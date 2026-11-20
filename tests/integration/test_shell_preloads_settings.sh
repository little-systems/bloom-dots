#!/usr/bin/env bash
# Owner: the shell preloads Settings at login, hidden, so it opens at once.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env
export BLOOM_SETTINGS_PRELOAD=1
mkdir -p "$XDG_CONFIG_HOME/bloom"
printf '{"bloom-enabled-modules":["notch"],"bloom-weather-enabled":false}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
# Instances are told apart by real path; the scripts resolve the config link.
APP="$(realpath "$XDG_CONFIG_HOME/quickshell/bloom/settings-app.qml")"
hidden() { qs --no-color ipc -p "$APP" call settingsapp state 2>/dev/null | jq -e '.visible == false' >/dev/null; }
WAIT_S=20 wait_for "the shell to preload a hidden Settings" hidden
pass "the shell preloads Settings, hidden"
before=$(qs --no-color ipc -p "$APP" call settingsapp state | jq -r .instance)
assert_eq "$(ipc settings open)" "ok" "open from the shell"
shown() { qs --no-color ipc -p "$APP" call settingsapp state 2>/dev/null | jq -e --arg i "$before" '.visible and .instance == $i' >/dev/null; }
wait_for "the preloaded Settings to show" shown
pass "the shell opens the preloaded Settings instead of starting another"

# `bloom settings` names the checkout, the shell its config link: both must
# reach the same preloaded Settings.
qs --no-color ipc -p "$APP" call settingsapp close >/dev/null
timeout 5 sh "$ROOT/shell/scripts/open-settings.sh" "$ROOT/shell/settings-app.qml" || fail "opening through the checkout path started another Settings"
wait_for "the same Settings to show through the checkout path" shown
pass "opening through the checkout path reaches the preloaded Settings"
qs --no-color ipc -p "$APP" call settingsapp quit >/dev/null 2>&1 || true
qs --no-color ipc -p "$ROOT/shell/settings-app.qml" call settingsapp quit >/dev/null 2>&1 || true
