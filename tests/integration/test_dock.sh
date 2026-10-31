#!/usr/bin/env bash
# The dock on headless sway: it loads per screen, shows pins from the state
# file, pins and unpins over IPC, launches the pinned app (Super+Alt+N's
# action) and changes mode live, with no warnings. No Hyprland here, so no
# running windows and no global shortcuts.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway not installed"
	exit 0
fi
bloom_env
# The isolated XDG_DATA_DIRS below has no host KDE colour schemes.
export QT_QPA_PLATFORMTHEME=generic
start_sway

mkdir -p "$TEST_TMP/data/applications" "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
# Desktop-entry Exec has its own quoting rules, so the fixture takes a plain
# path (mktemp paths have no spaces).
sed "s|@LAUNCHED@|$TEST_TMP/launched|" "$ROOT/tests/integration/fixtures/applications/bloom-test-app.desktop" \
	>"$TEST_TMP/data/applications/bloom-test-app.desktop"
sed "s|@LAUNCHED@|$TEST_TMP/term-launched|" "$ROOT/tests/integration/fixtures/applications/bloom-test-term.desktop" \
	>"$TEST_TMP/data/applications/bloom-test-term.desktop"
# A stand-in terminal, chosen through $TERMINAL as the user's would be: it
# runs `-e cmd…` and records that it was used.
mkdir -p "$TEST_TMP/bin"
printf '#!/bin/sh\n[ "$1" = -e ] && shift\ntouch "%s/term-used"\nexec "$@"\n' "$TEST_TMP" >"$TEST_TMP/bin/fake-term"
chmod +x "$TEST_TMP/bin/fake-term"
export TERMINAL="$TEST_TMP/bin/fake-term"
export XDG_DATA_HOME="$TEST_TMP/data" XDG_DATA_DIRS="$TEST_TMP/data"
printf '{ "bloom-enabled-modules": ["dock"], "bloom-weather-enabled": false, "bloom-dock-mode": "fixed" }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
printf '{ "pinned": ["bloom-test-app"], "order": ["remembered"] }\n' >"$XDG_STATE_HOME/bloom/dock.json"
cp "$ROOT/tests/integration/fake-picker.sh" "$TEST_TMP/bin/fake-picker"
chmod +x "$TEST_TMP/bin/fake-picker"
export BLOOM_PICKER="$TEST_TMP/bin/fake-picker" BLOOM_FAKE_PICK="$TEST_TMP/pick"
base64 -d >"$TEST_TMP/icon.png" <<'PNG'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQI12P4z8DwHwAFAAH/cpxSZwAAAABJRU5ErkJggg==
PNG
start_shell

state() { ipc dock state | jq -c ".[0] | {$1}"; }
state_is() { [[ "$(state "$1")" == "$2" ]]; }
state_icon_is_set() { ipc dock state | jq -e '.[0].icons["bloom-test-app"] | endswith("dock-icons/bloom-test-app.png")' >/dev/null; }
state_has_no_segment() { ipc dock state | jq -e '.[0].keys | index("|workspaces|") == null' >/dev/null; }

wait_for "the dock to settle with its pin" state_is "keys,height,y" '{"keys":["bloom-test-app"],"height":52,"y":0}'
pass "dock loads and shows the pinned app"
assert_eq "$(state "previewOpen")" '{"previewOpen":false}' "no toplevel capture on headless sway"

assert_eq "$(ipc dock pin nope)" "unknown app" "pin of a missing entry"
assert_eq "$(ipc dock pin bloom-test-app)" "already pinned" "double pin"
pass "pin refuses unknown and duplicate ids"

# Desktop entries load after start; activate answers "cannot launch" until then.
wait_for "activating slot 1 to launch the app" ipc_equals ok dock activate 1
wait_for "the app to run" test -f "$TEST_TMP/launched"
pass "activating a pinned app that isn't running launches it"
assert_eq "$(ipc dock activate 5)" "no app in slot 5" "empty slot"

assert_eq "$(ipc dock pin bloom-test-term)" "ok" "pin a Terminal=true app"
wait_for "activating slot 2 to launch the terminal app" ipc_equals ok dock activate 2
wait_for "the terminal app to run" test -f "$TEST_TMP/term-launched"
test -f "$TEST_TMP/term-used" || fail "the terminal app did not run in a terminal"
assert_eq "$(ipc dock unpin bloom-test-term)" "ok" "unpin the terminal app"
pass "Terminal=true apps open in the user's terminal"

assert_eq "$(ipc dock unpin bloom-test-app)" "ok" "unpin"
wait_for "the pin to leave" state_is "keys" '{"keys":[]}'
wait_for "the state file to drop it" grep -q '"pinned": \[\]' "$XDG_STATE_HOME/bloom/dock.json"
ipc dock pin bloom-test-app >/dev/null
wait_for "the pin to return" state_is "keys" '{"keys":["bloom-test-app"]}'
pass "pin and unpin persist to dock.json"

ipc settings set bloom-dock-mode peek >/dev/null
wait_for "peek mode to hide the dock" state_is "hidden,y" '{"hidden":true,"y":100}'
ipc settings set bloom-dock-mode smart >/dev/null
wait_for "smart mode without Hyprland to show it" state_is "hidden,overlapped" '{"hidden":false,"overlapped":false}'
pass "modes change live"

wait_for "no segment without Hyprland" state_has_no_segment
pass "no workspace segment outside Hyprland"

assert_eq "$(ipc dock setVisible false)" "ok" "setVisible"
wait_for "hiding by the user" state_is "visible,y" '{"visible":false,"y":150}'
ipc dock setVisible true >/dev/null

icons_dir="$XDG_STATE_HOME/bloom/dock-icons"
icon_path() { ipc dock state | jq -r '.[0].icons["bloom-test-app"] // ""'; }
toast_is() { [[ "$(ipc dock state | jq -r '.[0].toast')" == "$1" ]]; }
icon_count() { find "$icons_dir" -type f 2>/dev/null | wc -l; }
icon_set() { [[ -n "$(icon_path)" ]]; }
icon_not() { [[ "$(icon_path)" != "$1" ]]; }
file_gone() { ! test -f "$1"; }
count_is() { [[ "$(icon_count)" == "$1" ]]; }

assert_eq "$(ipc dock setIcon bloom-test-app "$TEST_TMP/icon.png")" "ok" "setIcon"
wait_for "the icon in state" icon_set
first="$(icon_path)"
[[ "$first" == "$icons_dir"/bloom-test-app-*.png && -f "$first" ]] || fail "copied into dock-icons under a unique name: $first"
assert_eq "$(ipc dock setIcon bloom-test-app /etc/hostname)" "unsupported type" "non-image"
assert_eq "$(ipc dock setIcon bloom-test-term "$TEST_TMP/icon.png")" "not pinned" "only pinned apps get icons"

# Review I6: a second change gets a new file (so the image cache can't show
# the old one) and the old copy goes.
cp "$TEST_TMP/icon.png" "$TEST_TMP/icon2.png"
ipc dock setIcon bloom-test-app "$TEST_TMP/icon2.png" >/dev/null
wait_for "the second icon" icon_not "$first"
second="$(icon_path)"
wait_for "the old copy to go" file_gone "$first"
assert_eq "$(icon_count)" "1" "one copy in dock-icons"

# Review I6: an image Qt can't load keeps the old icon, says so, and leaves no copy.
printf 'not an image' >"$TEST_TMP/bad.png"
ipc dock setIcon bloom-test-app "$TEST_TMP/bad.png" >/dev/null
wait_for "the bad-image toast" toast_is "Couldn't use that image"
assert_eq "$(icon_path)" "$second" "the old icon stays"
wait_for "no stray copy" count_is 1

assert_eq "$(ipc dock resetIcon bloom-test-app)" "ok" "resetIcon"
wait_for "the copy to go" file_gone "$second"
pass "custom icons: unique copies, checked images, old copies removed, reset"

# Review I8: the picker's three outcomes (BLOOM_PICKER is the stub).
printf '%s\n0\n' "$TEST_TMP/icon.png" >"$BLOOM_FAKE_PICK"
assert_eq "$(ipc dock pickIcon bloom-test-app)" "ok" "pickIcon"
wait_for "the picked icon" icon_set
picked="$(icon_path)"
serial="$(ipc dock state | jq -r '.[0].toastSerial')"
printf '\n1\n' >"$BLOOM_FAKE_PICK"
ipc dock pickIcon bloom-test-app >/dev/null
sleep 1
assert_eq "$(icon_path)" "$picked" "cancel keeps the icon"
assert_eq "$(ipc dock state | jq -r '.[0].toastSerial')" "$serial" "cancel says nothing"
printf '\n127\n' >"$BLOOM_FAKE_PICK"
ipc dock pickIcon bloom-test-app >/dev/null
wait_for "the no-picker toast" toast_is "Install kdialog or zenity to choose icons"
ipc dock resetIcon bloom-test-app >/dev/null
pass "the picker: chosen sets the icon, cancel does nothing, missing says what to install"

ipc dock pin bloom-test-term >/dev/null
assert_eq "$(ipc dock reorder '["bloom-test-term","bloom-test-app"]')" "ok" "reorder"
wait_for "the new order" state_is "keys" '{"keys":["bloom-test-term","bloom-test-app"]}'
assert_eq "$(ipc dock reorder '["nope"]')" "order must list the pinned apps" "reorder refuses a different set"
ipc dock unpin bloom-test-term >/dev/null
jq -e '.order == ["remembered"]' "$XDG_STATE_HOME/bloom/dock.json" >/dev/null || fail "pin edits lost remembered running order"
pass "reorder persists and refuses a different set"

ipc settings set bloom-dock-workspaces-enabled false >/dev/null
assert_eq "$(ipc settings get bloom-dock-workspaces-enabled)" "false" "workspaces setting"
pass "the workspaces setting applies without warnings"

problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
# The broken test image is meant to fail decoding (once, in the check itself).
problems="$(grep -v 'Error decoding: .*bloom-test-app-.*: Unsupported image format' <<<"$problems" || true)"
if [[ ! -S /run/dbus/system_bus_socket ]]; then
	problems="$(grep -viE 'upower|powerprofiles|dbus' <<<"$problems" || true)"
fi
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no warnings or errors in the shell log"
