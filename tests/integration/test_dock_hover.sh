#!/usr/bin/env bash
# Real compositor pointer input: the dock answers hover, also after the
# visibility toggle hides and shows it again.
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
printf '{"bloom-enabled-modules":["dock"],"bloom-dock-mode":"smart","bloom-dock-extras-position":"off"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
start_shell
settled() { ipc dock state | jq -e '.[0] | .expanded and .visible and (.hidden | not)' >/dev/null; }
wait_for "the dock to open" settled
sleep 1.5
interaction_is() { ipc dock state | jq -e --arg s "$1" '.[0].interaction == $s' >/dev/null; }
hover_dock() {
	python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 960 1050 hover 2500 &
	HOVER_PID=$!
	wait_for "the dock to answer the pointer$1" interaction_is active
	wait "$HOVER_PID" || true
}
leave_dock() {
	python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 960 400 hover 1500
	wait_for "the dock to let go" interaction_is none
}

hover_dock ""
pass "hovering the dock makes it active"
leave_dock

[[ "$(ipc dock setVisible false)" == ok ]] || fail "hiding the dock"
sleep 1
[[ "$(ipc dock setVisible true)" == ok ]] || fail "showing the dock"
wait_for "the dock to come back" settled
sleep 1.5
hover_dock " after it was hidden and shown"
pass "the dock still answers hover after the visibility toggle"
