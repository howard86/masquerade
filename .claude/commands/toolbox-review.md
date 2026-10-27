---
description: One toolbox PR-review iteration — pick one open `toolbox-autoimprove` PR, delegate review+fix+merge to a fresh worker, merge ONLY when CI is green and the diff matches the PR description, then flip the backlog row to `merged`. Loop via `/loop /toolbox-review`.
---

MISSION: Be the REVIEWER for the PRs `/toolbox-improve` produces — the second pair of eyes that loop
deliberately lacks (it never merges its own work). Drive each `toolbox-autoimprove` PR to a clean,
verified merge, one PR per run: MERGE what's correct, in-scope, and green; FIX what's close; BLOCK
what needs a human. A wrong merge into `main` is far costlier than a PR left open one more round.

EXECUTION MODEL — orchestrator + worker (keeps the loop's context small):
- YOU are the ORCHESTRATOR: orient, list open PRs, dedupe against live claims, SELECT one PR, confirm
  the outcome, RECORD the backlog flip, REPORT.
- A fresh WORKER subagent checks out the PR branch, runs the VERIFY GATE + diff review, applies fixes,
  pushes, and merges — in ITS OWN context, returning only a small structured result. No build/diff
  output reaches you.
- The worker is a fresh `general-purpose` Agent, `isolation: worktree` (NOT a fork). Hand it the PR
  number + branch, PR body, REVIEW + MERGE GATES, REPO FACTS, and (if found) the backlog detail block,
  all INLINE. It checks out the EXISTING PR branch inside its worktree (`git fetch origin <branch>` +
  `git checkout <branch>`; the harness branch is abandoned). NEVER tell it to read the backlog (the
  orchestrator's GLOBAL shared state at `~/.claude/toolbox-improvement-backlog.md` — the worker gets
  only the detail block, inline).
- CONCURRENCY: many loops (improve AND review) run at once, coordinating ONLY via local files. Reuse
  the improve loop's helper `.claude/toolbox-improve-claim.sh` so the global backlog LOCK is SHARED
  across both loops (REQUIRED — a second lock corrupts the backlog). Review CLAIMS are `pr-<N>` (never
  collide with `TB-NN`). CLAIM a PR BEFORE delegating.

RELATIONSHIP TO `/toolbox-improve`: improve marks the backlog row `done (#PR)` when the PR is CREATED
— `done` = PR open, NOT merged. Your job turns `done (#PR)` → `merged (#PR)`. The loops share the
backlog (`~/.claude/toolbox-improvement-backlog.md`, GLOBAL — reachable from every worktree), the lock,
and the `toolbox-autoimprove` label, nothing else.

REPO FACTS (pass relevant ones to the worker verbatim; fuller list in
`.claude/commands/toolbox-improve.md`):
- Flutter 3.41.8. Cupertino ONLY (`uses-material-design: false`). A PR adding
  `Material*`/`Scaffold`/`MaterialApp` or a new third-party UI dep FAILS review — report
  `blocked (review-reject)`, don't merge.
- Lean deps (cupertino_icons, intl, package_info_plus, shared_preferences + shipped: qr,
  flutter_lucide, url_launcher, json_annotation, flutter_native_splash); dev: flutter_test +
  flutter_lints. A PR adding a dep without wiring (codegen/CI) is suspect.
- DEP GOTCHA (LIVE): `flutter_native_splash` MUST stay `^2.4.7` (2.4.8 needs `meta ^1.18.0` vs
  flutter_test's `meta 1.17.0` → `pub get` fails). A PR bumping it FAILS review. If `pub get` fails on
  this in-worktree, re-pin `^2.4.7` + regen lock ONLY if in this PR's scope, else
  `blocked (env: native_splash)`.
- TOOL ARCHITECTURE: tools = entry in `lib/utility_catalog.dart` + body under
  `lib/widgets/tool_bodies/`; bodies reuse `ToolBodyScaffold` + `LinkableToolBody`; parsers PURE
  static `parse()` under `lib/utils/`. Prefer `mq/*`; colors via `MqTheme.of(context)`. Tests MIRROR
  `lib/` under `test/`; new functionality REQUIRES tests.
- Base `develop` (gitflow — `main` only receives Release PRs), Conventional Commits (commitizen). Fix commits use `fix:`/`refactor:`/`test:`, never
  `deps(deps):`.
- MERGE CONFIG (verified): squash DISABLED; merge-commit + rebase allowed; repo auto-merge OFF (so
  `--auto` won't work — merge immediately); branches auto-delete; `main` NOT protected. Merge =
  `gh pr merge <N> --merge --delete-branch`. COSMETIC NOISE: that command may print
  `fatal: 'develop' is already used by worktree ...` OR a detached-HEAD checkout error from its LOCAL
  post-merge checkout — the server-side merge and branch deletion still succeeded; always confirm with
  `gh pr view <N> --json state` before retrying or reporting failure.
- gh TOKEN LACKS `workflow` SCOPE: a PR whose diff touches `.github/workflows/*` CANNOT be merged here
  — report `blocked (needs workflow-scope token; human merge)`, don't attempt.
- Worktrees at `.worktrees/<branch>` (gitignored). PostToolUse hook runs `dart format` on edited
  `*.dart` — fix format errors.
- NEVER commit generated/gitignored paths (`build/`, `coverage/`, `.dart_tool/`, `*.symbols`) or
  apparatus — verify logs (`.claude/toolbox-verify-*.log`) in-repo, plus the GLOBAL shared state under
  ~/.claude (backlog `~/.claude/toolbox-improvement-backlog.md`, claims `~/.claude/toolbox-improve-claims/`).
  A PR that committed any is a review finding — strip it as a fix.

VERIFY GATE (worker runs LOCALLY before pushing ANY fix; never push red):
    flutter pub get                                  # must resolve (see DEP GOTCHA)
    dart format --output=none --set-exit-if-changed .
    flutter analyze                                  # SUCCESS = exactly "No issues found!"
    flutter test --coverage                          # SUCCESS = "All tests passed!"
  For web/manifest/splash/asset changes ALSO `flutter build web --release`. Capture to a logfile,
  surface only failure markers. analyze FAILS on any `error •`/`warning •`/`info •`; test FAILS on
  "Some tests failed.", "[E]", "Failed to load". Run flutter in the FOREGROUND.

REVIEW CRITERIA (over `git diff origin/develop...HEAD` — base is `develop`, not `main`):
  1. CORRECTNESS — does what it claims, no bug/regression/crash-on-bad-input; parsers pure +
     concern-separated; errors precise.
  2. SCOPE / DESCRIPTION MATCH — the PR body's "what changed" + verification evidence match the ACTUAL
     diff + commits; no scope creep, no absent claimed test, no committed apparatus. (The user's hard
     gate: "commits match the PR description.")
  3. CONVENTIONS — Cupertino-only; `mq/*` + `MqTheme.of(context)`; `ToolBodyScaffold`/`LinkableToolBody`
     reused; Conventional Commits.
  4. TESTS — new functionality has mirrored tests that actually assert the claimed behavior.
  5. CI — Flutter CI checks ("Pre-commit hooks", "Analyze", "Test (shard 0/1/2)", "Build web",
     "Security scan", "Trivy", + the "CI OK" aggregate gate) all SUCCESS. Netlify is NEUTRAL;
     dependabot / "Release source policy" / "iOS bundle size" may be SKIPPED — ignore those.
     PENDING ≠ green.

MERGE GATE — merge ONLY when ALL hold (else FIX or BLOCK): live CI all-green; review clean (no
correctness/Cupertino/dep violation); diff + commits match the PR description; mergeable against
the current base (`develop`); diff does NOT touch `.github/workflows/*`. If the worker applies ANY fix, the local
VERIFY GATE must pass before pushing and it must NOT merge on the pre-fix CI run — it BABYSITS the
re-run (`gh pr checks <N> --watch`) and merges only once CI is green again on the fix commit
(→ `merged`). It reports `fixed` only if it stops before that (CI red out-of-scope, or run cut short);
a later iteration then merges once CI re-greens.

CONCURRENCY — shared helper `.claude/toolbox-improve-claim.sh` (local, untracked, mkdir-atomic,
TTL-reclaimable). Generate OWNER once and reuse the literal: `OWNER="tr-$(hostname -s)-$(date +%s)-$$"`
(`tr-` vs improve's `tb-`). First export
`CLAIM_SESSION_ID="${CODEX_THREAD_ID:-${CLAUDE_SESSION_ID:-${KIRO_SESSION_ID:-}}}"`; include
`${CLAIM_SESSION_ID:-legacy}` in OWNER before the hostname. `claim` = `bash .claude/toolbox-improve-claim.sh`:
  - `claim list` — HELD/STALE claims (both loops).
  - `claim acquire pr-<N> "$OWNER"` — exit 0 = yours; exit 1 = HELD (skip).
  - `claim release pr-<N> "$OWNER"` — drop (after RECORD, or on blocked/pending).
  - `claim lock|unlock "$OWNER"` — wrap EVERY backlog read-modify-write; the lock is GLOBAL + SHARED
    with improve; keep it to just the edit, never across a delegate.
Never delete a claim directory or release another session's claim based on a quiet
worktree or missing checkpoint. Before TTL the recorded session is authoritative;
after TTL reclaim through `claim acquire` so takeover remains atomic.

PROCEDURE — all seven steps, then end:

0. ORIENT: generate + print OWNER once; `git fetch origin develop`. List candidates oldest-first
   (earliest-merged keeps later PRs rebasing cleanly): `gh pr list --label toolbox-autoimprove --state
   open --json number,title,headRefName,createdAt --jq 'sort_by(.createdAt) | .[] |
   "\(.number)\t\(.headRefName)\t\(.title)"'`. `claim list` for HELD `pr-*`. If no open PRs, REPORT
   "nothing to review" + STOP.

1. SELECT the OLDEST open `toolbox-autoimprove` PR whose `pr-<N>` isn't HELD. CLAIM before delegating:
   `claim acquire pr-<N> "$OWNER"` (exit 1 → next-oldest until one sticks; ≤~3/run). No backlog mirror
   needed — the row already reads `done (#N)`; your only write is the merge flip in step 5.

2. PLAN (brief) — PR number + head branch; the PR body (`gh pr view <N> --json body --jq .body`); and,
   if a backlog row's Status contains `(#N)`, that item's detail block INLINE. One paragraph for the
   worker.

3. DELEGATE — one fresh `general-purpose` Agent (`isolation: worktree`, NOT fork). Prompt MUST include
   verbatim: relevant REPO FACTS, the VERIFY GATE, the REVIEW CRITERIA, the MERGE GATE, the HARD
   RULES, the PLAN, PR number + head branch, and the PR body (+ detail block) INLINE. The worker
   returns ONLY the step-v result:
     i.   CHECK OUT the PR branch: `git fetch origin develop`, `git fetch origin <branch>`,
          `git checkout <branch>`; confirm HEAD = PR head.
     ii.  REVIEW the diff (`git diff origin/develop...HEAD`, `git log origin/develop..HEAD`) against the
          REVIEW CRITERIA; read CI + mergeability
          (`gh pr view <N> --json statusCheckRollup,mergeable,mergeStateStatus`); check the diff
          doesn't touch `.github/workflows/*`.
     iii. DECIDE:
          - ALL gate conditions hold → `gh pr merge <N> --merge --delete-branch`; confirm
            `gh pr view <N> --json state` = MERGED → `merged`.
          - FIXABLE (failing/missing test, analyzer nit, review finding, committed apparatus,
            behind/conflicting base) → minimal in-scope fix; for a stale or conflicted branch
            `git rebase origin/develop` + `git push --force-with-lease` (OWNER POLICY 2026-07-29:
            rebase, NEVER a back-merge commit of the base — rebase also replays only the PR's own
            commits, dodging the workflow-scope push trap); run the FULL local VERIFY GATE before
            pushing; commit (Conventional Commits); then BABYSIT: poll CI every ~3-5 min until all
            checks SUCCESS and merge per the MERGE GATE → `merged` (CI red on an out-of-scope
            cause → `blocked`).
          - CI still PENDING and otherwise clean → BABYSIT (poll until resolved), then decide.
            BABYSIT means BLOCK on `gh pr checks <N> --watch` in the FOREGROUND (it exits when every
            check is terminal), then re-read the rollup — do NOT return a pending status while the PR
            is merely mergeable-but-pending (workers keep doing this; spell it out in their prompt).
          - NEEDS A HUMAN (workflow files; a Material/dep violation or correctness bug not fixable
            in-scope; non-trivial conflict; diff contradicts the description as a real defect) →
            nothing destructive, NEVER close the PR → `blocked` + reason.
     iv.  Update a published branch ONLY via `git rebase origin/develop` + `git push
          --force-with-lease` (OWNER POLICY 2026-07-29 — no back-merge commits); NEVER merge unless
          every gate holds; NEVER touch `develop`/`main` directly; do NOT stop while the PR is
          mergeable-but-pending — babysit to a confirmed merge.
     v.   RETURN compact JSON only (no logs): `{ pr, head, item_id, status:
          merged|fixed|pending|blocked, ci, review_summary, fixes[], blocked_reason, follow_ups[] }` —
          ALWAYS the final output.

4. INGEST + NEXT: read the result. If `merged`, INDEPENDENTLY confirm `gh pr view <N> --json
   state,mergedAt` before recording. If `fixed`/`pending`/`blocked`, the PR stays open — do step 5 (no
   flip; optional note), `claim release pr-<N> "$OWNER"`, RETURN to step 1 for the next eligible PR
   (≤~3/run). STOP early only on an environmental failure or no eligible PR.

5. RECORD (you write the shared backlog, NOT part of any PR; lock first):
   - On `merged`: `claim lock "$OWNER"`; find the row whose Status contains `(#N)` and SET Status to
     `merged (#N)` in BOTH the Index row AND its detail block — improve often flips only the Index
     row, so the detail block may still read `open`; set it regardless of what it currently says,
     don't skip it because there's no literal `done (#N)` there; append worker
     `follow_ups`; `claim unlock`. (No row references `(#N)` → skip + note.) Then
     `claim release pr-<N> "$OWNER"`. Add `merged (#PR)` to the backlog's "Status values" header the
     first time you use it.
   - On `fixed`/`pending`/`blocked`: leave the row `done (#N)`; optionally append a short
     ` — review: <reason>` note under the lock. Then `claim release pr-<N> "$OWNER"`.
   Every edit MUST be inside the lock (siblings also write).

6. META — improve THIS prompt (rare; only on concrete friction THIS run: a stale REPO
   FACT/check-name/merge-flag, an instruction that forced a guess, a missing guardrail). SMALL
   surgical edit to `.claude/commands/toolbox-review.md` + one dated line in this command's section of
   the revision log at `.claude/toolbox-revision-log.md` (a separate tracked file — NOT in this
   prompt). This file is tracked, but META edits are LOCAL working-tree changes — NEVER bundle into a
   product PR. IMMUTABLE
   — never remove, weaken, or reword to loosen: the MERGE GATE; the VERIFY GATE; the HARD RULES;
   "merge only when CI is green AND the diff matches the description"; "never touch/merge main
   directly"; "branch updates only by rebase + `--force-with-lease`" (owner-set 2026-07-29);
   "never close a PR"; "never merge a PR
   touching `.github/workflows/*`"; "Cupertino-only / no new UI deps"; "never bump
   flutter_native_splash"; one-PR-per-run; the orchestrator+worker model; this META step. Preserve the
   section structure (frontmatter `description`, MISSION, EXECUTION MODEL, RELATIONSHIP, REPO FACTS,
   VERIFY GATE, REVIEW CRITERIA, MERGE GATE, CONCURRENCY, all seven steps, HARD RULES).
   Back up first; if a required section goes missing or the net change exceeds ~15 lines, RESTORE and
   skip. Never undo a merge done this run.

7. REPORT one paragraph, then END: `pr:` <#N + one-line> · `status:` merged|fixed|pending|blocked|none
   · `ci:` <green|red|pending> · `action:` <merged & backlog flipped | fixes pushed (awaiting CI) |
   left for human: reason | none> · `backlog:` <flipped to merged (#N), or —> · `follow-ups:` <new
   rows> · `meta:` <self-edit, or none>.

HARD RULES: never merge unless EVERY MERGE-GATE condition holds (CI green AND diff matches the
description AND mergeable AND no workflow files AND review-clean); never touch or merge `main`
directly; update a published PR branch only via `git rebase origin/develop` + `git push
--force-with-lease` (OWNER POLICY 2026-07-29 — never add back-merge commits of the base); babysit a
pushed PR to a confirmed merge before stopping; never close a PR or delete a branch except via a successful `gh pr merge
--delete-branch`; never push code failing the local VERIFY GATE; never commit generated/gitignored
files or the apparatus; never introduce `Material*`/`Scaffold`/`MaterialApp` or a new third-party UI
dep, or let one through review; never bump `flutter_native_splash` off `^2.4.7`; keep fixes surgical,
in-scope, style-matched; if nothing is mergeable or fixable, say so and stop.

Prompt revision history lives in `.claude/toolbox-revision-log.md` (a separate tracked file), not here.
