#!/usr/bin/env bash
# The Alt + Tab card through the real shell: Hyprland's alt-tab.lua sends
# `switcher open <seq> <addresses> <index>` and `hide <seq>` for floating
# windows; the card appears only once Alt has been held a moment, follows the
# selection, goes away on release, and ignores messages that land late.
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

assert_eq "$(ipc switcher open 1 "0xa1,junk,0xb2,0xc3" 1)" "ok" "open"
is '.active and .index == 1 and .addresses == ["0xa1","0xb2","0xc3"]' || fail "open didn't take the addresses: $(state)"
pass "open takes the windows, most recent first, and drops anything else"
wait_for "the card to appear once Alt is held" is '.revealed and .visible'
pass "the card appears once Alt has been held a moment"

assert_eq "$(ipc switcher open 2 "0xa1,0xb2,0xc3" 2)" "ok" "step"
is '.index == 2' || fail "step: $(state)"
assert_eq "$(ipc switcher open 3 "0xa1,0xb2,0xc3" 9)" "ok" "step past the end"
is '.index == 2' || fail "an index past the end isn't clamped: $(state)"
pass "the selection follows Tab"

assert_eq "$(ipc switcher open 2 "0xa1,0xb2,0xc3" 0)" "stale" "a late step"
is '.index == 2' || fail "a late step moved the selection: $(state)"
pass "a step that lands late is ignored"

assert_eq "$(ipc switcher hide 4)" "ok" "hide"
is '(.active | not) and (.revealed | not)' || fail "hide: $(state)"
wait_for "the card to go" is '(.visible | not)'
pass "releasing Alt takes it away"

# A quick tap whose hide lands before its open: the card must not stick.
assert_eq "$(ipc switcher hide 6)" "ok" "an early hide"
assert_eq "$(ipc switcher open 5 "0xa1,0xb2" 1)" "stale" "the open behind it"
sleep 0.4
is '(.active | not) and (.revealed | not) and (.visible | not)' || fail "a late open brought the card back: $(state)"
pass "an open that lands after its hide never shows the card"

# A quick tap in order: shown and hidden before the reveal delay, so no card.
ipc switcher open 7 "0xa1,0xb2" 1 >/dev/null
ipc switcher hide 8 >/dev/null
sleep 0.4
is '(.revealed | not) and (.visible | not)' || fail "a quick tap flashed the card: $(state)"
pass "a quick tap never shows the card"

if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
