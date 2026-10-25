#!/usr/bin/env bash
# The notch follows a (fake) MPRIS player on headless sway: music takes the
# collapsed pill, openMusic opens Bloom's player, and the player going away
# hands the pill back to the clock.
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
	echo "skipped: sway not installed"
	exit 0
fi
bloom_env
start_sway

python3 "$ROOT/tests/integration/fake_mpris.py" player --playing --title "End To End" >"$TEST_TMP/player.log" 2>&1 &
PLAYER_PID=$!
trap 'kill $PLAYER_PID 2>/dev/null || true; bloom_cleanup' EXIT
wait_for "the fake player" grep -q READY "$TEST_TMP/player.log"

mkdir -p "$XDG_CONFIG_HOME/bloom"
# No cava in tests: the visualizer is off, so the pill is 140 + 30 (art).
printf '{ "bloom-enabled-modules": ["notch"], "bloom-weather-enabled": false, "bloom-media-visualizer-enabled": false }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell

state_is() { [[ "$(ipc notch state | jq -c ".[0] | {$1}")" == "$2" ]]; }

wait_for "music to take the pill" state_is "bloomMode,width" '{"bloomMode":"music","width":170}'
pass "a playing player takes the collapsed pill"

assert_eq "$(ipc notch openMusic)" "ok" "openMusic"
wait_for "the classic player" state_is "open,width,height" '{"open":true,"width":340,"height":120}'
pass "openMusic opens the classic player"

kill "$PLAYER_PID"
wait_for "the pill to fall back to the clock" state_is "bloomMode,open,width" '{"bloomMode":"status","open":false,"width":140}'
pass "the player going away closes the panel and returns the clock"

problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
# Without a system bus (CI) UPower warns; without a session PipeWire, PipeWire does.
problems="$(grep -viE 'upower|powerprofiles|dbus|pipewire' <<<"$problems" || true)"
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no unexpected warnings"
