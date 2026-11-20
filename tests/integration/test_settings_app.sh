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
export CLAUDE_CONFIG_DIR="$TEST_TMP/claude" CODEX_HOME="$TEST_TMP/codex"
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin"
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false,"bloom-time-format-24h":true,"bloom-wallpaper":"/keep.png"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
if [[ -n "${BLOOM_TEST_LANGUAGE:-}" ]]; then
	jq --arg lang "$BLOOM_TEST_LANGUAGE" '. + {"bloom-language": $lang}' "$XDG_CONFIG_HOME/bloom/settings.json" > "$TEST_TMP/settings-localized.json"
	mv "$TEST_TMP/settings-localized.json" "$XDG_CONFIG_HOME/bloom/settings.json"
fi
cat > "$TEST_TMP/bin/systemctl" <<SH
#!/bin/sh
echo "\$*" >> "$TEST_TMP/calls"
[ "\$3" = is-enabled ] || [ "\$2" = is-enabled ] && echo enabled
exit 0
SH
chmod +x "$TEST_TMP/bin/systemctl"
printf '#!/bin/sh\necho "[{\"name\":\"HEADLESS-1\",\"description\":\"Test\",\"width\":1920,\"height\":1080,\"refreshRate\":60,\"scale\":1,\"x\":0,\"y\":0,\"availableModes\":[\"1920x1080@60.00Hz\"]}]"\n' > "$TEST_TMP/bin/hyprctl"
chmod +x "$TEST_TMP/bin/hyprctl"
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
store_started() { call state | jq -e '.storeStarted == true' >/dev/null; }
wait_for "the system queries to start once the window is up" store_started
pass "the system store starts after the first frame"
for page in sound power storage input hyprland apps time updates network bluetooth; do
	assert_eq "$(call tab "$page")" "ok" "open $page"
done
pass "every system page opens"
assert_eq "$(call tab integrations)" "ok" "open integrations"
sleep 0.5
if [[ -n "${BLOOM_INTEGRATIONS_SCREENSHOT:-}" ]]; then
	grim -o HEADLESS-1 "$BLOOM_INTEGRATIONS_SCREENSHOT"
fi
# The fixture uses a 1920x1080 output and the default Settings size.
agent_installed() { "$ROOT/bin/bloom" agents status | jq -e --argjson installed "$1" '.integrations[] | select(.agent == "claude") | .installed == $installed' >/dev/null; }
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 1472 577 click 0
wait_for "Claude hooks installed from Settings" agent_installed true
sleep 0.5
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 1472 577 click 0
wait_for "Claude hooks disconnected from Settings" agent_installed false
pass "the Integrations page connects and disconnects Claude in an isolated config"
assert_eq "$(call tab about)" "ok" "switch tab"
assert_eq "$(call state | jq -r .tab)" "about" "tab"
pass "tabs switch"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "app log has warnings"; fi
pass "no warnings or errors in the app log"
