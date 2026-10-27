#!/usr/bin/env python3
"""Web bundle size breakdown for the build-web job. Stdlib only.

  web_size.py measure <build_dir>   writes size.tsv, files.tsv, packages.tsv
                                    and flutter.txt into the current dir
  web_size.py details               prints the markdown detail sections,
                                    comparing against baseline-* when present

size.tsv keeps bundle-size.sh's <key>\t<bytes>\t<label> format so that script
still renders the headline table. packages.tsv needs the build to have run
with --dump-info, which writes main.dart.js.info.json without changing
main.dart.js itself.
"""

import gzip
import json
import os
import sys
from pathlib import Path

# The default JS build uses the CanvasKit renderer, and Chromium browsers load
# its chromium/ variant -- one of several canvaskit*.wasm files that ship.
FIRST_LOAD = [
    "index.html",
    "flutter_bootstrap.js",
    "main.dart.js",
    "canvaskit/chromium/canvaskit.js",
    "canvaskit/chromium/canvaskit.wasm",
]

# Order and labels of the headline rows.
ROWS = [
    ("gzip_main", "main.dart.js (gzip)"),
    ("first_load", "First load, Chrome (gzip)"),
    ("main", "main.dart.js"),
    ("engine", "Engine runtime (canvaskit/)"),
    ("symbols", "Debug symbols (*.symbols, never downloaded)"),
    ("assets", "App assets"),
    ("notices", "Licence NOTICES"),
    ("other", "Other"),
    ("total", "build/web total"),
]

TOP_FILES = 10
TOP_PACKAGES = 15


def gz(data):
    return len(gzip.compress(data, compresslevel=9))


def category(rel):
    if rel.endswith(".symbols"):
        return "symbols"
    if rel.startswith("canvaskit/"):
        return "engine"
    if rel == "main.dart.js":
        return "main"
    if rel == "assets/NOTICES":
        return "notices"
    if rel.startswith("assets/"):
        return "assets"
    return "other"


def shipped_files(root):
    # The dump-info report and source maps are build by-products, not bundle.
    for p in sorted(root.rglob("*")):
        rel = p.relative_to(root).as_posix()
        if p.is_file() and not rel.endswith((".info.json", ".map")):
            yield rel, p.stat().st_size


def first_load_files(root):
    files = list(FIRST_LOAD)
    manifest = root / "assets" / "FontManifest.json"
    if manifest.exists():
        for family in json.loads(manifest.read_text()):
            files += ["assets/" + f["asset"] for f in family.get("fonts", [])]
    return [f for f in files if (root / f).is_file()]


def package_of(uri):
    if uri.startswith("package:"):
        return uri.split("/")[0]
    if uri.startswith("dart:"):
        return "dart:* (SDK)"
    return "(app entrypoint)"


def packages(root):
    info = root / "main.dart.js.info.json"
    if not info.exists():
        return {}
    d = json.loads(info.read_text())
    out = {}
    for lib in d["elements"]["library"].values():
        name = package_of(lib["canonicalUri"])
        out[name] = out.get(name, 0) + lib["size"]
    # Code dart2js does not attribute to a library: runtime helpers, constants,
    # type metadata.
    rest = d["program"]["size"] - sum(out.values())
    if rest > 0:
        out["(unattributed runtime & constants)"] = rest
    return out


def write_tsv(path, rows):
    with open(path, "w") as f:
        for row in rows:
            f.write("\t".join(str(c) for c in row) + "\n")


def read_tsv(path):
    if not Path(path).exists():
        return None
    out = {}
    for line in Path(path).read_text().splitlines():
        if line:
            name, size = line.split("\t")[:2]
            out[name] = int(size)
    return out


def measure(build_dir):
    root = Path(build_dir)
    files = list(shipped_files(root))
    totals = {key: 0 for key, _ in ROWS}
    for rel, size in files:
        totals[category(rel)] += size
        totals["total"] += size
    totals["gzip_main"] = gz((root / "main.dart.js").read_bytes())
    totals["first_load"] = sum(
        gz((root / f).read_bytes()) for f in first_load_files(root)
    )

    write_tsv("size.tsv", [(k, totals[k], label) for k, label in ROWS])
    write_tsv("files.tsv", files)
    pkgs = sorted(packages(root).items(), key=lambda kv: -kv[1])
    write_tsv("packages.tsv", pkgs)
    Path("flutter.txt").write_text(os.environ.get("FLUTTER_VERSION", "") + "\n")


def human(n):
    sign = "-" if n < 0 else ""
    n = abs(n)
    if n >= 4 * 1024 * 1024:
        return f"{sign}{n / 1048576:.1f} MiB"
    return f"{sign}{n / 1024:.1f} KiB"


def delta(new, old):
    if old is None:
        return "added"
    if new is None:
        return "removed"
    d = new - old
    if d == 0:
        return "0"
    pct = f" ({100 * d / old:+.1f}%)" if old else ""
    return ("+" if d > 0 else "") + human(d) + pct


def details():
    out = []

    flutter = Path("flutter.txt").read_text().strip()
    base_flutter = (
        Path("baseline-flutter.txt").read_text().strip()
        if Path("baseline-flutter.txt").exists()
        else ""
    )
    if base_flutter and flutter and base_flutter != flutter:
        out += [
            f"> **Flutter changed:** baseline built with {base_flutter}, this "
            f"build with {flutter}. Engine and symbol rows move with the SDK, "
            "not with this PR's code.",
            "",
        ]

    files, base_files = read_tsv("files.tsv"), read_tsv("baseline-files.tsv")
    if base_files is None:
        out += ["_No per-file baseline yet: a push to develop records one._", ""]
    else:
        added = sorted(set(files) - set(base_files))
        removed = sorted(set(base_files) - set(files))
        changed = sorted(
            (f for f in files if f in base_files and files[f] != base_files[f]),
            key=lambda f: -abs(files[f] - base_files[f]),
        )
        out += [
            f"<details><summary>Per-file changes: {len(changed)} changed, "
            f"{len(added)} added, {len(removed)} removed</summary>",
            "",
        ]
        rows = (
            [(f, files[f], None) for f in added]
            + [(f, None, base_files[f]) for f in removed]
            + [(f, files[f], base_files[f]) for f in changed[:TOP_FILES]]
        )
        if rows:
            out += ["| File | This build | Baseline | Δ |", "|---|---|---|---|"]
            for f, new, old in rows:
                out.append(
                    f"| `{f}` | {human(new) if new is not None else '—'} | "
                    f"{human(old) if old is not None else '—'} | {delta(new, old)} |"
                )
            if len(changed) > TOP_FILES:
                out.append(f"\n_{len(changed) - TOP_FILES} smaller changes not shown._")
        else:
            out.append("No file changed.")
        out += ["", "</details>", ""]

    pkgs, base_pkgs = read_tsv("packages.tsv"), read_tsv("baseline-packages.tsv")
    if pkgs:
        base_pkgs = base_pkgs or {}
        names = sorted(
            set(pkgs) | set(base_pkgs),
            key=lambda n: -max(pkgs.get(n, 0), base_pkgs.get(n, 0)),
        )
        movers = [n for n in names if pkgs.get(n) != base_pkgs.get(n)]
        out += [
            "<details><summary>main.dart.js by package (pre-gzip, from "
            "<code>--dump-info</code>)</summary>",
            "",
            "| Package | This build | Baseline | Δ |",
            "|---|---|---|---|",
        ]
        shown = names[:TOP_PACKAGES]
        # A package outside the top list that moved still earns a row.
        shown += [n for n in movers if n not in shown] if base_pkgs else []
        for n in shown:
            new, old = pkgs.get(n), base_pkgs.get(n)
            out.append(
                f"| `{n}` | {human(new) if new is not None else '—'} | "
                f"{human(old) if old is not None else '—'} | "
                f"{delta(new, old) if base_pkgs else '—'} |"
            )
        out += ["", "</details>", ""]

    print("\n".join(out))


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "measure":
        measure(sys.argv[2])
    elif len(sys.argv) == 2 and sys.argv[1] == "details":
        details()
    else:
        sys.exit(__doc__)
