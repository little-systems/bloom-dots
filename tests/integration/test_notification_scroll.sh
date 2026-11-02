#!/usr/bin/env bash
# Equal-height long cards exposed a conflict between native ListView snapping
# and Bloom's scroll glide. Exercise cards and the separate scrollbar gutter.
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
printf '{"bloom-enabled-modules":["notifications"],"bloom-scale":1.15}' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
wait_for 'notification bus' busctl --user status org.freedesktop.Notifications
for i in $(seq 1 10); do
	notify-send -a 'Scroll Test' "Long $i" 'A notification body that wraps across several lines to exercise the changing card heights while scrolling through older history.'
done
have_history() { ipc notifications state | jq -e '.history | length == 10' >/dev/null; }
wait_for 'ten history entries' have_history
assert_eq "$(ipc notifications openHistory)" ok 'open history'
expanded() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .expanded and .viewportHeight>250)' >/dev/null; }
wait_for 'expanded stack' expanded

scrolled() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .contentY > .originY + 10)' >/dev/null; }
at_bottom() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .contentY >= .maxY - 5 and .lastCardVisible)' >/dev/null; }
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 1700 120 wheel 8
wait_for 'wheel over cards moves equal-height notifications' scrolled
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 1700 120 wheel 55
wait_for 'card wheel reaches the oldest notification' at_bottom

read -r scroll_x scroll_top < <(ipc notifications state | jq -r '.surfaces[] | select(.kind=="stack") | "\(.scrollX | round) \(.scrollTopY | round)"')
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$scroll_x" "$scroll_top" click 1
at_top() { ipc notifications state | jq -e 'any(.surfaces[]; .kind=="stack" and .contentY <= .originY + 3)' >/dev/null; }
wait_for 'scrollbar returns to newest notification' at_top
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$scroll_x" 120 wheel 8
wait_for 'wheel over scrollbar gutter moves notifications' scrolled
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$scroll_x" 120 wheel 55
wait_for 'gutter wheel reaches the oldest notification' at_bottom
if [[ -n "${BLOOM_NOTIFICATION_SCROLL_SCREENSHOT:-}" ]]; then
	grim -o HEADLESS-1 "$BLOOM_NOTIFICATION_SCROLL_SCREENSHOT"
fi
pass 'card and gutter wheel input reach the oldest notification'
