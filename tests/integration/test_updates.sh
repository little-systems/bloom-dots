#!/usr/bin/env bash
# The Updates service end to end with a fake checkupdates: counts, a failed
# check keeping the last good count, a missing tool, and arrivals.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

mkdir -p "$TEST_TMP/bin" "$XDG_CONFIG_HOME/bloom"
cp "$ROOT/tests/integration/updates-fake.sh" "$TEST_TMP/bin/checkupdates"
chmod +x "$TEST_TMP/bin/checkupdates"
export BLOOM_CHECKUPDATES="$TEST_TMP/bin/checkupdates" BLOOM_FAKE_UPDATES="$TEST_TMP/fake"
printf '{ "bloom-weather-enabled": false }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"

printf '0\nfuzzel 1 -> 2\njdk 1 -> 2\n' >"$BLOOM_FAKE_UPDATES"
start_shell
state() { ipc updates state | jq -c "{$1}"; }
state_is() { [[ "$(state "$1")" == "$2" ]]; }

assert_eq "$(ipc updates check)" "ok" "check"
wait_for "the first check" state_is "available,count,checking" '{"available":true,"count":2,"checking":false}'
pass "a check counts pending updates"

printf '1\n' >"$BLOOM_FAKE_UPDATES"
ipc updates check >/dev/null
wait_for "the failed check to finish" state_is "checking" '{"checking":false}'
assert_eq "$(state "count")" '{"count":2}' "a failed check keeps the last good count"
pass "offline keeps the dot steady"

printf '2\n' >"$BLOOM_FAKE_UPDATES"
ipc updates check >/dev/null
wait_for "no updates" state_is "available,count" '{"available":false,"count":0}'
pass "exit 2 clears it"

rm "$TEST_TMP/bin/checkupdates"
ipc updates check >/dev/null
wait_for "the missing tool" state_is "installed,available" '{"installed":false,"available":false}'
log_has "checkupdates is not installed" || fail "no note about the missing tool"
pass "a missing checkupdates hides the indicator"

problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no warnings"
