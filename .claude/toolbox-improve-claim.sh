#!/usr/bin/env bash
# toolbox-improve-claim.sh — mkdir-atomic claim + lock helper for the
# /toolbox-improve loop. LOCAL + gitignored. Lets several loops run at once
# (and lets a crashed loop self-heal) by coordinating ONLY through files in a
# claims dir next to this script. Generate an OWNER token once per run and pass
# the SAME literal string to every call:  OWNER="tb-$(hostname -s)-$(date +%s)-$$"
#
# Usage:
#   claim list
#   claim acquire <ID> "$OWNER"   exit 0 = you own it; exit 1 = HELD by a live loop
#   claim release <ID> "$OWNER"
#   claim lock "$OWNER"  / claim unlock "$OWNER"   wrap every backlog read-modify-write
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAIMS_DIR="${TOOLBOX_CLAIMS_DIR:-$SCRIPT_DIR/.toolbox-claims}"
LOCK_DIR="$CLAIMS_DIR/.lock"
CLAIM_TTL="${TOOLBOX_CLAIM_TTL:-3600}"   # 60 min — a worker run can be long; reclaim a dead one after this
LOCK_TTL="${TOOLBOX_LOCK_TTL:-120}"      # 2 min — locks only wrap quick backlog edits

mkdir -p "$CLAIMS_DIR"

now()  { date +%s; }
mtime() { if stat -f %m "$1" >/dev/null 2>&1; then stat -f %m "$1"; else stat -c %Y "$1"; fi; }  # macOS + Linux

cmd="${1:-}"; shift 2>/dev/null || true

case "$cmd" in
  list)
    found=0
    for d in "$CLAIMS_DIR"/claim-*; do
      [ -d "$d" ] || continue
      found=1
      id="${d##*/claim-}"
      owner="$(cat "$d/owner" 2>/dev/null || echo '?')"
      age=$(( $(now) - $(mtime "$d") ))
      state="HELD"; [ "$age" -gt "$CLAIM_TTL" ] && state="STALE"
      printf '%s\t%s\t%s\tage=%ss\n' "$id" "$state" "$owner" "$age"
    done
    [ "$found" = 0 ] && echo "(no claims)"
    ;;

  acquire)
    id="${1:?usage: acquire <id> <owner>}"; owner="${2:?usage: acquire <id> <owner>}"
    d="$CLAIMS_DIR/claim-$id"
    if mkdir "$d" 2>/dev/null; then
      printf '%s' "$owner" > "$d/owner"; echo "CLAIMED $id"; exit 0
    fi
    cur="$(cat "$d/owner" 2>/dev/null || echo '')"
    [ "$cur" = "$owner" ] && { touch "$d"; echo "ALREADY-YOURS $id"; exit 0; }
    age=$(( $(now) - $(mtime "$d") ))
    if [ "$age" -gt "$CLAIM_TTL" ]; then
      printf '%s' "$owner" > "$d/owner"; touch "$d"; echo "RECLAIMED $id (stale ${age}s)"; exit 0
    fi
    echo "HELD $id by ${cur:-?} (age=${age}s)"; exit 1
    ;;

  release)
    id="${1:?usage: release <id> <owner>}"; owner="${2:?usage: release <id> <owner>}"
    d="$CLAIMS_DIR/claim-$id"
    cur="$(cat "$d/owner" 2>/dev/null || echo '')"
    if [ -d "$d" ] && { [ "$cur" = "$owner" ] || [ -z "$cur" ]; }; then
      rm -rf "$d"; echo "RELEASED $id"
    else
      echo "NOT-YOURS $id (owner=${cur:-?})"
    fi
    exit 0
    ;;

  lock)
    owner="${1:?usage: lock <owner>}"
    i=0
    while [ "$i" -lt 100 ]; do
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s' "$owner" > "$LOCK_DIR/owner"; echo "LOCKED"; exit 0
      fi
      age=$(( $(now) - $(mtime "$LOCK_DIR") ))
      [ "$age" -gt "$LOCK_TTL" ] && { rm -rf "$LOCK_DIR"; continue; }   # self-heal a dead holder
      sleep 1; i=$((i+1))
    done
    echo "LOCK-TIMEOUT"; exit 1
    ;;

  unlock)
    owner="${1:?usage: unlock <owner>}"
    cur="$(cat "$LOCK_DIR/owner" 2>/dev/null || echo '')"
    if [ "$cur" = "$owner" ] || [ -z "$cur" ]; then rm -rf "$LOCK_DIR"; echo "UNLOCKED"; else echo "LOCK-NOT-YOURS (owner=${cur:-?})"; fi
    exit 0
    ;;

  *)
    echo "usage: $0 {list | acquire <id> <owner> | release <id> <owner> | lock <owner> | unlock <owner>}" >&2
    exit 2
    ;;
esac
