#!/usr/bin/env bash
# Owner: Settings is preloaded at login so it opens as fast as a bare window.
# A hidden Settings starts unmapped, shows on request, and hides on close.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
bloom_env
export CLAUDE_CONFIG_DIR="$TEST_TMP/claude" CODEX_HOME="$TEST_TMP/codex"
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin"
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
printf '#!/bin/sh\necho "[]"\n' > "$TEST_TMP/bin/hyprctl"
chmod +x "$TEST_TMP/bin/hyprctl"
export PATH="$TEST_TMP/bin:$PATH"
APP="$ROOT/shell/settings-app.qml"
OPEN="$ROOT/shell/scripts/open-settings.sh"
SWAY_SOCK="$(ls "$XDG_RUNTIME_DIR"/sway-ipc.* | head -1)"
shown() { SWAYSOCK="$SWAY_SOCK" swaymsg -t get_tree | jq -e '[.. | objects | select(.name? == "Bloom Settings")] | length == 1' >/dev/null; }
call() { qs --no-color ipc -p "$APP" call settingsapp "$@"; }
answers() { call state >/dev/null 2>&1; }

"$ROOT/shell/scripts/preload-settings.sh" "$APP" >"$TEST_TMP/shell.log" 2>&1
wait_for "the preloaded app to answer" answers
sleep 1
shown && fail "a preloaded Settings showed its window"
pass "preloading starts Settings hidden"

started=$(date +%s%N)
sh "$OPEN" "$APP"
wait_for "the window" shown
elapsed=$(( ($(date +%s%N) - started) / 1000000 ))
assert_eq "$(call state | jq -r .tab)" "display" "opens on Display"
# A cold start takes over a second even here; CI runners are slower than
# this machine, so the bound is loose.
(( elapsed < 1000 )) || fail "a preloaded Settings took ${elapsed} ms to show"
pass "opening a preloaded Settings shows it at once (${elapsed} ms)"

assert_eq "$(call tab about)" "ok" "switch tab"
assert_eq "$(call close)" "ok" "close"
wait_for "the window to hide" bash -c "! SWAYSOCK='$SWAY_SOCK' swaymsg -t get_tree | jq -e '[.. | objects | select(.name? == \"Bloom Settings\")] | length == 1' >/dev/null"
answers || fail "closing quit the preloaded Settings"
pass "closing hides Settings and keeps it loaded"

sh "$OPEN" "$APP" sound
wait_for "the window again" shown
assert_eq "$(call state | jq -r .tab)" "sound" "opens on the asked page"
pass "opening on a page shows that page"

SWAYSOCK="$SWAY_SOCK" swaymsg '[title="Bloom Settings"] kill' >/dev/null
wait_for "the compositor's close to hide the window" bash -c "! SWAYSOCK='$SWAY_SOCK' swaymsg -t get_tree | jq -e '[.. | objects | select(.name? == \"Bloom Settings\")] | length == 1' >/dev/null"
sleep 0.5
answers || fail "the compositor's close quit the preloaded Settings"
sh "$OPEN" "$APP"
wait_for "the window after a compositor close" shown
pass "a compositor close also only hides Settings"

# A newer shell replaces a hidden Settings (say, after an update) but never
# one that is open.
"$ROOT/shell/scripts/preload-settings.sh" "$APP" >>"$TEST_TMP/shell.log" 2>&1
sleep 1
shown || fail "preloading replaced a Settings window that was open"
assert_eq "$(call close)" "ok" "close"
old=$(call state | jq -r .instance)
"$ROOT/shell/scripts/preload-settings.sh" "$APP" >>"$TEST_TMP/shell.log" 2>&1
wait_for "the new hidden Settings" bash -c "[ \"\$(qs --no-color ipc -p '$APP' call settingsapp state 2>/dev/null | jq -r .instance)\" != '$old' ] && [ -n \"\$(qs --no-color ipc -p '$APP' call settingsapp state 2>/dev/null)\" ]"
pass "preloading again replaces a hidden Settings"
