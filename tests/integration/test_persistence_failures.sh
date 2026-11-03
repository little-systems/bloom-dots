#!/usr/bin/env bash
# Actual FileView failures, never writes against the real desktop.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
cleanup_permissions() {
    chmod 700 "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom" 2>/dev/null || true
    bloom_cleanup
}
trap cleanup_permissions EXIT
HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS" "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$HARNESS/"
cp "$ROOT/tests/integration/persistence-failure-harness.qml" "$HARNESS/shell.qml"
printf '{"bloom-theme-mode":"dark"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
printf '{"initial":true}\n' > "$XDG_STATE_HOME/bloom/failure.json"
chmod 500 "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
if ! timeout 12 qs --no-color -p "$HARNESS" > "$TEST_TMP/shell.log" 2>&1; then fail 'failure harness failed'; fi
chmod 700 "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
log_has 'RESULT settings-refused=true settings-kept=true' || fail 'settings falsely acknowledged a failed write'
log_has 'RESULT batch-atomic=true' || fail 'invalid batch applied only some settings'
log_has 'RESULT state-error=true pending=true' || fail 'state lost a failed pending write'
assert_eq "$(jq -r '."bloom-theme-mode"' "$XDG_CONFIG_HOME/bloom/settings.json")" dark 'settings file retained'
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/failure.json")" '{"initial":true}' 'state file retained'
pass 'failed persistence is reported, original data kept and pending state retained'
chmod 500 "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
if ! BLOOM_TEST_RETRY=1 timeout 12 qs --no-color -p "$HARNESS" > "$TEST_TMP/shell.log" 2>&1; then fail 'retry harness failed'; fi
log_has 'RESULT retry=true' || fail 'pending state did not recover after storage repair'
assert_eq "$(jq -r '."bloom-theme-mode"' "$XDG_CONFIG_HOME/bloom/settings.json")" light 'settings retry'
assert_eq "$(jq -r '."bloom-theme-opacity"' "$XDG_CONFIG_HOME/bloom/settings.json")" 0.7 'settings batch committed'
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/failure.json")" '{"changed":true}' 'state retry'
pass 'explicit retry persists held data after storage becomes writable'

mkdir -p "$TEST_TMP/bin"
printf '#!/bin/sh\nexit 1\n' > "$TEST_TMP/bin/mv"
chmod +x "$TEST_TMP/bin/mv"
printf '{broken\n' > "$XDG_STATE_HOME/bloom/failure.json"
cp "$ROOT/tests/integration/quarantine-failure-harness.qml" "$HARNESS/shell.qml"
PATH="$TEST_TMP/bin:$PATH" timeout 12 qs --no-color -p "$HARNESS" > "$TEST_TMP/shell.log" 2>&1
log_has 'RESULT quarantine-blocked=true' || fail 'quarantine failure allowed a write'
assert_eq "$(cat "$XDG_STATE_HOME/bloom/failure.json")" '{broken' 'corrupt evidence retained'
pass 'failed corruption backup blocks replacement and keeps the pending save'
