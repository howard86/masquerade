#!/usr/bin/env bash
# toolbox-improve-claim.sh — mkdir-atomic claim + lock helper for the
# /toolbox-improve loop. LOCAL + gitignored. Lets several loops run at once
# (and lets a crashed loop self-heal) by coordinating ONLY through files in a
# GLOBAL claims dir under ~/.claude, shared across all git worktrees. Generate an
# OWNER token once per run and pass the SAME literal string to every call:
#   OWNER="tb-$(hostname -s)-$(date +%s)-$$"
#
# Usage:
#   claim list
#   claim acquire <ID> "$OWNER"   exit 0 = you own it; exit 1 = HELD by a live loop
#   claim release <ID> "$OWNER"
#   claim lock "$OWNER"  / claim unlock "$OWNER"   wrap every backlog read-modify-write
set -u

# Resolve state from $HOME/.claude (NOT relative to this script): the helper is a
# TRACKED file copied into every git worktree, so a script-relative path would
# fork the claims/lock per worktree. The global path keeps every loop on one set.
BASE="${TOOLBOX_BASE:-$HOME/.claude}"
CLAIMS_DIR="${TOOLBOX_CLAIMS_DIR:-$BASE/toolbox-improve-claims}"
LOCK_DIR="$CLAIMS_DIR/.lock"
CLAIM_TTL="${TOOLBOX_CLAIM_TTL:-3600}"   # 60 min — a worker run can be long; reclaim a dead one after this
LOCK_TTL="${TOOLBOX_LOCK_TTL:-120}"      # 2 min — locks only wrap quick backlog edits
SESSION_ID="${CLAIM_SESSION_ID:-${CODEX_THREAD_ID:-${CLAUDE_SESSION_ID:-${KIRO_SESSION_ID:-}}}}"

mkdir -p "$CLAIMS_DIR"

now()  { date +%s; }
mtime() { if stat -f %m "$1" >/dev/null 2>&1; then stat -f %m "$1"; else stat -c %Y "$1"; fi; }  # macOS + Linux
age_of() { # <dir>; child guard creation must not refresh the lease age
  stamp="$1/owner"; [ -f "$stamp" ] || stamp="$1"
  echo $(( $(now) - $(mtime "$stamp") ))
}
write_state() { # <dir> <owner>
  printf '%s' "$2" > "$1/.owner.tmp" &&
    mv -f "$1/.owner.tmp" "$1/owner" &&
    printf '%s' "$SESSION_ID" > "$1/.session.tmp" &&
    mv -f "$1/.session.tmp" "$1/session"
}
session_ok() { # <dir>; legacy claims/callers remain releasable by exact owner
  held_session="$(cat "$1/session" 2>/dev/null || echo '')"
  [ -z "$held_session" ] || [ -z "$SESSION_ID" ] || [ "$held_session" = "$SESSION_ID" ]
}

cmd="${1:-}"; shift 2>/dev/null || true

case "$cmd" in
  list)
    found=0
    for d in "$CLAIMS_DIR"/claim-*; do
      [ -d "$d" ] || continue
      found=1
      id="${d##*/claim-}"
      owner="$(cat "$d/owner" 2>/dev/null || echo '?')"
      session="$(cat "$d/session" 2>/dev/null || echo 'legacy')"
      age="$(age_of "$d")"
      state="HELD"; [ "$age" -gt "$CLAIM_TTL" ] && state="STALE"
      printf '%s\t%s\t%s\tsession=%s\tage=%ss\n' "$id" "$state" "$owner" "${session:-legacy}" "$age"
    done
    [ "$found" = 0 ] && echo "(no claims)"
    ;;

  acquire)
    id="${1:?usage: acquire <id> <owner>}"; owner="${2:?usage: acquire <id> <owner>}"
    d="$CLAIMS_DIR/claim-$id"
    if mkdir "$d" 2>/dev/null; then
      write_state "$d" "$owner" || { rm -rf "$d"; echo "CLAIM-FAILED $id"; exit 1; }
      echo "CLAIMED $id"; exit 0
    fi
    cur="$(cat "$d/owner" 2>/dev/null || echo '')"
    [ "$cur" = "$owner" ] && session_ok "$d" && { touch "$d"; echo "ALREADY-YOURS $id"; exit 0; }
    age="$(age_of "$d")"
    if [ "$age" -gt "$CLAIM_TTL" ]; then
      if mkdir "$d/.takeover" 2>/dev/null; then
        age="$(age_of "$d")"
        if [ "$age" -gt "$CLAIM_TTL" ] && write_state "$d" "$owner"; then
          rmdir "$d/.takeover" 2>/dev/null
          touch "$d"; echo "RECLAIMED $id (stale ${age}s)"; exit 0
        fi
        rmdir "$d/.takeover" 2>/dev/null
      fi
    fi
    echo "HELD $id by ${cur:-?} (age=${age}s)"; exit 1
    ;;

  release)
    id="${1:?usage: release <id> <owner>}"; owner="${2:?usage: release <id> <owner>}"
    d="$CLAIMS_DIR/claim-$id"
    [ -d "$d" ] || { echo "RELEASED $id"; exit 0; }
    mkdir "$d/.takeover" 2>/dev/null || { echo "RELEASE-BUSY $id"; exit 1; }
    cur="$(cat "$d/owner" 2>/dev/null || echo '')"
    if [ -n "$cur" ] && [ "$cur" = "$owner" ] && session_ok "$d"; then
      rm -rf "$d"; echo "RELEASED $id"
    else
      rmdir "$d/.takeover" 2>/dev/null
      echo "NOT-YOURS $id (owner=${cur:-?})"
    fi
    exit 0
    ;;

  lock)
    owner="${1:?usage: lock <owner>}"
    i=0
    while [ "$i" -lt 100 ]; do
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        write_state "$LOCK_DIR" "$owner" || { rm -rf "$LOCK_DIR"; echo "LOCK-FAILED"; exit 1; }
        echo "LOCKED"; exit 0
      fi
      age="$(age_of "$LOCK_DIR")"
      if [ "$age" -gt "$LOCK_TTL" ] && mkdir "$LOCK_DIR/.takeover" 2>/dev/null; then
        age="$(age_of "$LOCK_DIR")"
        if [ "$age" -gt "$LOCK_TTL" ]; then rm -rf "$LOCK_DIR"; continue; fi
        rmdir "$LOCK_DIR/.takeover" 2>/dev/null
      fi
      sleep 1; i=$((i+1))
    done
    echo "LOCK-TIMEOUT"; exit 1
    ;;

  unlock)
    owner="${1:?usage: unlock <owner>}"
    [ -d "$LOCK_DIR" ] || { echo "UNLOCKED"; exit 0; }
    mkdir "$LOCK_DIR/.takeover" 2>/dev/null || { echo "LOCK-BUSY"; exit 1; }
    cur="$(cat "$LOCK_DIR/owner" 2>/dev/null || echo '')"
    if [ -n "$cur" ] && [ "$cur" = "$owner" ] && session_ok "$LOCK_DIR"; then
      rm -rf "$LOCK_DIR"; echo "UNLOCKED"
    else
      rmdir "$LOCK_DIR/.takeover" 2>/dev/null
      echo "LOCK-NOT-YOURS (owner=${cur:-?})"
    fi
    exit 0
    ;;

  *)
    echo "usage: $0 {list | acquire <id> <owner> | release <id> <owner> | lock <owner> | unlock <owner>}" >&2
    exit 2
    ;;
esac
