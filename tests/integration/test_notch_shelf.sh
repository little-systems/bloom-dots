#!/usr/bin/env bash
# Exercise the real Wayland input mask and the shelf entry point.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" != true ]] && exit 0
	exit 1
fi
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom"
printf '{"bloom-enabled-modules":["notch"],"bloom-notch-mode":"fixed","bloom-scale":1,"bloom-music-mode-enabled":false,"bloom-time-format-24h":false,"bloom-weather-enabled":false,"bloom-status-widgets":{"left":[],"right":[]}}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
has_bubble() { ipc notch state | jq -e '.[0].shelfBubble and (.[0].startupAnimating | not)' >/dev/null; }
cat > "$TEST_TMP/source.qml" <<'QML'
import QtQuick
import Quickshell
ShellRoot {
    FloatingWindow {
        title: "Shelf drag source"
        implicitWidth: 220
        implicitHeight: 150
        color: "#294364"
        Item {
            id: source
            anchors.fill: parent
            Drag.mimeData: ({ "text/plain": "Shelf pointer fixture" })
            Drag.supportedActions: Qt.CopyAction
            Drag.dragType: Drag.Automatic
            Drag.active: handler.active
            DragHandler { id: handler; target: null }
        }
    }
}
QML
qs --no-color -p "$TEST_TMP/source.qml" > "$TEST_TMP/source.log" 2>&1 &
SOURCE_PID=$!
trap 'kill "$SOURCE_PID" 2>/dev/null || true; wait "$SOURCE_PID" 2>/dev/null || true; bloom_cleanup' EXIT
source_ready() {
	local sock
	sock="$(find "$XDG_RUNTIME_DIR" -name 'sway-ipc.*.sock' | head -1)"
	SWAYSOCK="$sock" swaymsg -t get_tree | jq -e 'any(.. | objects; .name? == "Shelf drag source" and .focused)' >/dev/null
}
wait_for "the drag source window" source_ready
notch_settled() { ipc notch state | jq -e '.[0] | .visible and (.startupAnimating | not)' >/dev/null; }
wait_for "the notch to finish opening" notch_settled
# Let the source finish mapping before beginning the pointer grab.
sleep 0.5
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 960 500 drag 0 -482
dropped() { ipc shelf state | jq -e 'length == 1 and .[0].value == "Shelf pointer fixture"' >/dev/null; }
wait_for "a native text drop on the collapsed notch" dropped
pass "dragging text onto the collapsed notch opens Shelf and captures the text"
wait_for "the shelf bubble" has_bubble
sleep 0.4
if [[ -n "${BLOOM_SHELF_SCREENSHOT:-}" ]]; then
	grim -o HEADLESS-1 "$BLOOM_SHELF_SCREENSHOT"
fi
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 861 18 click 0
has_shelf() { ipc notch state | jq -e '.[0] | .panel == "shelf" and .width == 380 and .height == 176 and (.shelfBubble | not)' >/dev/null; }
wait_for "a real click on the bubble to open Shelf" has_shelf
if [[ -n "${BLOOM_SHELF_PANEL_SCREENSHOT:-}" ]]; then
	sleep 0.4
	grim -o HEADLESS-1 "$BLOOM_SHELF_PANEL_SCREENSHOT"
fi
ipc shelf remove 0 >/dev/null
removed() { ipc notch state | jq -e '.[0] | .panel != "shelf" and (.shelfBubble | not)' >/dev/null; }
wait_for "removing the last tile to return to a tool panel" removed
pass "the shelf bubble is clickable outside the pill and disappears after the last item"

leave_panel() { ipc notch state | jq -e '.[0].panel == ""' >/dev/null; }
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 960 500 hover 50
wait_for "the tool panel to close" leave_panel
ipc settings set bloom-notch-mode peek >/dev/null
hidden() { ipc notch state | jq -e '.[0].hidden' >/dev/null; }
wait_for "the notch to hide in Peek mode" hidden
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 960 500 drag 0 -499
wait_for "a native text drop on the hidden notch edge" dropped
pass "a drag reveals the hidden notch and reaches Shelf with the dock disabled"
