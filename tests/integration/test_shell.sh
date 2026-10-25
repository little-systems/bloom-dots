#!/usr/bin/env bash
# Starts the real shell offscreen and checks IPC and live settings.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

# Review focus 5: ipc must fail fast while the shell is down so `|| fallback` binds work.
if ipc shell ping >/dev/null 2>&1; then fail "ipc succeeded with no shell running"; fi
pass "ipc fails while the shell is not running"

start_shell
pass "shell starts and answers ping"

SETTINGS="$XDG_CONFIG_HOME/bloom/settings.json"

# Review focus 3: first run uses defaults and does not create settings.json.
assert_eq "$(ipc settings get bloom-theme-opacity)" "0.8" "default opacity"
[[ ! -e "$SETTINGS" ]] || fail "starting the shell created $SETTINGS"
pass "first run uses defaults without creating settings.json"

mkdir -p "$(dirname "$SETTINGS")"
printf '{ "bloom-theme-opacity": 0.5, "x-future-key": 1 }\n' >"$SETTINGS"
wait_for "a settings.json created after startup to apply" ipc_equals 0.5 settings get bloom-theme-opacity
pass "a settings.json created after startup is picked up"

printf '{ "bloom-theme-opacity": 0.4, "x-future-key": 1 }\n' >"$SETTINGS"
wait_for "a hand edit to apply" ipc_equals 0.4 settings get bloom-theme-opacity
pass "hand edits apply live"

# Review focus 1: a syntax error keeps the last good values and the file is never overwritten.
printf '{ "bloom-theme-opacity": 0.3, \n' >"$SETTINGS"
wait_for "the parse warning" log_has "is not valid JSON"
assert_eq "$(ipc settings get bloom-theme-opacity)" "0.4" "opacity after a bad edit"
assert_eq "$(ipc settings set bloom-theme-opacity 0.6)" "settings.json has a syntax error; fix it before changing settings" "set while the file is broken"
grep -qF '"bloom-theme-opacity": 0.3, ' "$SETTINGS" || fail "the broken settings.json was overwritten"
pass "a broken file keeps the last good settings and is never overwritten"

printf '{ "bloom-theme-opacity": 1.5, "bloom-theme-mode": "neon", "x-future-key": 1 }\n' >"$SETTINGS"
wait_for "invalid values to fall back" ipc_equals 0.8 settings get bloom-theme-opacity
assert_eq "$(ipc settings get bloom-theme-mode)" '"dark"' "invalid mode falls back"
assert_eq "$(ipc settings warnings | jq length)" "3" "warning count"
pass "invalid values fall back to defaults with warnings"

assert_eq "$(ipc settings set bloom-theme-mode light)" "ok" "set mode"
assert_eq "$(jq -r '."bloom-theme-mode"' "$SETTINGS")" "light" "mode written to the file"
assert_eq "$(jq -r '."x-future-key"' "$SETTINGS")" "1" "unknown key kept"
assert_eq "$(ipc theme mode)" "light" "theme follows settings"
assert_eq "$(ipc settings set bloom-theme-opacity 2)" "bloom-theme-opacity: expected a number from 0 to 1" "invalid set rejected"
pass "set validates, writes the file, keeps unknown keys, and the theme follows"

assert_eq "$(ipc settings set bloom-theme-mode adaptive)" "ok" "set adaptive"
assert_eq "$(ipc theme mode)" "dark" "adaptive falls back to dark until wallpaper theming"
pass "adaptive falls back to dark"

if grep -E '^ *(ERROR|FATAL)' "$TEST_TMP/shell.log"; then fail "shell logged errors"; fi
pass "no errors in the shell log"
