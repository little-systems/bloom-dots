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
SECOND_SHELL_PID=""
cleanup_notification_test() {
	if [[ -n "$SECOND_SHELL_PID" ]]; then kill "$SECOND_SHELL_PID" 2>/dev/null || true; wait "$SECOND_SHELL_PID" 2>/dev/null || true; fi
	bloom_cleanup
}
trap cleanup_notification_test EXIT
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom"
printf '{"bloom-enabled-modules":["notifications"],"bloom-notifications-timeout":2500}' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
wait_for 'Bloom notification bus owner' busctl --user status org.freedesktop.Notifications
owned_status() { ipc notifications state | jq -e '.ownership=="owned" and .ownershipError==""' >/dev/null; }
wait_for 'reported Bloom ownership' owned_status
pass 'Bloom owns notifications on the private bus'

ln -s "$ROOT/shell" "$XDG_CONFIG_HOME/quickshell/bloom-conflict"
qs --no-color -c bloom-conflict >"$TEST_TMP/conflict.log" 2>&1 &
SECOND_SHELL_PID=$!
second_ipc() { qs -c bloom-conflict ipc call "$@"; }
wait_for 'second shell ping' second_ipc shell ping
conflict_reported() { second_ipc notifications state | jq -e '.ownership=="conflict" and (.ownershipError | contains("PID"))' >/dev/null; }
wait_for 'ownership conflict report' conflict_reported
kill "$SECOND_SHELL_PID"
wait "$SECOND_SHELL_PID" 2>/dev/null || true
SECOND_SHELL_PID=""
pass 'a second Bloom instance reports the existing notification owner'

transient_hover_id="$(notify-send -p -e -t 10000 -a 'ChatGPT' 'Transient hover')"
transient_arrival() { ipc notifications state | jq -e 'any(.cards[]; .summary=="Transient hover")' >/dev/null; }
wait_for 'transient arrival card' transient_arrival
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 1885 28 hover 4000 &
TRANSIENT_HOVER_PID=$!
transient_hover_visible() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .visible and (.cornerHovered or .hovered) and .mode=="arrival")' >/dev/null; }
wait_for 'transient card stays visible on corner hover' transient_hover_visible
if [[ -n "${BLOOM_NOTIFICATION_APP_ICON_SCREENSHOT:-}" ]]; then
	sleep 0.25
	grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_APP_ICON_SCREENSHOT"
fi
sleep 2.7
transient_hover_visible || fail 'transient card slid out while hovered'
wait "$TRANSIENT_HOVER_PID"
ipc notifications dismiss "$transient_hover_id" >/dev/null
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 300 600 wheel 0 &
wait $!
pass 'corner hover keeps a transient arrival card visible without history'

id="$(notify-send -p -a 'Test App' -i folder -t 5000 'First' 'body')"
[[ "$id" =~ ^[0-9]+$ ]] || fail "notify-send did not return an ID: $id"
has_summary() { ipc notifications state | jq -e --arg s "$1" 'any(.history[]; .summary==$s)' >/dev/null; }
wait_for 'first notification' has_summary First
ipc notifications state | jq -e 'any(.cards[]; .summary=="First" and .image!="")' >/dev/null || fail 'notification image icon was not available to the card'
cards_mapped() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .visible and .mode=="arrival")' >/dev/null; }
wait_for 'visible card surface' cards_mapped
if [[ -n "${BLOOM_NOTIFICATION_SCREENSHOT:-}" ]]; then
	sleep 0.25
	grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_SCREENSHOT"
fi
notify-send -r "$id" -a 'Test App' -t 5000 'Replaced' 'new body'
wait_for 'replacement' has_summary Replaced
[[ "$(ipc notifications state | jq '.history | length')" == 1 ]] || fail 'replacement duplicated history'
pass 'replacement updates one history entry'
notify-send -a 'Test App' -t 5000 'Grouped' 'same app'
stacked_cards() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .cards==2)' >/dev/null; }
wait_for 'two cards in the stack' stacked_cards
pass 'same-app notifications occupy separate stacked cards'

ipc settings set bloom-notifications-dnd true >/dev/null
notify-send -a 'Test App' 'Quiet' 'kept in history'
wait_for 'quiet history' has_summary Quiet
[[ "$(ipc notifications state | jq '[.cards[] | select(.summary=="Quiet")] | length')" == 0 ]] || fail 'DND showed a normal card'
notify-send -u critical -a 'Test App' 'Critical' 'The notification body should remain readable as it wraps across several lines. Expand the stack to read more without losing the title or controls.'
critical_card() { ipc notifications state | jq -e 'any(.cards[]; .summary=="Critical")' >/dev/null; }
wait_for 'critical card' critical_card
pass 'DND retains normal history and shows critical cards'

no_cards() { ipc notifications state | jq -e '.cards | length == 0' >/dev/null; }
wait_for 'temporary banners to clear' no_cards
hover_target() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .cornerAvailable and (.visible==false))' >/dev/null; }
wait_for 'top-right hover target' hover_target
unread_before_hover="$(ipc notifications state | jq '.unread')"
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 1885 28 wheel 0 &
HOVER_PID=$!
history_mapped() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .visible and .mode=="history")' >/dev/null; }
wait_for 'history to open from top-right hover' history_mapped
[[ "$(ipc notifications state | jq '.unread')" == "$unread_before_hover" ]] || fail 'hover marked notifications read'
if [[ -n "${BLOOM_NOTIFICATION_HISTORY_SCREENSHOT:-}" ]]; then
	sleep 0.25
	grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_HISTORY_SCREENSHOT"
fi
wait "$HOVER_PID"
read -r expand_x expand_y < <(ipc notifications state | jq -r '.surfaces[] | select(.kind=="stack") | "\(.expandX | round) \(.expandY | round)"')
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$expand_x" "$expand_y" click 1
stack_expanded() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .expanded and .shown>=4)' >/dev/null; }
wait_for 'notification stack to expand from its count row' stack_expanded
if [[ -n "${BLOOM_NOTIFICATION_EXPANDED_SCREENSHOT:-}" ]]; then
	sleep 1.5
	grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_EXPANDED_SCREENSHOT"
fi
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$expand_x" "$expand_y" click 1
stack_collapsed() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and (.expanded==false) and .shown>=4)' >/dev/null; }
wait_for 'notification stack to collapse from its count row' stack_collapsed
pass 'notification count row expands and collapses the bounded stack'
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 300 600 wheel 0 &
LEAVE_PID=$!
history_closed() { ipc notifications state | jq -e 'all(.surfaces[]; .kind!="stack" or (.visible==false))' >/dev/null; }
wait_for 'hover history to close after leaving' history_closed
wait "$LEAVE_PID"
pass 'top-right hover slides the same card stack back in and leaves cleanly'

ipc notifications markRead >/dev/null
[[ "$(ipc notifications state | jq '.unread')" == 0 ]] || fail 'markRead kept unread items'
state_file="$XDG_STATE_HOME/bloom/notifications.json"
wait_for 'notification state file' test -s "$state_file"
[[ "$(jq '.entries | length' "$state_file")" -ge 3 ]] || fail 'history was not persisted'
pass 'notification history persists as JSON primitives'

assert_eq "$(ipc notifications openHistory)" 'ok' 'open history'
if [[ -n "${BLOOM_NOTIFICATION_MOTION_DIR:-}" ]]; then
	mkdir -p "$BLOOM_NOTIFICATION_MOTION_DIR"
	sleep 0.04; grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_MOTION_DIR/open-04.png"
	sleep 0.08; grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_MOTION_DIR/open-12.png"
	sleep 0.15; grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_MOTION_DIR/open-27.png"
fi
wait_for 'history cards in the same stack' history_mapped
assert_eq "$(ipc notifications closeHistory)" 'ok' 'close history'
if [[ -n "${BLOOM_NOTIFICATION_MOTION_DIR:-}" ]]; then
	sleep 0.04; grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_MOTION_DIR/close-04.png"
	sleep 0.08; grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_MOTION_DIR/close-12.png"
	sleep 0.15; grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_MOTION_DIR/close-27.png"
fi
wait_for 'history cards to slide away' history_closed
pass 'IPC reveals and hides history in the same stack'

ipc settings set bloom-notifications-dnd false >/dev/null
long_id="$(notify-send -p -a 'Test App' -t 10000 'Brief banner' 'kept in history')"
long_card() { ipc notifications state | jq -e --argjson id "$long_id" 'any(.cards[]; .id==$id)' >/dev/null; }
wait_for 'long sender timeout still shows a banner' long_card
WAIT_S=5 wait_for 'banner to hide by the Bloom timeout' no_cards
has_summary 'Brief banner' || fail 'hidden banner was lost from history'
pass 'ordinary banners hide within 2.5 seconds even when an app requests longer'
hover_id="$(notify-send -p -a 'Test App' -t 10000 'Hover banner' 'stay while the pointer is here')"
hover_card() { ipc notifications state | jq -e --argjson id "$hover_id" 'any(.cards[]; .id==$id)' >/dev/null; }
wait_for 'hover banner' hover_card
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 1750 60 hover 4500 &
CARD_HOVER_PID=$!
card_hovered() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .hovered)' >/dev/null; }
wait_for 'pointer over the banner' card_hovered
sleep 3.7
hover_card || fail 'banner expired while hovered'
wait "$CARD_HOVER_PID"
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 300 600 wheel 0 &
CARD_LEAVE_PID=$!
WAIT_S=5 wait_for 'banner to expire after pointer leaves' no_cards
wait "$CARD_LEAVE_PID"
pass 'hover pauses a banner and leaving resumes its timeout'
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

# The first session used ID 1 for the transient hover case, so advance the
# restarted session to the first ID that also exists in persisted history.
restart_transient_id="$(notify-send -p -e -t 1000 -a 'Test App' 'Restart transient')"
ipc notifications dismiss "$restart_transient_id" >/dev/null
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
assert_eq "$(ipc notifications openHistory)" 'ok' 'open stack for clear all'
clear_target() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .expanded and .clearVisible and .expansionProgress >= 0.99)' >/dev/null; }
wait_for 'floating clear-all button' clear_target
read -r clear_x clear_y < <(ipc notifications state | jq -r '.surfaces[] | select(.kind=="stack") | "\(.clearX | round) \(.clearY | round)"')
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$clear_x" "$clear_y" click 1
cleared() { ipc notifications state | jq -e '(.history|length)==0 and (.cards|length)==0' >/dev/null; }
wait_for 'floating button to clear history and live cards' cleared
wait_for 'cleared history on disk' jq -e '.entries | length == 0' "$state_file"
pass 'floating clear-all button dismisses live cards and clears history'
problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" "$TEST_TMP/restarted.log" || true)"
problems="$(grep -viE 'upower|powerprofiles|dbus|pipewire' <<<"$problems" || true)"
[[ -z "$problems" ]] || fail "notification shell logged warnings or errors: $problems"
pass 'notification shell has no unexpected warnings'
