#!/usr/bin/env bash
# A private session bus proves Bloom's exclusive server without disturbing ii.
set -euo pipefail
if [[ -z "${BLOOM_IN_DBUS:-}" ]]; then
	exec env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE BLOOM_IN_DBUS=1 QT_NO_XDG_DESKTOP_PORTAL=1 \
		dbus-run-session --config-file="$(dirname "${BASH_SOURCE[0]}")/dbus-session.conf" -- bash "$0" "$@"
fi
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom"
printf '{"bloom-enabled-modules":["notifications"],"bloom-notifications-timeout":1000}' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
wait_for 'Bloom notification bus owner' busctl --user status org.freedesktop.Notifications
pass 'Bloom owns notifications on the private bus'

id="$(notify-send -p -a 'Test App' -t 2000 'First' 'body')"
[[ "$id" =~ ^[0-9]+$ ]] || fail "notify-send did not return an ID: $id"
has_summary() { ipc notifications state | jq -e --arg s "$1" 'any(.history[]; .summary==$s)' >/dev/null; }
wait_for 'first notification' has_summary First
cards_mapped() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="cards" and .visible)' >/dev/null; }
wait_for 'visible card surface' cards_mapped
notify-send -r "$id" -a 'Test App' -t 2000 'Replaced' 'new body'
wait_for 'replacement' has_summary Replaced
[[ "$(ipc notifications state | jq '.history | length')" == 1 ]] || fail 'replacement duplicated history'
pass 'replacement updates one history entry'

ipc settings set bloom-notifications-dnd true >/dev/null
notify-send -a 'Test App' 'Quiet' 'kept in history'
wait_for 'quiet history' has_summary Quiet
[[ "$(ipc notifications state | jq '[.cards[] | select(.summary=="Quiet")] | length')" == 0 ]] || fail 'DND showed a normal card'
notify-send -u critical -a 'Test App' 'Critical' 'still shown'
critical_card() { ipc notifications state | jq -e 'any(.cards[]; .summary=="Critical")' >/dev/null; }
wait_for 'critical card' critical_card
pass 'DND retains normal history and shows critical cards'

ipc notifications markRead >/dev/null
[[ "$(ipc notifications state | jq '.unread')" == 0 ]] || fail 'markRead kept unread items'
state_file="$XDG_STATE_HOME/bloom/notifications.json"
wait_for 'notification state file' test -s "$state_file"
[[ "$(jq '.entries | length' "$state_file")" -ge 3 ]] || fail 'history was not persisted'
pass 'notification history persists as JSON primitives'

assert_eq "$(ipc notifications openHistory)" 'ok' 'open history'
history_mapped() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="history" and .visible)' >/dev/null; }
wait_for 'notch history surface' history_mapped
assert_eq "$(ipc notifications closeHistory)" 'ok' 'close history'
pass 'history panel opens below the notch and closes by IPC'

ipc settings set bloom-notifications-dnd false >/dev/null
notify-send -p -t 5000 -A 'open=Open' -a 'Test App' 'Actionable' >"$TEST_TMP/action.out" 2>"$TEST_TMP/action.err" &
ACTION_PID=$!
wait_for 'action notification ID' test -s "$TEST_TMP/action.out"
action_id="$(head -1 "$TEST_TMP/action.out")"
[[ "$action_id" =~ ^[0-9]+$ ]] || fail 'action notification had no ID'
assert_eq "$(ipc notifications action "$action_id" open)" 'ok' 'invoke action'
wait_for 'sender sees action' grep -Fxq open "$TEST_TMP/action.out"
wait "$ACTION_PID" || fail "action sender failed: $(cat "$TEST_TMP/action.err")"
pass 'live action reaches its sender'

before="$(ipc notifications state | jq '.history | length')"
notify-send -e -a 'Test App' 'Transient' 'not on disk'
sleep 0.2
[[ "$(ipc notifications state | jq '.history | length')" == "$before" ]] || fail 'transient notification entered history'
pass 'transient notification stays out of history'

persistent_id="$(notify-send -p -t 0 -a 'Test App' 'No timeout')"
sleep 1.2
ipc notifications state | jq -e --argjson id "$persistent_id" 'any(.cards[]; .id==$id)' >/dev/null || fail 'zero timeout card expired'
assert_eq "$(ipc notifications dismiss "$persistent_id")" 'ok' 'dismiss card'
closed_once() { ipc notifications state | jq -e --argjson id "$persistent_id" 'any(.history[]; .id==$id and .closeReason=="dismissed")' >/dev/null; }
wait_for 'dismissed close reason' closed_once
pass 'zero timeout persists and dismiss records one close reason'

saved_count="$(ipc notifications state | jq '.history | length')"
saved_unread="$(ipc notifications state | jq '.unread')"
wait_for 'saved close reason' jq -e --argjson id "$persistent_id" 'any(.entries[]; .id==$id and .closeReason=="dismissed")' "$state_file"
kill "$SHELL_PID"
wait "$SHELL_PID" 2>/dev/null || true
SHELL_PID=""
qs --no-color -c bloom >"$TEST_TMP/restarted.log" 2>&1 &
SHELL_PID=$!
wait_for 'restarted shell' ipc_equals pong shell ping
history_restored() { [[ "$(ipc notifications state | jq '.history | length')" == "$saved_count" ]]; }
wait_for 'restored history' history_restored
[[ "$(ipc notifications state | jq '.cards | length')" == 0 ]] || fail 'restart resurrected popup cards'
[[ "$(ipc notifications state | jq '.unread')" == "$saved_unread" ]] || fail 'restart lost unread state'
pass 'restart restores history and unread without resurrecting popups'

notify-send -p -t 5000 -A 'open=Open' -a 'Test App' 'New session action' >"$TEST_TMP/new-action.out" 2>"$TEST_TMP/new-action.err" &
NEW_ACTION_PID=$!
wait_for 'new action ID' test -s "$TEST_TMP/new-action.out"
new_id="$(head -1 "$TEST_TMP/new-action.out")"
old_key="$(ipc notifications state | jq -r --argjson id "$new_id" '[.history[] | select(.id==$id and .summary!="New session action") | .key] | first // empty')"
[[ -n "$old_key" ]] || fail 'test expected an ID reused after restart'
assert_eq "$(ipc notifications historyAction "$old_key" "$new_id" open)" 'action unavailable' 'stale action'
assert_eq "$(ipc notifications action "$new_id" open)" 'ok' 'new action'
wait "$NEW_ACTION_PID" || fail "new action sender failed: $(cat "$TEST_TMP/new-action.err")"
pass 'old history cannot invoke a new session action with the same ID'
problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" "$TEST_TMP/restarted.log" || true)"
problems="$(grep -viE 'upower|powerprofiles|dbus|pipewire' <<<"$problems" || true)"
[[ -z "$problems" ]] || fail "notification shell logged warnings or errors: $problems"
pass 'notification shell has no unexpected warnings'
