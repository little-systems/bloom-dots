#!/usr/bin/env bash
# Supervised backend processes restart with bounded backoff, report missing
# programs, stop when unwanted and recover on an explicit retry.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$HARNESS/"
cp "$ROOT/tests/integration/supervised-harness.qml" "$HARNESS/shell.qml"
timeout 15 qs --no-color -p "$HARNESS" > "$TEST_TMP/shell.log" 2>&1 || fail "harness exited with an error"
log_has "RESULT flaky-restarts=true flaky-degraded=true missing=true missing-retries=true steady=true idle-not-running=true" || fail "supervision: $(grep RESULT "$TEST_TMP/shell.log" | head -1)"
pass "exits restart with backoff, missing programs are reported and retried, unwanted processes don't start"
log_has "RESULT steady-stopped=true flaky-stopped=true" || fail "unwanted processes were not stopped"
log_has "RESULT no-restart-when-unwanted=true" || fail "an unwanted process restarted"
pass "a process that is no longer wanted stops and stays stopped"
log_has "RESULT retry-recovers=true" || fail "retry did not recover"
log_has "RESULT unknown-retry-refused=true" || fail "a retry for an unknown backend was accepted"
log_has "bloom capability: missing missing" || fail "the missing capability was not logged"
# An absent program is normal on many machines; a backend that broke warns.
grep -qE 'INFO.*bloom capability: missing missing' "$TEST_TMP/shell.log" || fail "missing was not logged as info"
if grep -qE 'WARN.*bloom capability: missing missing' "$TEST_TMP/shell.log"; then fail "missing was logged as a warning"; fi
grep -qE 'WARN.*bloom capability: flaky degraded' "$TEST_TMP/shell.log" || fail "a broken backend did not warn"
pass "an explicit retry recovers and resets the backoff"
log_has "RESULT restart-not-a-failure=true" || fail "restart counted as a failure"
pass "restart applies a new command without counting a failure"
