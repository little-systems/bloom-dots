#!/usr/bin/env bash
# The dock menu's shadow is drawn from its own click-through layer
# (bloom:dock-shadows), which Hyprland doesn't blur: over a light window the
# shadow still falls below the menu, the menu reads the same at its top and
# bottom, and the shadow layer never takes the click that closes the menu.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
bloom_env
export QT_QPA_PLATFORMTHEME=generic
start_sway
mkdir -p "$TEST_TMP/data/applications" "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
export XDG_DATA_DIRS="$TEST_TMP/data"
for id in a b c; do
	printf '[Desktop Entry]\nType=Application\nName=%s\nExec=true\n' "$id" > "$TEST_TMP/data/applications/$id.desktop"
done
printf '{"pinned":["a","b","c"]}\n' > "$XDG_STATE_HOME/bloom/dock.json"
printf '{"bloom-enabled-modules":["dock"],"bloom-dock-mode":"smart","bloom-dock-extras-position":"off","bloom-theme-opacity":"0.6","bloom-scale":1}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
"${QT_BIN:-/usr/lib/qt6/bin}/qml" "$ROOT/tests/integration/backdrop.qml" >"$TEST_TMP/backdrop.log" 2>&1 &
pixel() {
	grim -t ppm -g "$1 1x1" - | python3 -c "import sys; d = sys.stdin.buffer.read(); print(d[-3])"
}
light() { (( $(pixel "100,100") > 200 )); }
wait_for "the light backdrop" light
start_shell
settled() { ipc dock state | jq -e '.[0] | .expanded and .visible and (.hidden | not)' >/dev/null; }
wait_for "the dock to open" settled
sleep 1.5
BTN=273 python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 960 1050 click 1
menu_open() { ipc dock state | jq -e '.[0].menuBox != null' >/dev/null; }
wait_for "the menu to open" menu_open
sleep 0.8
# The menu box, on screen: the dock surface sits at the bottom edge.
read -r left top width height < <(ipc dock state | jq -r '.[0] | (1080 - .surfaceHeight) as $y0 | .menuBox | "\(.x|floor) \((.y + $y0)|floor) \(.width|floor) \(.height|floor)"')
mid=$((left + width / 2))
inside_top="$(pixel "$mid,$((top + 6))")"
inside_bottom="$(pixel "$mid,$((top + height - 6))")"
(( inside_top - inside_bottom <= 3 && inside_bottom - inside_top <= 3 )) || fail "menu reads $inside_top at its top but $inside_bottom at its bottom"
pass "the shadow doesn't show through the menu"
right="$(pixel "$((left + width + 6)),$((top + height / 2))")"
(( right < 225 )) || fail "no shadow beside the menu ($right)"
pass "the shadow still falls around the menu"
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 $((left + width + 12)) $((top + height / 2)) click 1
menu_closed() { ipc dock state | jq -e '.[0].menuBox == null' >/dev/null; }
wait_for "a click on the shadow to close the menu" menu_closed
pass "the shadow layer doesn't take clicks"
