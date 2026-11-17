#!/usr/bin/env bash
# The first-run guide through the real shell on headless sway: a pending
# install opens it; the virtual pointer clicks through all nine pages; the
# Island shows during its introduction; finishing marks it completed and a
# restart doesn't reopen it.
set -euo pipefail
if [[ -z "${BLOOM_IN_DBUS:-}" ]]; then
	# A private bus that can't auto-start anything, and no route to the host
	# display or Hyprland, so nothing on it reaches the real session.
	exec env -u WAYLAND_DISPLAY -u DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE BLOOM_IN_DBUS=1 QT_NO_XDG_DESKTOP_PORTAL=1 \
		dbus-run-session --config-file="$(dirname "${BASH_SOURCE[0]}")/dbus-session.conf" -- bash "$0" "$@"
fi
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
printf '{"bloom-enabled-modules":["notch"],"bloom-notch-mode":"peek","bloom-weather-enabled":false,"bloom-reduce-motion":true,"bloom-scale":1}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
printf '{"completed": false}\n' > "$XDG_STATE_HOME/bloom/onboarding.json"
start_shell

opened() { ipc onboarding state | jq -e ".opened == $1" >/dev/null; }
reveal_is() { ipc onboarding state | jq -e ".reveal == \"$1\"" >/dev/null; }
wait_for "the guide to open on a pending install" opened true
pass "a pending install opens the guide"

# The primary button sits 24 px from the card's right edge and centred in the
# 74 px footer; the 500x400 card is centred, or 96 px from the Island/Dock edge.
click_primary() {
	local top
	case "$1" in island) top=96 ;; dock) top=$((1080 - 400 - 96)) ;; *) top=$(((1080 - 400) / 2)) ;; esac
	python3 -I "$ROOT/tests/integration/vpointer.py" 1920 1080 $((710 + 500 - 24 - 50)) $((top + 400 - 37)) click 1
	sleep 0.3
}
click_primary center
wait_for "the Island to show during its introduction" reveal_is island
pass "Meet the Island reveals the Island in Peek mode"
for anchor in island island dock dock center center center; do click_primary "$anchor"; done
reveal_is "" || fail "the reveal clears after the introductions"
click_primary center
wait_for "the guide to close after Let's bloom" opened false
assert_eq "$(jq -c . "$XDG_STATE_HOME/bloom/onboarding.json")" '{"completed":true}' "finishing records completion"
pass "Let's bloom closes the guide and records it"

kill "$SHELL_PID"; wait "$SHELL_PID" 2>/dev/null || true
rm -f "$XDG_CONFIG_HOME/quickshell/bloom"
start_shell
sleep 1
opened false || fail "a restart reopened the guide"
pass "a restart doesn't reopen it"
if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
