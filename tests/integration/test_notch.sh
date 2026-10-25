#!/usr/bin/env bash
# Runs the real shell with the notch enabled on headless sway: the layer
# surface loads cleanly, modes change live, peek and visibility work over IPC.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway not installed"
	exit 0
fi
bloom_env
start_sway

mkdir -p "$XDG_CONFIG_HOME/bloom"
# No network in tests: weather off.
printf '{ "bloom-enabled-modules": ["notch"], "bloom-weather-enabled": false, "bloom-music-mode-enabled": false }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell

state() { ipc notch state | jq -c ".[0] | {$1}"; }
state_is() { [[ "$(state "$1")" == "$2" ]]; }

wait_for "the notch to settle after the drop-in" state_is "hidden,width" '{"hidden":false,"width":140}'
pass "notch surface loads and settles at 140 px"

# Quickshell expands a JSON array into positional IPC arguments unless the
# CLI quotes it as one string. Exercise both removal and re-creation live.
ipc settings set bloom-enabled-modules '[]' >/dev/null
wait_for "disabling the notch to remove its surface" ipc_equals '[]' notch state
ipc settings set bloom-enabled-modules '["notch"]' >/dev/null
wait_for "re-enabling the notch to restore its surface" state_is "hidden,width" '{"hidden":false,"width":140}'
pass "CLI list setting removes and restores the notch"

ipc settings set bloom-notch-mode peek >/dev/null
wait_for "peek mode to hide the notch" state_is "hidden,y" '{"hidden":true,"y":-100}'
pass "peek mode hides the notch"

assert_eq "$(ipc notch peek 1500)" "ok" "peek"
wait_for "the peek to show it" state_is "hidden" '{"hidden":false}'
wait_for "the peek to end" state_is "hidden" '{"hidden":true}'
pass "an event peek shows it for the given time"

# Review focus 2: smart mode without Hyprland is simply "not overlapped".
ipc settings set bloom-notch-mode smart >/dev/null
wait_for "smart mode to show it" state_is "hidden,overlapped" '{"hidden":false,"overlapped":false}'
pass "smart mode without Hyprland keeps the notch shown"

assert_eq "$(ipc notch setVisible false)" "ok" "setVisible"
wait_for "hiding by the user" state_is "visible,y" '{"visible":false,"y":-150}'
ipc notch setVisible true >/dev/null
wait_for "showing again" state_is "visible,y" '{"visible":true,"y":0}'
pass "setVisible hides and shows the notch"

# A CI container has no system D-Bus, so UPower/power-profiles warnings are
# expected there and only there.
problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
if [[ ! -S /run/dbus/system_bus_socket ]]; then
	problems="$(grep -viE 'upower|powerprofiles|dbus' <<<"$problems" || true)"
fi
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no warnings or errors in the shell log"
