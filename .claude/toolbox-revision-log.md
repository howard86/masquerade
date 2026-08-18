# Toolbox loop commands — prompt revision log

Revision history for the `/toolbox-improve` and `/toolbox-review` loop commands
(`.claude/commands/toolbox-{improve,review}.md`). Kept here, OUT of the command files, so the
per-iteration prompt stays lean. The META step of each command appends one dated line to its section
below.

Newest last; one line each, capped at the last ~20 entries per command.
Format: `YYYY-MM-DD — <change> (<why>)`.

## /toolbox-improve

- 2026-06-19 — Initial adaptation of `engine-improve` for the Masquerade Flutter toolbox: Cupertino/UX
  mission, Flutter VERIFY GATE, tool-catalog + ToolBodyScaffold facts, `flutter_native_splash ^2.4.7`
  pin as a step-0 precondition, claim+lock helper. (From the hft-market-server template.)
- 2026-06-19 — Condensed the whole file for lower per-iteration token cost; no rule, gate, or step
  removed or weakened. (Maintainer request.)
- 2026-06-19 — Moved the revision log out of the command file into this shared file. (Maintainer
  request — keep the per-iteration prompt lean.)
- 2026-06-19 — Moved the backlog + claims out of `.claude/` to GLOBAL `~/.claude/`
  (`toolbox-improvement-backlog.md`, `toolbox-improve-claims/`) and repointed the claim helper to
  `$HOME/.claude` instead of `$SCRIPT_DIR`. (The tracked helper was forking claims/lock per git
  worktree; a global path keeps every loop on one shared backlog + claim set. Maintainer request.)
- 2026-07-29 — Base branch switched `main` → `develop` throughout (ORIENT fetch, worker branch point,
  `gh pr create --base`, next-iteration note); HARD RULES strengthened to forbid direct pushes to
  `develop` as well. Matches the repo's gitflow: `develop` is the default branch, `main` only receives
  Release PRs. (Maintainer request.)
- 2026-08-03 — SELECT: `in-progress` rows whose claim is STALE/missing are eligible again. (A loop
  dying between the mirror flip and RECORD left rows shadowed forever — the claim self-heals via
  TTL, the mirror text didn't, and the `open`-only filter never retried it. Maintainer fix, applied
  to `/engine-improve` too.)

## /toolbox-review

- 2026-06-19 — Initial creation, modeled on `/toolbox-improve`: orchestrator+worker review loop
  driving `toolbox-autoimprove` PRs to a verified merge. Merge gate = live CI green + diff matches PR
  description + mergeable + no workflow files + review-clean; reuses the shared
  `toolbox-improve-claim.sh` lock with `pr-<N>` / `tr-` namespacing; flips backlog `done (#PR)` →
  `merged (#PR)`. Encodes the verified repo merge config and the gh-token workflow-scope guard.
- 2026-06-19 — Condensed the whole file for lower per-iteration token cost; no rule, gate, or step
  removed or weakened. (Maintainer request.)
- 2026-06-19 — Moved the revision log out of the command file into this shared file. (Maintainer
  request — keep the per-iteration prompt lean.)
- 2026-06-19 — Backlog + claims relocated to GLOBAL `~/.claude/`; updated the shared-backlog and
  apparatus path references. (Same worktree-shared-state migration as `/toolbox-improve`.)
- 2026-07-29 — OWNER POLICY: branch updates now `git rebase origin/develop` + `git push
  --force-with-lease` (never back-merge commits — also dodges the workflow-scope push trap since
  rebase replays only the PR's own commits); workers babysit a pushed PR to a confirmed merge
  instead of reporting `fixed`/`pending`; base references corrected `main` → `develop` (gitflow).
  (Direct user instruction, this session.)
- 2026-07-30 — Three friction fixes from the #112/#116 run: refreshed the stale CI check names
  (now Analyze + Test shard 0/1/2 + Build web + Trivy + the "CI OK" aggregate; Release source policy
  and iOS bundle size join the ignorable SKIPPED set); defined BABYSIT concretely as blocking on
  `gh pr checks <N> --watch` (a worker returned `pending` mid-CI and needed a manual resume); noted
  that `gh pr merge --delete-branch`'s `fatal: 'develop' is already used by worktree` is local
  post-merge-checkout noise, not a failed merge.
- 2026-07-30 — REVIEW CRITERIA header still said `git diff origin/main...HEAD` while step ii and the
  2026-07-29 gitflow correction both say `develop`; the orchestrator had to fix it inline when writing
  the pr-237 worker prompt. Corrected to `origin/develop...HEAD`.
- 2026-07-30 — Three surviving stale `main` refs after the gitflow correction (step 0 and step i both
  said `git fetch origin main`; the MERGE GATE said "mergeable against current `main`"), which the
  orchestrator had to fix inline in the pr-239 worker prompt — all three now `develop`. Also broadened
  the `gh pr merge` cosmetic-noise note: the pr-239 worker hit a detached-HEAD local-checkout error
  (not the worktree variant) and had to confirm via `gh pr view --json state` that the server-side
  merge had in fact landed.
- 2026-07-30 — Step 5 said to "flip `done (#N)` → `merged (#N)`" in both the Index row and the detail
  block, but on pr-245 (TB-57) improve had only flipped the Index row — the detail block still read
  `Status: open`, so the literal flip instruction had no match there and invited skipping it. Reworded
  to SET Status to `merged (#N)` in both places regardless of the current value.
- 2026-07-30 — Resolved a contradiction the pr-246 review hit: the MERGE GATE said any fix means
  report `fixed` and never merge that run, while step-iii's FIXABLE branch said fix → babysit CI →
  merge → `merged`. Workers had to guess. MERGE GATE now states the fix path explicitly — never merge
  on the PRE-FIX CI run, babysit the re-run, merge once green on the fix commit; `fixed` is only for
  stopping short. No gate weakened.
