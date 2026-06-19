---
description: One toolbox auto-improvement iteration — select one backlog item, delegate implement+verify to a fresh worker, open a PR off main. Designed to be looped via `/loop /toolbox-improve`.
---

MISSION: Evolve Masquerade into the ULTIMATE developer toolbox with the BEST UX — a fast,
delightful, accessible iOS-first (Cupertino) utility app whose tools are correct, polished, and a
joy to use. Each run, ship EXACTLY ONE high-value, verified improvement as its own PR. Quality and
UX over volume — never invent churn, never ship a half-tested tool.

EXECUTION MODEL — orchestrator + worker (this is what keeps the loop's context small):
- YOU are the ORCHESTRATOR. You do the cheap, stateful work in this (looping) context: orient,
  read the backlog INDEX, dedupe against open PRs, SELECT one item, RECORD results, REPORT.
- A fresh WORKER subagent does the expensive, stateless work — implement, run the VERIFY GATE,
  commit, open the PR — in ITS OWN context, and returns only a small structured result. All
  `flutter analyze` / `flutter test` / `flutter build` output dies with the worker; it never enters
  this loop context.
- The worker is a FRESH `general-purpose` Agent in an isolated worktree (`isolation: worktree`) —
  NOT a `fork` (a fork would inherit your whole accumulated context, defeating the purpose). Hand it
  the PLAN and the selected item's detail block INLINE in its prompt (the backlog file is gitignored
  and absent from a fresh worktree — never tell the worker to read it).
- CONCURRENCY: MANY of these loops may run AT ONCE. They coordinate ONLY through local files: a
  per-item CLAIM and a global backlog-write LOCK (see CONCURRENCY). You MUST claim an item BEFORE
  delegating it, so two orchestrators never pick the same item during the long in-flight window
  before a PR exists. The `gh pr list` dedupe is a backstop, not the gate — a PR appears only
  minutes later when the worker finishes. For a single solo loop the claim is cheap insurance +
  crash recovery; keep using it.

REPO FACTS (don't rediscover; pass the relevant ones to the worker verbatim):
- Flutter `3.41.8` (pinned in `.github/workflows/ci.yml`). Cupertino widgets ONLY — `uses-material-design:
  false`. NEVER introduce `Material*` widgets, `Scaffold`, or `MaterialApp`. If a Material-only API
  seems needed, the item is BLOCKED — raise it, don't add the dependency.
- Runtime deps are deliberately lean: `cupertino_icons`, `intl`, `package_info_plus`,
  `shared_preferences`, plus shipped feature deps (qr, flutter_lucide, url_launcher, json_annotation,
  flutter_native_splash). NO third-party UI packages — `lib/widgets/iphone_frame.dart` is hand-rolled.
  Dev deps: `flutter_test` + `flutter_lints` only — NO codegen / mock framework. If an item genuinely
  needs `build_runner`/`mockito`/`json_serializable`, it must add the dep AND wire the generator + a
  CI step in the SAME PR (usually too big for one run → split or BLOCK).
- TOOL ARCHITECTURE (the heart of the app): every tool is registered in `lib/utility_catalog.dart`
  (`UtilityCatalog.all`) plus an embeddable body widget under
  `lib/widgets/tool_bodies/<tool>_body.dart`. Home (`lib/screens/home_screen.dart`) reads the catalog
  directly and renders each as an `InlineToolCard` — there is NO manual wiring elsewhere. Full-screen
  opens go through `lib/screens/detail/tool_detail_route.dart`. Adding a tool = catalog entry + body
  widget + tests; nothing else.
- Tool bodies share infra: the `ToolBodyScaffold` mixin
  (`lib/widgets/tool_bodies/tool_body_scaffold.dart`) handles input lifecycle (debounce Timer,
  HistoryRecorder, TextEditingController) — use `scaffold.reparse()` for option toggles. The
  `LinkableToolBody` mixin (`linkable_body.dart`) self-wires cross-tool live links. Prefer these over
  re-rolling lifecycle plumbing.
- Parsers are PURE: a static `parse()` returning a result struct, under `lib/utils/` (see
  `TimestampParser`). Keep tools concern-separated — timestamp stays time-only, encoding stays
  encoding-only; no cross-tool fall-through detection.
- DESIGN SYSTEM: prefer `lib/widgets/mq/*` (`MqButton`, `MqInput`, `MqSurface`, `MqMonoCell`,
  `InlineToolCard`, `ToolActionBar`, …) over raw Cupertino primitives — they carry theme + spacing
  tokens. Read colors via `MqTheme.of(context)` (`MqColors`/`MqTypography`/`MqMetrics`), NEVER
  hardcoded `CupertinoColors`. Every new tool threads `actionBar` through builder + body.
- DESKTOP OS: on wide web (≥ 900 px) the same catalog opens on a skeuomorphic macOS-style desktop
  (`lib/screens/desktop/`, `lib/widgets/desktop/`) — menubar, wallpaper, icon grid, windowed cards,
  dock, Spotlight ⌘K, live links. See `docs/adr/0001` (link engine) and `docs/adr/0002` (desktop
  metaphor), and `CONTEXT.md` for domain language.
- Tests MIRROR `lib/` under `test/`. Tests are REQUIRED for new functionality. `flutter test` is
  untagged in CI (picks up everything in `test/`). There's a `dynamic_type_test` that auto-iterates
  the catalog for overflow at large text sizes — new tools are covered automatically.
- Base branch is `main` (Conventional Commits, enforced by `commitizen` at commit-msg stage; caps
  apply). Branches: `feature/<slug>`. Dependabot's `deps(deps):` prefix is grandfathered — don't copy
  it for hand-written commits.
- DEPENDENCY GOTCHA (currently LIVE on main): `flutter_native_splash` MUST stay `^2.4.7`. Version
  2.4.8 requires `meta ^1.18.0`, but `flutter_test` from SDK 3.41.8 pins `meta 1.17.0`, so
  `flutter pub get` fails version-solving. Dependabot keeps re-bumping it (last via PR #93). NEVER
  bump `flutter_native_splash`; if `pub get` fails on the meta/native_splash conflict, pin it back to
  `^2.4.7` and regenerate `pubspec.lock`.
- Worktrees live at `.worktrees/<branch-name>` (gitignored) — run `git worktree list` before
  assuming working-tree state. The `PostToolUse` hook in `.claude/settings.json` runs `dart format` on
  every edited `*.dart`; if a format error surfaces, fix the syntax — don't silence it.
- NEVER touch/commit generated or gitignored paths: `build/`, `coverage/`, `.dart_tool/`,
  `*.symbols`, and the loop's gitignored RUNTIME STATE (`.claude/toolbox-improvement-backlog.md`,
  `.claude/.toolbox-claims/`, `.claude/toolbox-verify-*.log`). The command file and the claim helper
  (`.claude/commands/toolbox-improve.md`, `.claude/toolbox-improve-claim.sh`) ARE tracked, but a
  WORKER must never restage them — only the orchestrator/maintainer edits them, never inside a
  product PR.

VERIFY GATE (all must pass before any commit) — what CI gates on:
    flutter pub get                                  # must resolve (see DEPENDENCY GOTCHA)
    dart format --output=none --set-exit-if-changed .
    flutter analyze
    flutter test --coverage
  For any change touching web/manifest/splash/assets, ALSO run `flutter build web --release` (CI gates
  on it). Run each capturing stdout+stderr to a logfile (`.claude/toolbox-verify-<step>.log` or a
  worktree-local temp), and surface only the failure markers into context — never paste full logs:
    - format → non-zero exit, or any file path printed = unformatted; fix and re-run.
    - analyze → SUCCESS is exactly "No issues found!". Any `error •` / `warning •` / `info •` line
      FAILS the gate (the repo runs clean — leave it clean).
    - test → SUCCESS is "All tests passed!". FAIL markers: "Some tests failed.", lines starting "[E]",
      "Failed to load". NEVER infer success from the exit code alone — grep the log for these markers.
  Run flutter in the FOREGROUND — never detach/background a build or arm a monitor and rest; a
  backgrounded worker comes to rest mid-verify and never returns its result, stalling the loop.

CONCURRENCY — claim + lock helper (`.claude/toolbox-improve-claim.sh`, local + untracked, shared
across worktrees next to the backlog; `mkdir`-atomic, TTL-reclaimable so a crashed agent never wedges
the loop). Generate your OWNER token ONCE at run start and reuse the SAME literal string in every call
this run: `OWNER="tb-$(hostname -s)-$(date +%s)-$$"` (run it, paste the printed value into each command
below). `claim` is shorthand for `bash .claude/toolbox-improve-claim.sh`. Commands:
  - `claim list`                    — show in-flight (HELD) and dead (STALE) claims.
  - `claim acquire <ID> "$OWNER"`   — atomically take an item. Exit 0 = you own it (CLAIMED/RECLAIMED →
                                      proceed); exit 1 = HELD by a live agent (skip to next eligible).
  - `claim release <ID> "$OWNER"`   — drop your claim (on blocked/reverted, or after RECORD).
  - `claim lock "$OWNER"` / `claim unlock "$OWNER"` — wrap EVERY backlog-file read-modify-write (status
                                      flips, survey appends, bootstrap). Keep the locked section to just
                                      the edit; never hold the lock across a delegate.
The CLAIM is the gate; the Index `in-progress` text is only a human-readable mirror — always re-check
via `acquire`.

PROCEDURE — do all seven steps, then end the iteration:

0. ORIENT (the `.claude/toolbox-improvement-backlog.md` file is your only memory across runs — read it
   CHEAPLY):
   - Generate your OWNER token ONCE now (`OWNER="tb-$(hostname -s)-$(date +%s)-$$"`, print it) and reuse
     that literal string in every `claim`/`lock` call this run.
   - `git fetch origin main`.
   - PRECONDITION — `flutter pub get`. If it FAILS with the `meta`/`flutter_native_splash` conflict
     (see DEPENDENCY GOTCHA), this run's single item is: pin `flutter_native_splash` to `^2.4.7`,
     regenerate `pubspec.lock`, verify, ship as a `fix:` PR. That unblocks the gate for every future
     run — do it FIRST and skip the rest of SELECT.
   - Read ONLY the `## Index` table at the top of `.claude/toolbox-improvement-backlog.md` (Read with a
     small `limit`, ~first 70 lines) — do NOT read the detailed `## Backlog` blocks. The file is local,
     untracked, shared across worktrees (NOT in git). If it does NOT exist, BOOTSTRAP it this run (under
     `claim lock "$OWNER"` so a sibling loop doesn't bootstrap concurrently): survey `lib/` (catalog,
     tool bodies, parsers, mq widgets, desktop), write 10-15 ranked candidate improvements across the
     five categories below plus the `## Index` table, save the file, `claim unlock "$OWNER"`, then STOP —
     that is this run's deliverable.
   - `claim list` AND `gh pr list --label toolbox-autoimprove --state open` (create the label once if
     missing: `gh label create toolbox-autoimprove -c "#1d76db" -d "Automated toolbox-improve PR"`).
     Treat BOTH as IN-FLIGHT: do NOT re-pick an item another loop has CLAIMED (HELD) or that already has
     an open PR. Do NOT wait for either.

1. SELECT ONE item from the index: the highest-ranked entry that is `open`, NOT `blocked`/`done`/
   `wontfix`, NOT depending on a still-open item, not already covered by an open PR or live CLAIM, whose
   diff fits a single PR (~< 300 LOC).
   - CLAIM BEFORE DELEGATING (the race gate): the instant you pick a candidate, run
     `claim acquire <ID> "$OWNER"`. Exit 0 → you own it; proceed. Exit 1 (HELD) → a sibling grabbed it;
     drop it and SELECT the next eligible candidate, re-claiming, until one sticks. Then mirror it for
     humans under the lock: `claim lock "$OWNER"`, flip that Index row to `in-progress ($OWNER)`,
     `claim unlock "$OWNER"`. (The mirror is cosmetic; the CLAIM is the real gate.)
   - EXHAUSTION → SURVEY branch: if FEWER THAN 2 such items remain, do NOT force a low-value PR. Make
     this a SURVEY run instead: re-survey `lib/` for fresh high-value candidates, append 3-5 ranked
     entries (detail blocks + index rows) under the lock, ship one ONLY if genuinely high-value and
     single-PR, then REPORT and STOP. Never invent churn to have a PR.
   Categories, in priority order (mission = best UX + ultimate toolbox):
     a. UX & interaction polish — accessibility (Dynamic Type, `Semantics` labels, contrast),
        empty/error/loading states, copy/paste affordances, focus & keyboard handling, haptics,
        responsive layout, desktop-OS interactions (window snap, dock, Spotlight), micro-interactions
        and motion. The mission's center of gravity — weight these highest.
     b. Tool correctness & robustness — parser edge cases, malformed-input handling, no crashes on bad
        input, precise/actionable error messages, round-trip fidelity.
     c. Tool breadth & depth — a genuinely useful NEW developer utility (catalog entry + body + tests +
        detection predicate), or deepening an existing tool (more formats/options) without breaking
        concern-separation.
     d. Performance & responsiveness — debounce tuning, large-input handling, avoid rebuild jank, lazy
        builds. UX-perceptible wins only.
     e. Tests & coverage — widget tests for under-covered tool bodies, parser unit tests, golden tests,
        dynamic-type / overflow teeth-tests.
   If the best item is too big for one PR, split it: hand the worker the first vertical slice and leave
   the remainder in the backlog.

2. PLAN (brief) — the worker's marching orders: the change, files touched, the success check, and how a
   reviewer sees the UX win (a description, or a `flutter test` assertion). One short paragraph; this is
   what you hand to the worker.

3. DELEGATE — spawn ONE fresh `general-purpose` Agent (`isolation: worktree`; NOT a fork). Its prompt
   MUST include, verbatim: the relevant REPO FACTS, the VERIFY GATE, and the HARD RULES from this file;
   the PLAN from step 2; and the selected item's detail block INLINE (do NOT tell it to read the backlog
   file — that file is gitignored and absent from its worktree). The worker does the following IN ITS
   OWN CONTEXT and returns ONLY the structured result in step iv — no build logs reach you:
     i.   IMPLEMENT on a fresh `feature/<slug>` branch ALWAYS off `origin/main` (prior PRs are likely
          unmerged — branch from main, not a previous run's branch). Exception: if the item genuinely
          depends on an unmerged PR, base on that branch (a stacked PR) and say so. Surgical,
          style-matched, no speculative abstraction; Cupertino-only; reuse `ToolBodyScaffold` /
          `LinkableToolBody` / `mq/*`; colors via `MqTheme.of(context)`.
     ii.  VERIFY with the gate (quiet-capture per the VERIFY GATE), running flutter in the FOREGROUND.
          For UX items, the success check is usually a new/updated widget test asserting the behavior
          (a `Semantics` finder, an overflow check, an error-state finder). If a claimed win can't be
          demonstrated, REVERT and report it.
     iii. COMMIT atomically (Conventional Commits: `feat:`/`fix:`/`refactor:`/`test:`/`docs:`/`perf:`;
          NOT `deps(deps):`) staging ONLY changed paths (`git add <your paths>`, never `-A`/`.`; ignore
          pre-existing root untracked files and the gitignored apparatus). Then `gh pr create --base
          main --label toolbox-autoimprove` with body: motivation, what changed, UX impact, verification
          evidence (test summary + how to see it), risk/rollback. Do NOT merge — leave for human review.
     iv.  RETURN a compact result ONLY (no logs): `{ id, status: shipped|blocked|reverted, pr_url,
          evidence, blocked_reason, follow_ups[] }`. This JSON MUST be the worker's FINAL output on every
          path — never end mid-task. If the item proves BLOCKED (needs a prerequisite/infra/Material-only
          API it cannot stand up), it abandons the branch and returns `status: blocked` with the reason —
          it does NOT stop the loop.

4. INGEST + RETRY: read the worker's result. If `status: blocked` or `reverted`, first do step 5's
   RECORD for it (terminal status for `blocked`; leave `reverted` items `open`), then
   `claim release <ID> "$OWNER"` so the item frees immediately, and RETURN to step 1 to DELEGATE the
   NEXT eligible item (try at most ~3 items per run). STOP only if the failure is environmental
   (toolchain/`pub get` down beyond the native_splash pin) or no unblocked, verifiable item remains.

5. RECORD (you write the shared state — it is NOT part of any PR): take the global lock first
   (`claim lock "$OWNER"`), then from the worker's result flip the item's Status — from the
   `in-progress` mirror — to `done (#PR)` / `blocked (<reason>)` in BOTH its `## Index` row AND its
   detail block, append any follow-ups the worker discovered, and add index rows + detail blocks for any
   new candidates a SURVEY run produced; `claim unlock "$OWNER"`. Then `claim release <ID> "$OWNER"`.
   Sibling loops may also be writing this file, so every edit MUST be inside the lock — you are a
   serialized writer, not the sole one.

6. META — improve THIS prompt (rare; only on concrete friction from THIS run). Reflect: was a REPO FACT
   stale (a path/command/anchor that moved)? Did an instruction force you to guess? Was a guardrail
   missing that you needed? Only if there is a concrete, observed fix — NOT speculative wordsmithing;
   most runs change nothing — make a SMALL surgical edit to this file at
   `.claude/commands/toolbox-improve.md`. This file IS tracked in git, but META edits are LOCAL
   working-tree changes in the orchestrator's main checkout — NEVER bundle them into a
   toolbox-improve product PR; the maintainer commits prompt tweaks separately (they're dev tooling).
   Then append one dated line to the "Prompt revision log" at the bottom.
   IMMUTABLE — a self-edit must NEVER remove, weaken, or reword to loosen: the VERIFY GATE; the HARD
   RULES; "never push/merge main"; "never merge your own PR"; "Cupertino-only / no new UI deps"; "never
   bump flutter_native_splash"; the one-improvement-per-run scope; the orchestrator+worker execution
   model; or this META step and its own rules. Preserve the file's structure (frontmatter with
   `description`, MISSION, EXECUTION MODEL, REPO FACTS, VERIFY GATE, CONCURRENCY, all seven steps, HARD
   RULES, revision log). Back the file up first; if afterward any required section is missing or the net
   change exceeds ~15 lines, RESTORE the backup and skip. This step must NEVER revert or block the
   improvement already shipped this run.

7. REPORT one paragraph in this fixed shape, then END IMMEDIATELY (do NOT wait for CI or merge):
   `item:` <ID + one-line> · `status:` shipped|blocked|reverted|survey|bootstrap · `pr:` <URL or —> ·
   `evidence:` <test summary + UX impact, or why blocked> · `follow-ups:` <new backlog rows> · `meta:`
   <prompt self-edit made, or none>. The next iteration begins as soon as this one stops and will branch
   fresh off `origin/main`, skipping anything still open.

HARD RULES: never push to or merge `main`; never merge your own PR; never commit generated/gitignored
files or the apparatus; never introduce `Material*`/`Scaffold`/`MaterialApp` or a new third-party UI
dependency; never bump `flutter_native_splash` off `^2.4.7`; keep diffs small, reversible, and
style-matched; tests are required for new functionality; if nothing is genuinely worth doing this round,
say so and stop.

## Prompt revision log

Newest last; one line each, capped at the last ~20 entries.
Format: `YYYY-MM-DD — <change> (<why>)`.

- 2026-06-19 — Initial adaptation of `engine-improve` for the Masquerade Flutter toolbox: Cupertino/UX
  mission, Flutter VERIFY GATE (format/analyze/test + web build), tool-catalog + ToolBodyScaffold repo
  facts, `flutter_native_splash ^2.4.7` pin as a self-healing step-0 precondition, claim+lock helper at
  `.claude/toolbox-improve-claim.sh`. (Created from the hft-market-server template.)
