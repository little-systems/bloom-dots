#!/usr/bin/env bash
# Runs StateFile in a harness: corrupt files move to .bak, missing files use
# the default, save() writes the file.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

# A config can only import QML from inside its own folder, so build one.
HARNESS="$TEST_TMP/harness"
mkdir -p "$HARNESS"
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$HARNESS/"
cp "$ROOT/tests/integration/state-harness.qml" "$HARNESS/shell.qml"

mkdir -p "$XDG_STATE_HOME/bloom"
printf '{ "items": [ \n' >"$XDG_STATE_HOME/bloom/corrupt.json"

if ! timeout 15 qs --no-color -p "$HARNESS" >"$TEST_TMP/shell.log" 2>&1; then
	fail "harness exited with an error"
fi
log_has "RESULT corrupt-uses-default=true missing-uses-default=true" || fail "unexpected harness result"
[[ -f "$XDG_STATE_HOME/bloom/corrupt.json.bak" ]] || fail "corrupt file was not moved to .bak"
[[ ! -e "$XDG_STATE_HOME/bloom/corrupt.json" ]] || fail "corrupt file still in place"
log_has "is corrupt" || fail "no warning for the corrupt file"
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/fresh.json")" '["a","b"]' "saved state"
pass "corrupt state moves to .bak, missing state uses the default, save writes"
