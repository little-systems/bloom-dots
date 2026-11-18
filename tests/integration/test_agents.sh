#!/usr/bin/env bash
# Agent live activities through the real shell: `bloom agent-hook` reaches it
# over Quickshell IPC, an older background event can't overwrite a newer one,
# the first event marks the agent connected, and a session clears soon after
# its agent process exits.
set -euo pipefail
if [[ -z "${BLOOM_IN_DBUS:-}" ]]; then
	# A private bus that can't auto-start anything, and no route to the host
	# display or Hyprland, so nothing on it reaches the real session.
	exec env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE BLOOM_IN_DBUS=1 QT_NO_XDG_DESKTOP_PORTAL=1 \
		dbus-run-session --config-file="$(dirname "${BASH_SOURCE[0]}")/dbus-session.conf" -- bash "$0" "$@"
fi
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

assert_eq "$(ipc agents preview codex editing)" "ok" "preview"
wait_for "the preview to enter the Island" active_is working editing
[[ ! -e "$XDG_STATE_HOME/bloom/agents.json" ]] || fail "preview marked a connection verified"
inactive() { state | jq -e '.active == null' >/dev/null; }
wait_for "the working preview to expire" inactive
pass "a preview expires and does not mark the agent connected"

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

# Claude sends no hook when a turn is interrupted mid-reply or rewound: a
# working session that stays silent is checked against its transcript's end.
transcript="$TEST_TMP/s5.jsonl"
printf '%s\n' '{"type":"summary"}' '{"type":"user","message":{"role":"user","content":"go"}}' \
	'{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash"}]}}' > "$transcript"
ipc agents event "{\"agent\":\"claude\",\"session\":\"s5\",\"project\":\"p\",\"kind\":\"working\",\"transcript\":\"$transcript\"}" >/dev/null
wait_for "the Claude session to be tracked" entries 2
sleep 9
entries 2 || fail "a silent turn that is still going was cleared"
printf '%s\n' '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}' \
	'{"type":"queue-operation"}' >> "$transcript"
WAIT_S=10 wait_for "the interrupted turn to clear" entries 1
pass "an interrupted turn clears from its transcript"

assert_eq "$(ipc agents event '{"agent":"claude","session":"s9","project":"p","kind":"ready","prompt":"secret"}')" "invalid" "unknown fields"
pass "events with anything off the allow-list are refused"
ipc agents event '{"agent":"claude","session":"s1","project":"bloom","kind":"attention"}' >/dev/null
wait_for "the attention alert" active_is attention ""
# The badge's real centre once it takes clicks (its width follows the fonts),
# from the screen-centred pill.
badge_shown() { ipc notch state | jq -e '.[0].agentBadge and .[0].agentBadgeAt != null' >/dev/null; }
WAIT_S=12 wait_for "the persistent attention badge" badge_shown
# It slides in: click once its centre holds still.
badge_at() { ipc notch state | jq -c '.[0].agentBadgeAt'; }
badge_settled() { local a; a="$(badge_at)"; sleep 0.25; [[ "$a" == "$(badge_at)" ]]; }
wait_for "the badge to settle" badge_settled
badge_x="$(ipc notch state | jq -r '960 + .[0].agentBadgeAt.dx | round')"
badge_y="$(ipc notch state | jq -r '.[0].agentBadgeAt.y | round')"
if [[ -n "${BLOOM_AGENT_BADGE_SCREENSHOT:-}" ]]; then grim -o HEADLESS-1 "$BLOOM_AGENT_BADGE_SCREENSHOT"; fi
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$badge_x" "$badge_y" click 0
wait_for "the badge click to replay the attention alert" active_is attention ""
pass "attention stays accessible through a real click on its badge"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
