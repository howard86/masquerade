---
description: One toolbox auto-improvement iteration — select one backlog item, delegate implement+verify to a fresh worker, open a PR off main. Loop via `/loop /toolbox-improve`.
---

MISSION: Evolve Masquerade into the ultimate developer toolbox with the best UX — a fast, delightful,
accessible iOS-first (Cupertino) utility app. Each run, ship EXACTLY ONE high-value, verified
improvement as its own PR. Quality over volume; never invent churn or ship a half-tested tool.

EXECUTION MODEL — orchestrator + worker (keeps the loop's context small):
- YOU are the ORCHESTRATOR: cheap stateful work in this looping context — orient, read the backlog
  INDEX only, dedupe against open PRs + claims, SELECT one item, RECORD, REPORT.
- A fresh WORKER subagent does the expensive work — implement, run the VERIFY GATE, commit, open the
  PR — in ITS OWN context, returning only a small structured result. No build output reaches you.
- The worker is a fresh `general-purpose` Agent, `isolation: worktree` (NOT a fork — a fork inherits
  your whole context). Hand it the PLAN, REPO FACTS, VERIFY GATE, HARD RULES, and the item's detail
  block INLINE. NEVER tell it to read the backlog (gitignored, absent from its worktree).
- CONCURRENCY: many loops may run at once, coordinating ONLY via local files — a per-item CLAIM and a
  global backlog LOCK. CLAIM an item BEFORE delegating (the long pre-PR window is the race); the
  `gh pr list` dedupe is a backstop, not the gate.

REPO FACTS (pass relevant ones to the worker verbatim):
- Flutter 3.41.8 (pinned in ci.yml). Cupertino widgets ONLY (`uses-material-design: false`) — never
  `Material*`/`Scaffold`/`MaterialApp`. A Material-only need = BLOCKED, don't add the dep.
- Lean runtime deps (cupertino_icons, intl, package_info_plus, shared_preferences + shipped: qr,
  flutter_lucide, url_launcher, json_annotation, flutter_native_splash); no third-party UI pkgs. Dev
  deps: flutter_test + flutter_lints only — no codegen/mocks. An item needing
  build_runner/mockito/json_serializable must add the dep AND wire generator + CI in the SAME PR
  (usually too big → split or BLOCK).
- TOOL ARCHITECTURE: every tool = entry in `lib/utility_catalog.dart` (`UtilityCatalog.all`) + body
  under `lib/widgets/tool_bodies/<tool>_body.dart`. Home reads the catalog and renders each as
  `InlineToolCard` (no manual wiring); full-screen via `lib/screens/detail/tool_detail_route.dart`.
  Adding a tool = catalog entry + body + tests.
- Tool bodies reuse the `ToolBodyScaffold` mixin (input lifecycle: debounce, HistoryRecorder,
  controller; `scaffold.reparse()` for toggles) and `LinkableToolBody` (cross-tool links) — don't
  re-roll plumbing. Parsers are PURE static `parse()` under `lib/utils/`; keep tools concern-separated
  (no cross-tool detection).
- DESIGN SYSTEM: prefer `lib/widgets/mq/*` over raw Cupertino; read colors via `MqTheme.of(context)`,
  never hardcoded `CupertinoColors`. New tools thread `actionBar` through builder + body.
- DESKTOP OS: wide web (≥900px) opens the same catalog on a skeuomorphic macOS desktop
  (`lib/screens/desktop/`, `lib/widgets/desktop/`). See `docs/adr/0001` (links), `0002` (desktop),
  `CONTEXT.md`.
- Tests MIRROR `lib/` under `test/`, REQUIRED for new functionality (CI runs all of `test/`,
  untagged). `dynamic_type_test` auto-covers new catalog tools for overflow.
- Base `main`, Conventional Commits (commitizen at commit-msg; caps apply). Branches `feature/<slug>`.
  Don't use Dependabot's grandfathered `deps(deps):` prefix.
- DEP GOTCHA (LIVE): keep `flutter_native_splash` at `^2.4.7` — 2.4.8 needs `meta ^1.18.0` but
  flutter_test pins `meta 1.17.0`, breaking `pub get`. NEVER bump it; if `pub get` fails on this,
  re-pin `^2.4.7` + regen `pubspec.lock`.
- Worktrees at `.worktrees/<branch>` (gitignored — `git worktree list` first). PostToolUse hook runs
  `dart format` on edited `*.dart`; fix format errors, don't silence.
- NEVER commit generated/gitignored paths (`build/`, `coverage/`, `.dart_tool/`, `*.symbols`) or the
  loop's runtime state (`.claude/toolbox-improvement-backlog.md`, `.claude/.toolbox-claims/`,
  `.claude/toolbox-verify-*.log`). The command + claim helper ARE tracked, but a WORKER never restages
  them.

VERIFY GATE (all pass before any commit; what CI gates on):
    flutter pub get                                  # must resolve (see DEP GOTCHA)
    dart format --output=none --set-exit-if-changed .
    flutter analyze                                  # SUCCESS = exactly "No issues found!"
    flutter test --coverage                          # SUCCESS = "All tests passed!"
  For web/manifest/splash/asset changes ALSO `flutter build web --release`. Capture each to a logfile
  and surface only failure markers — never paste logs. analyze FAILS on any `error •`/`warning •`/
  `info •`; test FAILS on "Some tests failed.", "[E]", "Failed to load" — never infer success from the
  exit code. Run flutter in the FOREGROUND (a backgrounded build stalls the loop).

CONCURRENCY — claim+lock helper `.claude/toolbox-improve-claim.sh` (local, untracked, mkdir-atomic,
TTL-reclaimable). Generate OWNER once and reuse the literal everywhere:
`OWNER="tb-$(hostname -s)-$(date +%s)-$$"`. `claim` = `bash .claude/toolbox-improve-claim.sh`:
  - `claim list` — show HELD/STALE claims.
  - `claim acquire <ID> "$OWNER"` — exit 0 = you own it; exit 1 = HELD (skip).
  - `claim release <ID> "$OWNER"` — drop (on blocked/reverted or after RECORD).
  - `claim lock|unlock "$OWNER"` — wrap EVERY backlog read-modify-write; keep it to just the edit,
    never across a delegate.
The CLAIM is the gate; the Index `in-progress` text is a human mirror only.

PROCEDURE — all seven steps, then end:

0. ORIENT: generate + print OWNER once; `git fetch origin main`. PRECONDITION `flutter pub get` — if
   it fails on the meta/native_splash conflict, this run's item is: re-pin `^2.4.7`, regen lock,
   verify, ship a `fix:` PR (skip the rest of SELECT). Read ONLY the `## Index` table (small `limit`,
   ~70 lines) — not the detail blocks. If the backlog file is missing, BOOTSTRAP under the lock:
   survey `lib/`, write 10-15 ranked candidates across the five categories + the Index, save, unlock,
   STOP. Then `claim list` AND `gh pr list --label toolbox-autoimprove --state open` (create the label
   once if missing: `gh label create toolbox-autoimprove -c "#1d76db" -d "Automated toolbox-improve
   PR"`); treat both as in-flight, don't wait.

1. SELECT one Index item: highest-ranked that is `open`, not blocked/done/wontfix, not depending on an
   open item, not covered by an open PR or live claim, diff ~<300 LOC. CLAIM BEFORE DELEGATING:
   `claim acquire <ID> "$OWNER"` (exit 1 → next eligible until one sticks), then mirror under the lock
   (flip the Index row to `in-progress ($OWNER)`). EXHAUSTION (<2 eligible) → SURVEY run: re-survey
   `lib/`, append 3-5 ranked entries under the lock, ship one only if genuinely high-value +
   single-PR, else REPORT + STOP — never invent churn. Categories by priority: (a) UX & interaction
   polish — accessibility (Dynamic Type, Semantics, contrast), empty/error/loading states,
   copy/paste, focus/keyboard, haptics, responsive, desktop-OS interactions, motion (weight highest);
   (b) tool correctness — parser edge cases, malformed input, no crashes, precise errors, round-trip
   fidelity; (c) breadth/depth — a useful NEW tool (catalog+body+tests+predicate) or deepening one
   without breaking concern-separation; (d) performance — debounce, large input, rebuild jank
   (UX-perceptible only); (e) tests/coverage — widget/parser/golden/overflow tests. If the best item
   is too big, hand the worker the first slice and leave the rest.

2. PLAN (brief) — the worker's marching orders: the change, files touched, the success check, how a
   reviewer sees the UX win. One short paragraph.

3. DELEGATE — one fresh `general-purpose` Agent (`isolation: worktree`, NOT fork). Prompt MUST include
   verbatim: relevant REPO FACTS, the VERIFY GATE, the HARD RULES, the PLAN, and the item's detail
   block INLINE (never "read the backlog"). The worker, in its own context, returns ONLY the step-iv
   result:
     i.   IMPLEMENT on a fresh `feature/<slug>` off `origin/main` (prior PRs are likely unmerged —
          branch from main, not a prior branch; exception: a genuine dependency → stack on that branch
          and say so). Surgical, style-matched, Cupertino-only; reuse `ToolBodyScaffold`/
          `LinkableToolBody`/`mq/*`; colors via `MqTheme.of(context)`.
     ii.  VERIFY with the gate (quiet-capture, foreground). UX items: the success check is usually a
          new/updated widget test (a Semantics finder, an overflow check, an error-state finder). If a
          claimed win can't be demonstrated, REVERT and report.
     iii. COMMIT atomically (Conventional Commits: feat/fix/refactor/test/docs/perf, NOT deps(deps)),
          staging ONLY your paths (`git add <paths>`, never `-A`/`.`; ignore pre-existing root
          untracked files and the apparatus). Then `gh pr create --base main --label
          toolbox-autoimprove` with body: motivation, what changed, UX impact, verification evidence,
          risk/rollback. Do NOT merge.
     iv.  RETURN compact JSON only (no logs): `{ id, status: shipped|blocked|reverted, pr_url,
          evidence, blocked_reason, follow_ups[] }` — ALWAYS the final output, never end mid-task.
          BLOCKED (needs a prerequisite/infra/Material-only API) → abandon the branch, return
          `blocked`, don't stop the loop.

4. INGEST + RETRY: read the result. If blocked/reverted, do step 5 RECORD (terminal for `blocked`;
   leave `reverted` items `open`), `claim release <ID> "$OWNER"`, and RETURN to step 1 for the next
   eligible item (≤~3/run). STOP only if the failure is environmental (toolchain/`pub get` down beyond
   the native_splash pin) or no unblocked, verifiable item remains.

5. RECORD (you write shared state, NOT part of any PR): `claim lock "$OWNER"`, flip the item's Status
   from the `in-progress` mirror to `done (#PR)`/`blocked (reason)` in BOTH the Index row AND its
   detail block, append worker follow-ups + any SURVEY candidates (index rows + detail blocks),
   `claim unlock "$OWNER"`, then `claim release <ID> "$OWNER"`. Every edit MUST be inside the lock
   (siblings also write).

6. META — improve THIS prompt (rare; only on concrete friction THIS run: a stale REPO FACT — a
   path/command/anchor that moved; an instruction that forced a guess; a missing guardrail). Make a
   SMALL surgical edit to `.claude/commands/toolbox-improve.md` and append one dated line to this
   command's section of the revision log at `.claude/toolbox-revision-log.md` (a separate tracked
   file — NOT in this prompt). This file is tracked, but META edits are LOCAL working-tree changes in the
   orchestrator's main checkout — NEVER bundle into a product PR (the maintainer commits prompt tweaks
   separately). IMMUTABLE — never remove, weaken, or reword to loosen: the VERIFY GATE; the HARD
   RULES; "never push/merge main"; "never merge your own PR"; "Cupertino-only / no new UI deps";
   "never bump flutter_native_splash"; one-improvement-per-run; the orchestrator+worker model; this
   META step. Preserve the file's section structure (frontmatter `description`, MISSION, EXECUTION
   MODEL, REPO FACTS, VERIFY GATE, CONCURRENCY, all seven steps, HARD RULES). Back up
   first; if any required section goes missing or the net change exceeds ~15 lines, RESTORE and skip.
   Never revert/block the improvement already shipped this run.

7. REPORT one paragraph, then END (don't wait for CI/merge): `item:` <ID + one-line> · `status:`
   shipped|blocked|reverted|survey|bootstrap · `pr:` <URL or —> · `evidence:` <test summary + UX
   impact, or why blocked> · `follow-ups:` <new rows> · `meta:` <self-edit, or none>. The next
   iteration branches fresh off `origin/main`, skipping anything still open.

HARD RULES: never push to or merge `main`; never merge your own PR; never commit generated/gitignored
files or the apparatus; never introduce `Material*`/`Scaffold`/`MaterialApp` or a new third-party UI
dependency; never bump `flutter_native_splash` off `^2.4.7`; keep diffs small, reversible,
style-matched; tests required for new functionality; if nothing is genuinely worth doing, say so and
stop.

Prompt revision history lives in `.claude/toolbox-revision-log.md` (a separate tracked file), not here.
