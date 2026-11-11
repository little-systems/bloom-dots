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
cp -r "$ROOT/shell/services" "$ROOT/shell/common" "$ROOT/shell/modules" "$HARNESS/"
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

# FileView does not emit saved() when identical text is submitted. A no-op
# must not leave the store waiting forever and block the next real write.
printf '{\n\t"entries": [\n\t\t1\n\t]\n}\n' > "$XDG_STATE_HOME/bloom/noop.json"
cp "$ROOT/tests/integration/state-noop-harness.qml" "$HARNESS/shell.qml"
timeout 12 qs --no-color -p "$HARNESS" > "$TEST_TMP/shell.log" 2>&1
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/noop.json")" '{"entries":[]}' 'save after an unchanged state'
pass "an unchanged save does not block the next real write"

# External edits are adopted, invalid shapes and oversized documents are
# quarantined, oversized saves are refused, and old backups are pruned.
printf '{ "n": 1 }\n' > "$XDG_STATE_HOME/bloom/watched.json"
printf '{ "items": 5 }\n' > "$XDG_STATE_HOME/bloom/shaped.json"
printf '{ "text": "%s" }\n' "$(printf 'x%.0s' {1..200})" > "$XDG_STATE_HOME/bloom/big.json"
printf '{ "small": 1 }\n' > "$XDG_STATE_HOME/bloom/budget.json"
printf '{ broken\n' > "$XDG_STATE_HOME/bloom/pruned.json"
for n in "" .~1~ .~2~ .~3~ .~4~ .~5~; do printf 'old %s\n' "$n" > "$XDG_STATE_HOME/bloom/pruned.json.bak$n"; done
cp "$ROOT/tests/integration/state-store-harness.qml" "$HARNESS/shell.qml"
timeout 15 qs --no-color -p "$HARNESS" > "$TEST_TMP/shell.log" 2>&1 || fail "store harness exited with an error"
log_has "RESULT watched-loaded=true invalid-shape-uses-default=true oversized-file-uses-default=true oversized-save-refused=true" || fail "schema/budget result: $(grep RESULT "$TEST_TMP/shell.log" | head -1)"
grep -qF '"items": 5' "$XDG_STATE_HOME/bloom/shaped.json.bak" || fail "invalid shape was not preserved"
[[ -f "$XDG_STATE_HOME/bloom/big.json.bak" ]] || fail "oversized file was not preserved"
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/budget.json")" '{"small":1}' "oversized save kept the file"
pass "invalid and oversized state is preserved aside; an oversized save is refused"
log_has "RESULT own-write-not-external=true" || fail "Bloom's own write was reported as an external change"
log_has "RESULT external-edit-adopted=true" || fail "external edit was not adopted"
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/watched.json")" '{"n":3}' "save after an external edit"
pass "an external edit is adopted and announced; Bloom's own writes are not"
backups=$(find "$XDG_STATE_HOME/bloom" -name 'pruned.json.bak*' | wc -l)
assert_eq "$backups" 3 "retained quarantine backups"
grep -qF '{ broken' "$XDG_STATE_HOME/bloom/pruned.json.bak" || fail "newest quarantine is not the plain .bak"
pass "quarantine keeps the three newest backups"
