---
description: One toolbox PR-review iteration — pick one open `toolbox-autoimprove` PR, delegate review+fix+merge to a fresh worker, merge ONLY when CI is green and the diff matches the PR description, then flip the backlog row to `merged`. Designed to be looped via `/loop /toolbox-review`.
---

MISSION: Be the REVIEWER for the PRs the `/toolbox-improve` loop produces. Drive each
`toolbox-autoimprove` PR to a clean, verified merge — one PR per run. You are the second pair of
eyes the improve loop deliberately lacks (it never merges its own work). Merge ONLY what is correct,
in-scope, and green; FIX what is close; BLOCK what needs a human. Quality over throughput — a wrong
merge into `main` is far costlier than a PR left open one more round.

EXECUTION MODEL — orchestrator + worker (this keeps the loop's context small):
- YOU are the ORCHESTRATOR. You do the cheap, stateful work in this (looping) context: orient, list
  open PRs, dedupe against live review CLAIMS, SELECT one PR, confirm the outcome, RECORD the backlog
  flip, REPORT.
- A fresh WORKER subagent does the expensive, stateless work — check out the PR branch, read the
  diff, run the VERIFY GATE, apply fixes, push, and merge — in ITS OWN context, returning only a
  small structured result. All `flutter analyze` / `flutter test` / diff output dies with the worker;
  it never enters this loop context.
- The worker is a FRESH `general-purpose` Agent in an isolated worktree (`isolation: worktree`) —
  NOT a `fork`. Hand it the PR number + branch, the PR body, the REVIEW + MERGE GATES, the REPO
  FACTS, and (if found) the backlog detail block for the item, all INLINE. The worker checks out the
  EXISTING PR branch inside its worktree (`git fetch origin <branch>` + `git checkout <branch>`); the
  harness-created branch is abandoned. NEVER tell the worker to read the backlog file — it is
  gitignored and absent from a fresh worktree.
- CONCURRENCY: MANY loops (improve AND review) may run AT ONCE. They coordinate ONLY through local
  files. Reuse the SAME helper the improve loop uses — `.claude/toolbox-improve-claim.sh` — so the
  global backlog-write LOCK is SHARED across both loops (this is REQUIRED; a second lock would let
  the two loops corrupt the backlog file concurrently). Review CLAIMS are namespaced `pr-<N>` so they
  never collide with the improve loop's `TB-NN` item claims. You MUST claim a PR BEFORE delegating it
  so two reviewers never grab the same PR.

RELATIONSHIP TO `/toolbox-improve`: the improve loop SHIPS a PR and marks the backlog row
`done (#PR)` the instant the PR is CREATED — `done` here means "PR open", NOT merged. Your job turns
`done (#PR)` into `merged (#PR)`. The two loops share the backlog file, the lock, and the
`toolbox-autoimprove` label, nothing else.

REPO FACTS (don't rediscover; pass the relevant ones to the worker verbatim — the canonical, fuller
list lives in `.claude/commands/toolbox-improve.md`, but the worker has a fresh context so inline
what matters):
- Flutter `3.41.8` (pinned in `.github/workflows/ci.yml`). Cupertino widgets ONLY —
  `uses-material-design: false`. A PR that introduces `Material*` / `Scaffold` / `MaterialApp` or a
  new third-party UI dependency FAILS review — do NOT merge it; report `blocked (review-reject)`.
- Runtime deps are deliberately lean (`cupertino_icons`, `intl`, `package_info_plus`,
  `shared_preferences`, plus shipped feature deps: qr, flutter_lucide, url_launcher, json_annotation,
  flutter_native_splash). Dev deps: `flutter_test` + `flutter_lints` only. A PR adding a dep without
  wiring it (codegen/CI) is suspect — scrutinize.
- DEPENDENCY GOTCHA (LIVE on main): `flutter_native_splash` MUST stay `^2.4.7` (2.4.8 needs
  `meta ^1.18.0` but `flutter_test` pins `meta 1.17.0`, so `pub get` fails). A PR that bumps it FAILS
  review. If `pub get` fails on this conflict inside the worktree, the worker re-pins `^2.4.7` +
  regenerates `pubspec.lock` as a fix commit ONLY if that change belongs to THIS PR's scope;
  otherwise report `blocked (env: native_splash)`.
- TOOL ARCHITECTURE: tools register in `lib/utility_catalog.dart` (`UtilityCatalog.all`) + an
  embeddable body under `lib/widgets/tool_bodies/<tool>_body.dart`; Home renders each as an
  `InlineToolCard`. Tool bodies reuse the `ToolBodyScaffold` mixin (input lifecycle) and
  `LinkableToolBody` (cross-tool links); parsers are PURE static `parse()` under `lib/utils/`. Design
  system: prefer `lib/widgets/mq/*`; read colors via `MqTheme.of(context)`, never hardcoded
  `CupertinoColors`. Tests MIRROR `lib/` under `test/`; new functionality REQUIRES tests.
- Base branch is `main` (Conventional Commits, enforced by `commitizen` at commit-msg; caps apply).
  Dependabot's `deps(deps):` prefix is grandfathered — fix commits you add use
  `fix:`/`refactor:`/`test:` etc., never `deps(deps):`.
- MERGE CONFIG (verified): squash is DISABLED; merge-commit and rebase are allowed; repo-level
  auto-merge is OFF (so `--auto` will NOT work — merge immediately with `--merge`); branches
  auto-delete on merge; `main` is NOT branch-protected. Merge method is `gh pr merge <N> --merge
  --delete-branch`.
- gh TOKEN LACKS `workflow` SCOPE: a PR whose diff touches `.github/workflows/*` CANNOT be merged by
  this loop — report `blocked (needs workflow-scope token; human merge)`. Do NOT attempt the merge.
- Worktrees live at `.worktrees/<branch>` (gitignored) — run `git worktree list` before assuming
  state. The `PostToolUse` hook runs `dart format` on edited `*.dart`; if a format error surfaces,
  fix the syntax.
- NEVER touch/commit generated or gitignored paths (`build/`, `coverage/`, `.dart_tool/`,
  `*.symbols`) or the loop apparatus (`.claude/toolbox-improvement-backlog.md`,
  `.claude/.toolbox-claims/`, `.claude/toolbox-verify-*.log`). If a PR under review committed any of
  those, that is a review finding — the worker strips them as a fix commit.

VERIFY GATE (what CI gates on; the worker runs this LOCALLY before pushing ANY fix, and never pushes
red):
    flutter pub get                                  # must resolve (see DEPENDENCY GOTCHA)
    dart format --output=none --set-exit-if-changed .
    flutter analyze                                  # SUCCESS = exactly "No issues found!"
    flutter test --coverage                          # SUCCESS = "All tests passed!"
  For any change touching web/manifest/splash/assets, ALSO `flutter build web --release` (CI gates on
  it). Capture stdout+stderr to a logfile (`.claude/toolbox-verify-<step>.log` or worktree-local
  temp) and surface only failure markers — never paste full logs. analyze FAILS on any `error •` /
  `warning •` / `info •` line; test FAILS on "Some tests failed.", "[E]", or "Failed to load" — never
  infer success from exit code alone. Run flutter in the FOREGROUND — never detach/background a build;
  a backgrounded worker comes to rest mid-verify and stalls the loop.

REVIEW CRITERIA (the worker's review pass over `git diff origin/main...HEAD`):
  1. CORRECTNESS — does the change do what it claims with no bug, regression, or crash-on-bad-input?
     Parsers stay concern-separated and pure; error messages precise.
  2. SCOPE / DESCRIPTION MATCH — the PR body's "what changed" + verification evidence must match the
     ACTUAL diff and commit messages. No scope creep (unrelated files), no claimed test that is
     absent, no committed apparatus/gitignored files. This is the user's hard merge gate: "commits
     match the PR description."
  3. CONVENTIONS — Cupertino-only; `mq/*` + `MqTheme.of(context)` over raw primitives/hardcoded
     colors; `ToolBodyScaffold`/`LinkableToolBody` reused, not re-rolled; Conventional Commits.
  4. TESTS — new functionality has mirrored tests under `test/` that actually assert the behavior the
     PR claims (a `Semantics` finder, an overflow check, an error-state finder, a parser case).
  5. CI — the live check rollup: the Flutter CI checks ("Pre-commit hooks", "Analyze and Test",
     "Security scan") must all be SUCCESS. Netlify checks are NEUTRAL and dependabot may be SKIPPED —
     ignore those. PENDING/IN_PROGRESS ≠ green.

MERGE GATE — merge ONLY when ALL hold (else FIX or BLOCK, never merge):
  - live CI all-green (the three Flutter CI checks SUCCESS), AND
  - the diff review is clean (no correctness/Cupertino/dep violation), AND
  - the diff + commits match the PR description (criterion 2), AND
  - the PR is MERGEABLE against current `main` (no conflicts), AND
  - the diff does NOT touch `.github/workflows/*`.
  If the worker applies ANY fix, the local VERIFY GATE must pass before pushing, and it does NOT merge
  that run (CI must re-run on the new commit) — it reports `fixed`, and a later iteration merges once
  CI re-greens.

CONCURRENCY — claim + lock via the SHARED helper `.claude/toolbox-improve-claim.sh` (local +
untracked; `mkdir`-atomic, TTL-reclaimable). Generate your OWNER token ONCE at run start and reuse the
SAME literal string everywhere this run: `OWNER="tr-$(hostname -s)-$(date +%s)-$$"` (the `tr-` prefix
distinguishes review owners from the improve loop's `tb-`). `claim` is shorthand for
`bash .claude/toolbox-improve-claim.sh`. Commands:
  - `claim list`                       — show in-flight (HELD) and dead (STALE) claims (both loops).
  - `claim acquire pr-<N> "$OWNER"`    — atomically take PR #N. Exit 0 = you own it; exit 1 = HELD by
                                         a live reviewer (skip to the next eligible PR).
  - `claim release pr-<N> "$OWNER"`    — drop your claim (after RECORD, or on blocked/pending).
  - `claim lock "$OWNER"` / `claim unlock "$OWNER"` — wrap EVERY backlog-file read-modify-write. This
                                         lock is GLOBAL and SHARED with the improve loop; keep the
                                         locked section to just the edit, never across a delegate.

PROCEDURE — do all seven steps, then end the iteration:

0. ORIENT:
   - Generate your OWNER token ONCE now (`OWNER="tr-$(hostname -s)-$(date +%s)-$$"`, print it) and
     reuse that literal string in every `claim`/`lock` call this run.
   - `git fetch origin main`.
   - List candidate PRs oldest-first (merging the earliest first keeps later PRs rebasing cleanly):
     `gh pr list --label toolbox-autoimprove --state open --json number,title,headRefName,createdAt
     --jq 'sort_by(.createdAt) | .[] | "\(.number)\t\(.headRefName)\t\(.title)"'`.
   - `claim list` — note which `pr-*` are already HELD by a sibling reviewer. If NO open
     `toolbox-autoimprove` PRs exist, REPORT "nothing to review" and STOP.

1. SELECT ONE PR: the OLDEST open `toolbox-autoimprove` PR whose `pr-<N>` claim is not HELD. Claim it
   BEFORE delegating (the race gate): `claim acquire pr-<N> "$OWNER"`. Exit 0 → you own it; proceed.
   Exit 1 (HELD) → a sibling has it; move to the next-oldest, re-claiming until one sticks (try at
   most ~3 PRs per run). You do NOT need to mirror review claims into the backlog Index — the backlog
   row already reads `done (#N)`; your only backlog write is the merge flip in step 5.

2. PLAN (brief) — assemble the worker's marching orders: PR number + head branch; the PR body
   (`gh pr view <N> --json body,title --jq .body`); and, if a backlog row's Status contains `(#N)`,
   that item's detail block INLINE (so the worker can judge "matches the description"). One short
   paragraph; this is what you hand to the worker.

3. DELEGATE — spawn ONE fresh `general-purpose` Agent (`isolation: worktree`; NOT a fork). Its prompt
   MUST include, verbatim: the relevant REPO FACTS, the VERIFY GATE, the REVIEW CRITERIA, the MERGE
   GATE, and the HARD RULES from this file; the PLAN from step 2; the PR number + head branch; and the
   PR body (+ backlog detail block if found) INLINE. The worker does the following IN ITS OWN CONTEXT
   and returns ONLY the structured result in step v:
     i.   CHECK OUT the PR branch in its worktree: `git fetch origin main`, `git fetch origin
          <branch>`, `git checkout <branch>` (the harness-created branch is abandoned). Confirm
          `git rev-parse HEAD` matches the PR head.
     ii.  REVIEW the diff (`git diff origin/main...HEAD`, `git log origin/main..HEAD`) against the
          REVIEW CRITERIA. Read the live CI rollup
          (`gh pr view <N> --json statusCheckRollup,mergeable,mergeStateStatus`). Check the diff does
          NOT touch `.github/workflows/*`.
     iii. DECIDE:
          - ALL MERGE-GATE conditions hold → `gh pr merge <N> --merge --delete-branch`. Confirm
            `gh pr view <N> --json state` returns MERGED. Return `merged`.
          - FIXABLE (failing/missing test, analyzer nit, review finding, committed apparatus file, or
            a conflict with main that resolves cleanly) → apply the MINIMAL in-scope fix; for a
            conflict, `git merge origin/main` (NEVER rebase-force-push a published branch) and resolve
            trivially; run the FULL local VERIFY GATE; commit with Conventional Commits (`fix:` /
            `test:` / `refactor:`); `git push`. Do NOT merge this run. Return `fixed`.
          - CI still PENDING/IN_PROGRESS and otherwise clean → touch nothing. Return `pending`.
          - NEEDS A HUMAN (touches `.github/workflows/*`, a Material/dep violation or correctness bug
            you cannot fix in-scope, a non-trivial conflict, or the diff contradicts the PR
            description in a way that is a real defect) → touch nothing destructive; NEVER close the
            PR. Return `blocked` with the reason.
     iv.  NEVER force-push or rewrite a published branch; only ADD commits or a clean `merge origin/
          main`. NEVER merge unless every MERGE-GATE condition holds. NEVER touch `main` directly.
     v.   RETURN a compact result ONLY (no logs): `{ pr, head, item_id, status:
          merged|fixed|pending|blocked, ci, review_summary, fixes[], blocked_reason, follow_ups[] }`.
          This JSON MUST be the worker's FINAL output on every path.

4. INGEST + NEXT: read the worker's result. If `status: merged`, the orchestrator INDEPENDENTLY
   confirms with `gh pr view <N> --json state,mergedAt` before recording (trust, but verify). If
   `fixed` / `pending` / `blocked`, the PR stays open — do step 5 (no merge flip; optional note),
   `claim release pr-<N> "$OWNER"`, and RETURN to step 1 for the NEXT eligible PR (at most ~3 PRs per
   run). STOP early only if the failure is environmental (toolchain/`pub get` down) or no eligible PR
   remains.

5. RECORD (you write the shared backlog — it is NOT part of any PR; take the global lock first):
   - On `merged`: `claim lock "$OWNER"`; find the backlog row whose Status contains `(#N)` and flip
     it from `done (#N)` to `merged (#N)` in BOTH its `## Index` row AND its detail block; append any
     `follow_ups` the worker surfaced as new index rows + detail blocks; `claim unlock "$OWNER"`. (If
     no backlog row references `(#N)` — e.g. a manual PR — skip the flip; note it in the report.) Then
     `claim release pr-<N> "$OWNER"`.
   - On `fixed`/`pending`/`blocked`: leave the row `done (#N)` (PR still open). Optionally, under the
     lock, append a short ` — review: <fixed|pending|blocked reason>` note to the row's detail block
     so the next reviewer has context. Then `claim release pr-<N> "$OWNER"`.
   Sibling loops may also be writing this file — every edit MUST be inside the lock; you are a
   serialized writer, not the sole one. Add `merged (#PR)` to the backlog's "Status values" header
   line the first time you introduce it.

6. META — improve THIS prompt (rare; only on concrete friction from THIS run). Reflect: was a REPO
   FACT stale (a path/command/check-name/merge-flag that moved)? Did an instruction force you to
   guess? Was a guardrail missing? Only on a concrete, observed fix — NOT speculative wordsmithing;
   most runs change nothing — make a SMALL surgical edit to `.claude/commands/toolbox-review.md`. This
   file IS tracked in git, but META edits are LOCAL working-tree changes in the orchestrator's main
   checkout — NEVER bundle them into a product PR; the maintainer commits prompt tweaks separately.
   Then append one dated line to the "Prompt revision log" at the bottom.
   IMMUTABLE — a self-edit must NEVER remove, weaken, or reword to loosen: the MERGE GATE; the VERIFY
   GATE; the HARD RULES; "never merge unless CI is green AND the diff matches the description"; "never
   touch/merge `main` directly"; "never force-push or rewrite a published branch"; "never close a PR";
   "never merge a PR touching `.github/workflows/*`"; "Cupertino-only / no new UI deps"; "never bump
   flutter_native_splash"; the one-PR-per-run scope; the orchestrator+worker execution model; or this
   META step. Preserve the file structure (frontmatter `description`, MISSION, EXECUTION MODEL,
   RELATIONSHIP, REPO FACTS, VERIFY GATE, REVIEW CRITERIA, MERGE GATE, CONCURRENCY, all seven steps,
   HARD RULES, revision log). Back the file up first; if afterward any required section is missing or
   the net change exceeds ~15 lines, RESTORE the backup and skip. This step must NEVER undo a merge
   already done this run.

7. REPORT one paragraph in this fixed shape, then END IMMEDIATELY:
   `pr:` <#N + one-line> · `status:` merged|fixed|pending|blocked|none · `ci:` <green|red|pending> ·
   `action:` <merged & backlog flipped | fixes pushed (awaiting CI) | left for human: reason | none> ·
   `backlog:` <row flipped to merged (#N), or —> · `follow-ups:` <new rows> · `meta:` <prompt
   self-edit made, or none>. The next iteration begins as soon as this one stops.

HARD RULES: never merge a PR unless EVERY MERGE-GATE condition holds (CI green AND diff matches the PR
description AND mergeable AND no workflow files AND review-clean); never touch or merge `main`
directly; never force-push or rewrite a published PR branch (only add commits or a clean
`merge origin/main`); never close a PR or delete a branch except via a successful `gh pr merge
--delete-branch`; never push code that fails the local VERIFY GATE; never commit generated/gitignored
files or the apparatus; never introduce `Material*`/`Scaffold`/`MaterialApp` or a new third-party UI
dependency and never let one through review; never bump `flutter_native_splash` off `^2.4.7`; keep
fixes surgical, in-scope, and style-matched; if nothing is mergeable or fixable this round, say so and
stop.

## Prompt revision log

Newest last; one line each, capped at the last ~20 entries.
Format: `YYYY-MM-DD — <change> (<why>)`.

- 2026-06-19 — Initial creation, modeled on `/toolbox-improve`: orchestrator+worker review loop that
  drives `toolbox-autoimprove` PRs to a verified merge. Merge gate = live CI green + diff matches PR
  description + mergeable + no workflow files + review-clean; reuses the shared
  `toolbox-improve-claim.sh` lock with `pr-<N>` / `tr-` namespacing; flips backlog `done (#PR)` →
  `merged (#PR)`. Encodes verified repo merge config (squash off, `--merge --delete-branch`, repo
  auto-merge off) and the gh-token workflow-scope guard.
