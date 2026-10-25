#!/usr/bin/env bash
# "ok" from Settings.set (and so from `bloom ipc settings set`) must mean the
# value is on disk: a shell stopped right after the reply must not lose it.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

# A config can only import QML from inside its own folder, so build one.
HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$HARNESS/"
cp "$ROOT/tests/integration/settings-harness.qml" "$HARNESS/shell.qml"

if ! QML_XHR_ALLOW_FILE_READ=1 timeout 15 qs --no-color -p "$HARNESS" >"$TEST_TMP/shell.log" 2>&1; then
	fail "a setting was not on disk when set returned"
fi
log_has "RESULT durable=5/5" || fail "unexpected harness result"
pass "a setting is on disk the moment set returns"
