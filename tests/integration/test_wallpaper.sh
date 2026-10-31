#!/usr/bin/env bash
# Bloom's wallpaper layer and picker through the real shell in headless sway,
# with a fake matugen and throwaway wallpapers. mpvpaper is never started.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway is not installed"
	exit 0
fi
bloom_env
start_sway
W="$TEST_TMP/walls"
mkdir -p "$XDG_CONFIG_HOME/bloom" "$TEST_TMP/bin" "$W"
cp "$ROOT/shell/assets/device-art/"*.png "$W/a.png" 2>/dev/null || python3 - "$W/a.png" <<'PY'
import struct, sys, zlib
row = b"\0" + bytes((0, 0, 255)) * 8
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 8, 8, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(row * 8)) + chunk(b"IEND", b""))
PY
cp "$W/a.png" "$W/b.png"
printf '{"bloom-enabled-modules":["wallpaper"],"bloom-weather-enabled":false,"bloom-wallpaper-dir":"%s","bloom-theme-mode":"adaptive"}\n' "$W" > "$XDG_CONFIG_HOME/bloom/settings.json"
cat > "$TEST_TMP/bin/matugen" <<SH
#!/bin/sh
echo "\$*" >> "$TEST_TMP/matugen-calls"
echo '{"colors":{"primary":{"dark":{"color":"#336699"}}}}'
SH
printf '#!/bin/sh\necho started > "%s/mpvpaper-started"\nsleep 30\n' "$TEST_TMP" > "$TEST_TMP/bin/mpvpaper"
# Theming reloads running apps: neither reaches the real session.
printf '#!/bin/sh\nexit 0\n' > "$TEST_TMP/bin/pkill"
printf '#!/bin/sh\nexit 0\n' > "$TEST_TMP/bin/plasma-apply-colorscheme"
chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
start_shell
assert_eq "$(ipc wallpaper set "$W/a.png")" "ok" "set"
has_accent() { [[ "$(ipc wallpaper state | jq -r .accent)" == "#336699" ]]; }
wait_for "the accent from matugen" has_accent
assert_eq "$(ipc wallpaper state | jq -r .path)" "$W/a.png" "the path sticks"
grep -q 'bloom-wallpaper"' "$XDG_CONFIG_HOME/bloom/settings.json" || wait_for "the setting to save" grep -q "a.png" "$XDG_CONFIG_HOME/bloom/settings.json"
pass "setting a wallpaper saves it and themes the shell"
themed() { grep -q -- "--config" "$TEST_TMP/matugen-calls"; }
wait_for "the apps to be themed" themed
pass "Adaptive themes other apps from the wallpaper"
assert_eq "$(ipc wallpaper random)" "ok" "random"
moved() { [[ "$(ipc wallpaper state | jq -r .path)" == "$W/b.png" ]]; }
wait_for "a different wallpaper" moved
pass "random picks a different wallpaper"

assert_eq "$(ipc wallpaper toggle)" "ok" "open the picker"
two() { ipc wallpaper state | jq -e '.opened and .items == 2' >/dev/null; }
wait_for "the folder listing" two
assert_eq "$(ipc wallpaper close)" "ok" "close"
pass "the picker lists the folder"

: > "$W/clip.mp4"
assert_eq "$(ipc wallpaper set "$W/clip.mp4")" "ok" "set a video"
wait_for "mpvpaper to start" test -f "$TEST_TMP/mpvpaper-started"
pass "a video runs through mpvpaper"

printf '{"bloom-enabled-modules":["wallpaper"],"bloom-weather-enabled":false,"bloom-theme-mode":"dark"}\n' > "$XDG_CONFIG_HOME/bloom/settings.json"
wait_for "the app themes to be restored" test -f "$XDG_STATE_HOME/bloom/app-themes/manifest.restored"
pass "leaving Adaptive restores the app themes"

if grep -E "WARN|ERROR" "$TEST_TMP/shell.log" | grep -vE "textinput|pipewire|clip.mp4"; then fail "shell log has warnings"; fi
pass "no warnings or errors in the shell log"
