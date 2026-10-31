#!/usr/bin/env bash
# The settings app as its own process in headless sway, with a fake systemctl
# and throwaway settings. It never reaches the real bloom-shell.
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
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin"
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false,"bloom-time-format-24h":true,"bloom-wallpaper":"/keep.png"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
cat > "$TEST_TMP/bin/systemctl" <<SH
#!/bin/sh
echo "\$*" >> "$TEST_TMP/calls"
[ "\$3" = is-enabled ] || [ "\$2" = is-enabled ] && echo enabled
exit 0
SH
chmod +x "$TEST_TMP/bin/systemctl"
export PATH="$TEST_TMP/bin:$PATH"
qs --no-color -p "$ROOT/shell/settings-app.qml" >"$TEST_TMP/shell.log" 2>&1 &
SHELL_PID=$!
call() { qs --no-color ipc -p "$ROOT/shell/settings-app.qml" call settingsapp "$@"; }
up() { call state | jq -e '.autostart and .version != ""' >/dev/null; }
wait_for "the app to answer" up
pass "the app starts and reads autostart and the version"
SWAY_SOCK="$(ls "$XDG_RUNTIME_DIR"/sway-ipc.* | head -1)"
win() { SWAYSOCK="$SWAY_SOCK" swaymsg -t get_tree | jq -e '[.. | objects | select(.name? == "Bloom Settings")] | length == 1' >/dev/null; }
wait_for "the window" win
pass "the window maps"
assert_eq "$(call tab about)" "ok" "switch tab"
assert_eq "$(call state | jq -r .tab)" "about" "tab"
pass "tabs switch"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "app log has warnings"; fi
pass "no warnings or errors in the app log"
