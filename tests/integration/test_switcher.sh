#!/usr/bin/env bash
# The Alt + Tab switcher through the real shell: Hyprland's alt-tab.lua sends
# `switcher open/select/hide`; the card appears only once Alt has been held a
# moment, follows the selection, and goes away on release.
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
printf '{"bloom-enabled-modules":["overview"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
state() { ipc switcher state; }
is() { state | jq -e "$1" >/dev/null; }

assert_eq "$(ipc switcher open "0xa1,junk,0xb2,0xc3" 1)" "ok" "open"
is '.active and .index == 1 and .addresses == ["0xa1","0xb2","0xc3"]' || fail "open didn't take the addresses: $(state)"
pass "open takes the windows, most recent first, and drops anything else"
wait_for "the card to appear once Alt is held" is '.revealed and .visible'
pass "the card appears once Alt has been held a moment"

assert_eq "$(ipc switcher select 2)" "ok" "select"
is '.index == 2' || fail "select: $(state)"
assert_eq "$(ipc switcher select 9)" "ok" "select past the end"
is '.index == 2' || fail "an index past the end isn't clamped: $(state)"
pass "the selection follows Tab"

assert_eq "$(ipc switcher hide)" "ok" "hide"
is '(.active | not) and (.revealed | not)' || fail "hide: $(state)"
wait_for "the card to go" is '(.visible | not)'
pass "releasing Alt takes it away"

# A quick tap: shown and hidden before the reveal delay, so no card at all.
ipc switcher open "0xa1,0xb2" 1 >/dev/null
ipc switcher hide >/dev/null
sleep 0.4
is '(.revealed | not) and (.visible | not)' || fail "a quick tap flashed the card: $(state)"
pass "a quick tap never shows the card"

assert_eq "$(ipc switcher select 1)" "idle" "select with nothing shown"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
