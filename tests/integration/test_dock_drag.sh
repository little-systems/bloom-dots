#!/usr/bin/env bash
# Real compositor pointer input, not QtTest events delivered straight to a view.
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
printf '{"bloom-enabled-modules":["dock"],"bloom-scale":1.15,"bloom-dock-mode":"smart","bloom-dock-icon-only":true,"bloom-dock-preview-enabled":false,"bloom-dock-extras-position":"off"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
settled() { ipc dock state | jq -e '.[0] | .expanded and .height == 52' >/dev/null; }
wait_for "the dock to open" settled
sleep 1.5
width="$(ipc dock state | jq -r '.[0].width')"
x="$(python3 -c 'import sys; print(round((1920-float(sys.argv[1])*1.15)/2+26*1.15))' "$width")"
python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 "$x" 1050 drag 130
ordered() { ipc dock state | jq -e '.[0].pinned == ["b","c","a"]' >/dev/null; }
wait_for "dragging a across b and c to save the new order" ordered
pass "real pointer dragging reorders dock apps"
wait_for "the drag order on disk" jq -e '.pinned == ["b","c","a"]' "$XDG_STATE_HOME/bloom/dock.json"
kill "$SHELL_PID"
wait "$SHELL_PID" || true
SHELL_PID=""
qs --no-color -c bloom >"$TEST_TMP/shell.log" 2>&1 &
SHELL_PID=$!
wait_for "the restarted shell" ipc_equals pong shell ping
wait_for "the drag order after restarting the shell" ordered
pass "drag order is saved and survives a shell restart"
