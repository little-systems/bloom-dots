#!/usr/bin/env bash
# Exercise real notch surfaces with a controlled compositor snapshot. The
# host compositor and its applications are never changed.
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
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false,"bloom-music-mode-enabled":false,"bloom-notch-mode":"smart"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
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
    printf '[{"mapped":true,"hidden":false,"monitor":0,"workspace":{"id":1},"at":[0,%s],"size":[1280,720],"fullscreen":%s,"focusHistoryID":0}]\n' "$1" "$2" > "$TEST_TMP/clients.new"
    mv "$TEST_TMP/clients.new" "$TEST_TMP/clients.json"
}
client 0 0
start_shell
state_matches() { ipc notch state | jq -e ".[0] | $1" >/dev/null; }
wait_for 'smart startup stays hidden over an existing app' state_matches '.startupAnimating and .overlapped and .hidden'
pass 'smart startup does not reveal over a covering app'
ipc notch openPanel calendar >/dev/null
wait_for 'a deliberately opened panel' state_matches '.panel == "calendar" and (.hidden | not)'
client 0 2
wait_for 'fullscreen clears the previous interaction' state_matches '.suppressed and .hidden and .panel == "" and .interaction == "none"'
ipc notch peek 1000 >/dev/null
wait_for 'fullscreen stays hidden during an event peek' state_matches '.suppressed and .hidden'
pass 'fullscreen suppresses prior interaction and event reveal'
client 200 0
wait_for 'visibility recovers when the app no longer covers the notch' state_matches '(.suppressed | not) and (.overlapped | not) and (.hidden | not)'
pass 'smart notch returns after the covering app leaves'
