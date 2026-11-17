#!/usr/bin/env bash
# Agent live activities through the real shell: `bloom agent-hook` reaches it
# over Quickshell IPC, an older background event can't overwrite a newer one,
# the first event marks the agent connected, and a session clears soon after
# its agent process exits.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom"
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell

state() { ipc agents state; }
active_is() { state | jq -e --arg k "$1" --arg a "$2" '.active.kind == $k and .active.activity == $a' >/dev/null; }

out="$(printf '{"hook_event_name":"PreToolUse","tool_name":"Edit","session_id":"s1","cwd":"/home/u/bloom","tool_input":{"file_path":"/secret"}}' | "$ROOT/bin/bloom" agent-hook claude)"
assert_eq "$out" "{}" "the hook answers {}"
wait_for "the Island to show Claude editing" active_is working editing
notch_shows_agent() { ipc notch state | jq -e '.[0].bloomMode == "agent" and .[0].height == 36' >/dev/null; }
wait_for "the agent activity to occupy the Island" notch_shows_agent
if [[ -n "${BLOOM_AGENT_SCREENSHOT:-}" ]]; then
	sleep 0.5
	grim -o HEADLESS-1 "$BLOOM_AGENT_SCREENSHOT"
fi
pass "a Claude hook reaches the shell and occupies the Island"
assert_eq "$(jq -c 'keys' "$XDG_STATE_HOME/bloom/agents.json")" '["claude"]' "the first event marks Claude connected"
pass "the first event is remembered as connected"

now=$(($(date +%s%3N)))
assert_eq "$(ipc agents event "{\"agent\":\"claude\",\"session\":\"s1\",\"project\":\"bloom\",\"kind\":\"working\",\"activity\":\"running\",\"at\":$((now + 1000))}")" "ok" "newer"
assert_eq "$(ipc agents event "{\"agent\":\"claude\",\"session\":\"s1\",\"project\":\"bloom\",\"kind\":\"working\",\"activity\":\"reading\",\"at\":$now}")" "stale" "older"
active_is working running || fail "an older event overwrote a newer one"
pass "an older background event is dropped"

sleep 300 &
agent=$!
started="$(awk '{ sub(/^.*\) /, ""); print $20 }' "/proc/$agent/stat")"
ipc agents event "{\"agent\":\"codex\",\"session\":\"t1\",\"project\":\"x\",\"kind\":\"working\",\"pid\":$agent,\"started\":$started}" >/dev/null
entries() { state | jq -e ".entries == $1" >/dev/null; }
wait_for "the Codex session to be tracked" entries 2
kill "$agent"; wait "$agent" 2>/dev/null || true
wait_for "the session to clear after its agent exits" entries 1
pass "an exited agent clears its session"

assert_eq "$(ipc agents event '{"agent":"claude","session":"s9","project":"p","kind":"ready","prompt":"secret"}')" "invalid" "unknown fields"
pass "events with anything off the allow-list are refused"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
