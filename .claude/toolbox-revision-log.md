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
