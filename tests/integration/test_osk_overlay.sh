#!/usr/bin/env bash
# The on-screen keyboard and overlay as real layers in headless sway.
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
printf '{"bloom-enabled-modules":["osk","overlay"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
assert_eq "$(ipc osk toggle)" "ok" "open the keyboard"
assert_eq "$(ipc osk state | jq .opened)" "true" "keyboard opened"
assert_eq "$(ipc osk toggle)" "ok" "close the keyboard"
pass "the keyboard opens and closes"
assert_eq "$(ipc overlay toggle)" "ok" "open the overlay"
assert_eq "$(ipc overlay state | jq .opened)" "true" "overlay opened"
assert_eq "$(ipc overlay toggle)" "ok" "close the overlay"
pass "the overlay opens and closes"
sleep 0.5
if grep -E "WARN|ERROR|caused by" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire|wl_keyboard.leave"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
