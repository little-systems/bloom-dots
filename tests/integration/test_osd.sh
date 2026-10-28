#!/usr/bin/env bash
# Exercise OSD windows in an isolated compositor without touching host devices.
set -euo pipefail
if [[ -z "${BLOOM_IN_DBUS:-}" ]]; then
	exec env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE BLOOM_IN_DBUS=1 QT_NO_XDG_DESKTOP_PORTAL=1 \
		dbus-run-session --config-file="$(dirname "${BASH_SOURCE[0]}")/dbus-session.conf" -- bash "$0" "$@"
fi
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
mkdir -p "$TEST_TMP/bin" "$XDG_CONFIG_HOME/bloom"
cat >"$TEST_TMP/bin/brightnessctl" <<'SH'
#!/bin/sh
printf 'test_backlight,backlight,50,50%%,100\n'
SH
chmod +x "$TEST_TMP/bin/brightnessctl"
export PATH="$TEST_TMP/bin:$PATH"
start_sway
printf '{"bloom-enabled-modules":[]}' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
assert_eq "$(ipc osd state)" '[]' 'disabled OSD'
pass 'module-off creates no OSD windows'

ipc settings set bloom-enabled-modules '["osd"]' >/dev/null
osd_count() { [[ "$(ipc osd state 2>/dev/null | jq length)" == 2 ]]; }
left_visible() { [[ "$(ipc osd state 2>/dev/null | jq -r '.[] | select(.edge=="left") | .shown')" == true ]]; }
right_visible() { [[ "$(ipc osd state 2>/dev/null | jq -r '.[] | select(.edge=="right") | .shown')" == true ]]; }
right_available() { [[ "$(ipc osd state 2>/dev/null | jq -r '.[] | select(.edge=="right") | .backlightAvailable')" == true ]]; }
all_closed() { [[ "$(ipc osd state 2>/dev/null | jq '[.[] | .shown] | any')" == false ]]; }
wait_for 'OSD windows' osd_count
assert_eq "$(ipc osd showVolume)" 'ok' 'show volume'
wait_for 'left OSD visible' left_visible
wait_for 'fake backlight discovery' right_available
assert_eq "$(ipc osd showBrightness)" 'ok' 'show brightness'
wait_for 'right OSD visible' right_visible
pass 'both edge OSD windows open on the single test screen'

ipc settings set bloom-scale 1.3 >/dev/null
scaled_width() { ipc osd state | jq -e 'any(.[]; .edge=="left" and (.width > 54.5 and .width < 54.7))' >/dev/null; }
wait_for 'scaled pill geometry' scaled_width
pass 'OSD pill follows the UI scale'

wait_for 'OSD timeout' all_closed
pass 'OSD windows close after timeout'
problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
problems="$(grep -viE 'upower|powerprofiles|dbus|pipewire' <<<"$problems" || true)"
[[ -z "$problems" ]] || fail "OSD shell logged warnings or errors: $problems"
pass 'OSD shell has no unexpected warnings'
