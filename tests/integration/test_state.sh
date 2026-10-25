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
printf 'older backup\n' >"$XDG_STATE_HOME/bloom/corrupt.json.bak"
printf '{ "racy": [ \n' >"$XDG_STATE_HOME/bloom/racy.json"
printf '{ "old": 1 }\n' >"$XDG_STATE_HOME/bloom/early.json"

if ! timeout 15 qs --no-color -p "$HARNESS" >"$TEST_TMP/shell.log" 2>&1; then
	fail "harness exited with an error"
fi
log_has "RESULT corrupt-uses-default=true missing-uses-default=true early-save-wins=true" || fail "unexpected harness result"
[[ -f "$XDG_STATE_HOME/bloom/corrupt.json.bak" ]] || fail "corrupt file was not moved to .bak"
[[ ! -e "$XDG_STATE_HOME/bloom/corrupt.json" ]] || fail "corrupt file still in place"
log_has "is corrupt" || fail "no warning for the corrupt file"
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/fresh.json")" '["a","b"]' "saved state"
pass "corrupt state moves to .bak, missing state uses the default, save writes"

grep -qxF 'older backup' "$XDG_STATE_HOME"/bloom/corrupt.json.bak.~1~ || fail "an earlier .bak was overwritten"
pass "an earlier .bak is kept"

assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/racy.json")" '["saved"]' "save right after a corrupt load"
grep -qF '{ "racy": [' "$XDG_STATE_HOME/bloom/racy.json.bak" || fail "corrupt racy.json was not backed up"
pass "a save right after a corrupt load is kept, and the corrupt file is still backed up"

assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/early.json")" '{"fresh":1}' "save before load"
pass "a save before the file has loaded wins over the old file"
