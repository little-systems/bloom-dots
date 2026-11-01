#!/usr/bin/env bash
# Fixed dock/notch reserve app work area without cropping the wallpaper.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
if ! command -v kitty >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "kitty is required in CI" >&2; exit 1; }
	echo "skipped: kitty is not installed"
	exit 0
fi
if ! command -v wtype >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "wtype is required in CI" >&2; exit 1; }
	echo "skipped: wtype is not installed"
	exit 0
fi
bloom_env
start_sway
mkdir -p "$XDG_CONFIG_HOME/bloom"
WALL="$TEST_TMP/red.png"
python3 - "$WALL" <<'PY'
import struct, sys, zlib
row = b"\0" + bytes((255, 0, 0)) * 8
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 8, 8, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(row * 8)) + chunk(b"IEND", b""))
PY
printf '{"bloom-enabled-modules":["wallpaper","dock","notch","lock"],"bloom-wallpaper":"%s","bloom-theme-mode":"dark","bloom-weather-enabled":false,"bloom-music-mode-enabled":false,"bloom-dock-mode":"fixed","bloom-notch-mode":"fixed","bloom-scale":1.3}\n' "$WALL" > "$XDG_CONFIG_HOME/bloom/settings.json"
# Use a disposable copy so the test can authenticate through a fake PAM stack.
# The production shell and the user's PAM configuration are never changed.
mkdir -p "$TEST_TMP/pam" "$XDG_CONFIG_HOME/quickshell"
cp -a "$ROOT/shell" "$TEST_TMP/shell"
sed -i \
	-e 's/property string pamConfig: "hyprlock"/property string pamConfig: "bloom-test"/' \
	-e "s#property string pamDir: \"/etc/pam.d\"#property string pamDir: \"$TEST_TMP/pam\"#" \
	"$TEST_TMP/shell/modules/lock/LockSurface.qml"
printf 'auth [success=1 default=ignore] pam_exec.so quiet expose_authtok %s\nauth requisite pam_deny.so\nauth required pam_permit.so\naccount required pam_permit.so\n' "$TEST_TMP/pam/check" > "$TEST_TMP/pam/bloom-test"
cat > "$TEST_TMP/pam/check" <<'SH'
#!/bin/sh
read -r pw
[ "$pw" = "letmein" ]
SH
chmod +x "$TEST_TMP/pam/check"
ln -s "$TEST_TMP/shell" "$XDG_CONFIG_HOME/quickshell/bloom"
qs --no-color -c bloom >"$TEST_TMP/shell.log" 2>&1 &
SHELL_PID=$!
wait_for "the shell to answer ping" ipc_equals pong shell ping

SWAY_SOCK="$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -name 'sway-ipc.*' -print -quit)"
app_rect() {
	SWAYSOCK="$SWAY_SOCK" swaymsg -t get_tree | jq -r '[.. | objects | select(.app_id? == "bloom-workarea-probe") | .rect | "\(.y),\(.height)"] | first // empty'
}
pixel() {
	grim -t ppm -g "$1 1x1" - | python3 -c 'import sys; print(tuple(sys.stdin.buffer.read()[-3:]))'
}
red() { [[ "$(pixel "$1")" == "(255, 0, 0)" ]]; }
workarea_is() { [[ "$(app_rect)" == "$1" ]]; }

wait_for "wallpaper behind the fixed notch" red "8,8"
wait_for "wallpaper behind the fixed dock" red "8,1070"
pass "wallpaper covers the full output behind fixed panels at 130% scale"
if [[ -n "${BLOOM_SCREENSHOT:-}" ]]; then
	panels_settled() {
		ipc notch state | jq -e '.[0].width > 100' >/dev/null &&
		ipc dock state | jq -e '.[0].expanded' >/dev/null
	}
	wait_for "fixed panels to settle for the screenshot" panels_settled
	grim -o HEADLESS-1 "$BLOOM_SCREENSHOT"
fi

SWAYSOCK="$SWAY_SOCK" swaymsg exec 'kitty --class bloom-workarea-probe' >/dev/null
app_mapped() { [[ -n "$(app_rect)" ]]; }
wait_for "the app window to map" app_mapped
SWAYSOCK="$SWAY_SOCK" swaymsg '[app_id="bloom-workarea-probe"] border none' >/dev/null

wait_for "fixed panels to reserve app space" workarea_is "52,955"
pass "fixed notch and dock reserve 52 px top and 73 px bottom"

assert_eq "$(ipc settings set bloom-notch-mode smart)" "ok" "smart notch"
wait_for "smart notch to release top area" workarea_is "0,1007"
assert_eq "$(ipc settings set bloom-dock-mode smart)" "ok" "smart dock"
wait_for "smart dock to release bottom area" workarea_is "0,1080"
pass "smart modes release app space without changing the wallpaper"

assert_eq "$(ipc settings set bloom-notch-mode fixed)" "ok" "restore fixed notch"
assert_eq "$(ipc settings set bloom-dock-mode fixed)" "ok" "restore fixed dock"
wait_for "fixed area before locking" workarea_is "52,955"
assert_eq "$(ipc lock lock)" "ok" "lock"
preparing() { ipc lock state | jq -e '.preparing and (.locked == false)' >/dev/null; }
wait_for "the desktop panels to begin collapsing" preparing
if [[ -n "${BLOOM_COLLAPSE_SCREENSHOT:-}" ]]; then
	sleep 0.15
	grim -o HEADLESS-1 "$BLOOM_COLLAPSE_SCREENSHOT"
fi
notch_hidden() { ipc notch state | jq -e '.[0].visible == false' >/dev/null; }
dock_hidden() { ipc dock state | jq -e '.[0].visible == false' >/dev/null; }
wait_for "the notch to start collapsing" notch_hidden
wait_for "the dock to start collapsing" dock_hidden
locked() { ipc lock state | jq -e '.locked' >/dev/null; }
wait_for "the session lock" locked
covered() { ipc lock state | jq -e '.covered' >/dev/null; }
wait_for "the lock backdrop" covered
wait_for "locked panels to release app space" workarea_is "0,1080"
lock_wallpaper() {
	local red
	red="$(grim -t ppm -g "$1 1x1" - | python3 -c 'import sys; print(sys.stdin.buffer.read()[-3])')"
	(( red > 100 ))
}
wait_for "the lock wallpaper at the top" lock_wallpaper "960,10"
wait_for "the lock wallpaper at the bottom" lock_wallpaper "960,1073"
if [[ -n "${BLOOM_LOCK_SCREENSHOT:-}" ]]; then grim -o HEADLESS-1 "$BLOOM_LOCK_SCREENSHOT"; fi
pass "the desktop panels collapse before the lock screen, then leave it clear"

wtype -s 400 -d 30 letmein -k Return
unlocked() { ipc lock state | jq -e '.locked == false' >/dev/null; }
wait_for "authentication to unlock the screen" unlocked
notch_restored() { ipc notch state | jq -e '.[0].visible and (.[0].sessionLocked == false) and (.[0].lockPreparing == false)' >/dev/null; }
dock_restored() { ipc dock state | jq -e '.[0].visible and (.[0].sessionLocked == false) and (.[0].lockPreparing == false)' >/dev/null; }
wait_for "the notch to restore after unlock" notch_restored
wait_for "the dock to restore after unlock" dock_restored
wait_for "fixed panels to reserve app space after unlock" workarea_is "52,955"
pass "unlock restores both panels and their fixed work area"

problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" | grep -vE 'textinput|pipewire|wl_keyboard.leave' || true)"
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
