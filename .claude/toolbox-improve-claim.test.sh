#!/usr/bin/env bash
set -u

HELPER="${1:-$(dirname "$0")/toolbox-improve-claim.sh}"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
export TOOLBOX_BASE="$TEST_ROOT"
fail=0

check() {
  if [ "$2" = "$3" ]; then
    printf 'ok - %s\n' "$1"
  else
    printf 'FAIL - %s: got %s, want %s\n' "$1" "$2" "$3"
    fail=1
  fi
}

CLAIM_SESSION_ID=old "$HELPER" acquire TB-X same-owner >/dev/null
check "other session cannot release" \
  "$(CLAIM_SESSION_ID=new "$HELPER" release TB-X same-owner | cut -d' ' -f1)" "NOT-YOURS"
check "claim remains held" \
  "$(CLAIM_SESSION_ID=old "$HELPER" list | awk '$1 == "TB-X" {print $2}')" "HELD"
check "owning session releases" \
  "$(CLAIM_SESSION_ID=old "$HELPER" release TB-X same-owner | cut -d' ' -f1)" "RELEASED"

CLAIM_SESSION_ID=old "$HELPER" lock same-owner >/dev/null
check "other session cannot unlock" \
  "$(CLAIM_SESSION_ID=new "$HELPER" unlock same-owner | cut -d' ' -f1)" "LOCK-NOT-YOURS"
check "owning session unlocks" \
  "$(CLAIM_SESSION_ID=old "$HELPER" unlock same-owner | cut -d' ' -f1)" "UNLOCKED"

CLAIM_SESSION_ID=old "$HELPER" acquire TB-Y guarded-owner >/dev/null
mkdir "$TEST_ROOT/toolbox-improve-claims/claim-TB-Y/.takeover"
check "release is serialized with takeover" \
  "$(CLAIM_SESSION_ID=old "$HELPER" release TB-Y guarded-owner | cut -d' ' -f1)" "RELEASE-BUSY"
rmdir "$TEST_ROOT/toolbox-improve-claims/claim-TB-Y/.takeover"

CLAIM_SESSION_ID=old "$HELPER" acquire TB-Z stale-owner >/dev/null
touch -t 202001010000 "$TEST_ROOT/toolbox-improve-claims/claim-TB-Z/owner"
check "takeover guard does not refresh stale age" \
  "$(TOOLBOX_CLAIM_TTL=1 CLAIM_SESSION_ID=new "$HELPER" acquire TB-Z new-owner | cut -d' ' -f1)" "RECLAIMED"

exit "$fail"
