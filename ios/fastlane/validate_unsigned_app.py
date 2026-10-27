#!/usr/bin/env python3
"""Validate the unsigned release app bundle without signing or ASC access."""

from __future__ import annotations

import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path


EXPECTED_VERSION = "1.29.0"
IOS_SUPPORT_CEILING = (13, 0, 0)
MACH_O_MAGICS = {
    b"\xfe\xed\xfa\xce",
    b"\xce\xfa\xed\xfe",
    b"\xfe\xed\xfa\xcf",
    b"\xcf\xfa\xed\xfe",
    b"\xca\xfe\xba\xbe",
    b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf",
    b"\xbf\xba\xfe\xca",
}


def version_tuple(value: str) -> tuple[int, int, int]:
    parts = [int(part) for part in value.split(".")]
    return tuple((parts + [0, 0, 0])[:3])


def plist(path: Path) -> dict:
    with path.open("rb") as stream:
        return plistlib.load(stream)


def require_supported_minimum(value: str, source: Path) -> None:
    if version_tuple(value) > IOS_SUPPORT_CEILING:
        raise ValueError(f"{source} requires iOS {value}; supported minimum must remain 13.0 or lower")


def validate_bundle(bundle: Path, identifier: str) -> dict:
    info_path = bundle / "Info.plist"
    info = plist(info_path)
    actual_identifier = info.get("CFBundleIdentifier")
    if actual_identifier != identifier:
        raise ValueError(f"{info_path}: expected bundle ID {identifier}, got {actual_identifier!r}")
    version = info.get("CFBundleShortVersionString")
    if version != EXPECTED_VERSION:
        raise ValueError(f"{info_path}: expected version {EXPECTED_VERSION}, got {version!r}")
    build = str(info.get("CFBundleVersion", ""))
    if not re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", build):
        raise ValueError(f"{info_path}: invalid CFBundleVersion {build!r}")
    minimum = str(info.get("MinimumOSVersion", ""))
    if not minimum:
        raise ValueError(f"{info_path}: MinimumOSVersion is missing")
    require_supported_minimum(minimum, info_path)

    manifest_path = bundle / "PrivacyInfo.xcprivacy"
    manifest = plist(manifest_path)
    if manifest.get("NSPrivacyTracking") is not False:
        raise ValueError(f"{manifest_path}: expected NSPrivacyTracking=false")
    if manifest.get("NSPrivacyTrackingDomains") != []:
        raise ValueError(f"{manifest_path}: tracking domains must be empty")
    if manifest.get("NSPrivacyCollectedDataTypes") != []:
        raise ValueError(f"{manifest_path}: expected no collected data types")
    accessed = manifest.get("NSPrivacyAccessedAPITypes", [])
    required_reason = any(
        entry.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryFileTimestamp"
        and "C617.1" in entry.get("NSPrivacyAccessedAPITypeReasons", [])
        for entry in accessed
    )
    if not required_reason:
        raise ValueError(f"{manifest_path}: missing FileTimestamp reason C617.1")

    for nested_info in bundle.rglob("Info.plist"):
        nested = plist(nested_info)
        nested_minimum = nested.get("MinimumOSVersion")
        if nested_minimum:
            require_supported_minimum(str(nested_minimum), nested_info)

    return {
        "bundle_id": actual_identifier,
        "version": version,
        "build": build,
        "minimum_ios": minimum,
        "privacy_manifest": str(manifest_path.relative_to(bundle.parent)),
    }


def is_mach_o(path: Path) -> bool:
    try:
        with path.open("rb") as stream:
            return stream.read(4) in MACH_O_MAGICS
    except OSError:
        return False


def macho_minimums(path: Path) -> list[str]:
    result = subprocess.run(
        ["xcrun", "vtool", "-show-build", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    minimums = re.findall(r"^\s*minos\s+([0-9]+(?:\.[0-9]+){0,2})\s*$", result.stdout, re.MULTILINE)
    if minimums:
        return minimums

    result = subprocess.run(
        ["xcrun", "otool", "-l", str(path)],
        check=False,
        capture_output=True,
        text=True,
    )
    command = None
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if stripped.startswith("cmd "):
            command = stripped[4:]
        elif command == "LC_VERSION_MIN_IPHONEOS" and stripped.startswith("version "):
            return [stripped.split()[1]]
    raise ValueError(f"could not read an iOS minimum deployment version from Mach-O {path}")


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} Runner.app", file=sys.stderr)
        return 2

    app = Path(sys.argv[1]).resolve()
    extension = app / "PlugIns" / "ShareExtension.appex"
    if not app.is_dir() or not extension.is_dir():
        raise ValueError(f"release app or Share Extension is missing under {app}")

    bundles = [
        validate_bundle(app, "dev.howardism.Masquerade"),
        validate_bundle(extension, "dev.howardism.Masquerade.ShareExtension"),
    ]
    binaries = [path for path in app.rglob("*") if path.is_file() and is_mach_o(path)]
    if not binaries:
        raise ValueError("no Mach-O binaries were found in the release app")

    checked_minimums: list[dict[str, str]] = []
    for binary in binaries:
        for minimum in macho_minimums(binary):
            require_supported_minimum(minimum, binary)
            checked_minimums.append({"path": str(binary.relative_to(app)), "minimum_ios": minimum})

    print(
        json.dumps(
            {
                "result": "passed",
                "expected_version": EXPECTED_VERSION,
                "bundles": bundles,
                "macho_binaries_checked": len(binaries),
                "macho_minimums": checked_minimums,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"unsigned app validation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
