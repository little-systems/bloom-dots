#!/usr/bin/env bash
# Screen corners: four click-through corners per screen while the setting is
# on, hidden over a fullscreen window, gone when the setting is off. Uses a
# controlled compositor snapshot; the host session is never changed.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
    [[ "${CI:-}" == true ]] && { echo 'sway required in CI' >&2; exit 1; }
    echo 'skipped: sway is not installed'
    exit 0
fi
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin"
export BLOOM_HYPR_FIXTURE="$TEST_TMP" HYPRLAND_INSTANCE_SIGNATURE=bloom-fixture
# The smart notch polls Hyprland every second, so the fixture's changes reach
# the shell without Hyprland's events.
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false,"bloom-music-mode-enabled":false,"bloom-notch-mode":"smart","bloom-corners-enabled":true}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
cat > "$TEST_TMP/bin/hyprctl" <<'SH'
#!/bin/sh
case "$*" in
    '-j clients') cat "$BLOOM_HYPR_FIXTURE/clients.json" ;;
    '-j monitors') cat "$BLOOM_HYPR_FIXTURE/monitors.json" ;;
    *) echo '[]' ;;
esac
SH
chmod +x "$TEST_TMP/bin/hyprctl"
export PATH="$TEST_TMP/bin:$PATH"
printf '[{"id":0,"name":"HEADLESS-1","x":0,"y":0,"width":1280,"height":720,"scale":1,"reserved":[0,0,0,0],"activeWorkspace":{"id":1}}]\n' > "$TEST_TMP/monitors.json"
client() {
    printf '[{"mapped":true,"hidden":false,"monitor":0,"workspace":{"id":1},"at":[0,40],"size":[600,400],"fullscreen":%s,"focusHistoryID":0}]\n' "$1" > "$TEST_TMP/clients.new"
    mv "$TEST_TMP/clients.new" "$TEST_TMP/clients.json"
}
client 0
start_shell
corners() { ipc corners state | jq -e "$1" >/dev/null; }
wait_for 'four corners on the screen' corners 'length == 1 and .[0].corners == ["top-left","top-right","bottom-left","bottom-right"] and .[0].shown and .[0].radius == 23 and .[0].clickThrough'
pass 'the setting puts four click-through 23 px corners on each screen'
client 2
wait_for 'corners hidden over fullscreen' corners '.[0].shown | not'
pass 'a fullscreen window hides the corners'
client 0
wait_for 'corners back after fullscreen' corners '.[0].shown'
pass 'leaving fullscreen brings them back'
ipc settings set bloom-corners-enabled false >/dev/null
wait_for 'no corners with the setting off' corners 'length == 0'
pass 'turning the setting off removes them'
problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
# The fixture fakes HYPRLAND_INSTANCE_SIGNATURE without a socket.
problems="$(grep -v 'Unable to find hyprland socket' <<<"$problems" || true)"
if [[ ! -S /run/dbus/system_bus_socket ]]; then
	problems="$(grep -viE 'upower|powerprofiles|dbus' <<<"$problems" || true)"
fi
if [[ ! -S "$XDG_RUNTIME_DIR/pipewire-0" ]]; then
	problems="$(grep -vi 'Failed to connect pipewire context' <<<"$problems" || true)"
fi
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no warnings or errors in the shell log"
