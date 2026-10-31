#!/usr/bin/env bash
# Adaptive theming with the real matugen and real templates, in a throwaway
# home: the owner's own config files are never touched.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/shell/scripts/adaptive-theme.sh"
if ! command -v matugen >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "matugen is required in CI" >&2; exit 1; }
	echo "skipped: matugen is not installed"
	exit 0
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
export BLOOM_THEME_HOME="$T/home" XDG_STATE_HOME="$T/state" PATH="$T/bin:$PATH"
mkdir -p "$T/bin" "$T/home/.config/fuzzel" "$T/home/.config/hypr/hyprland"
printf '#!/bin/sh\necho "$*" >> "%s/plasma"\n' "$T" > "$T/bin/plasma-apply-colorscheme"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/pkill"
cat > "$T/bin/gsettings" <<'FAKE_GSETTINGS'
#!/bin/sh
if [ "$1" = get ]; then echo "'default'"; fi
exit 0
FAKE_GSETTINGS
printf '#!/bin/sh\nexit 0\n' > "$T/bin/hyprctl"
chmod +x "$T/bin/"*
echo original-fuzzel > "$T/home/.config/fuzzel/fuzzel_theme.ini"
echo original-hypr > "$T/home/.config/hypr/hyprland/colors.lua"
python3 - "$T/wall.png" <<'PY'
import struct, sys, zlib
w = 64
rows = b"".join(b"\0" + b"".join(bytes((x * 4, 90, 200 - x * 3)) for x in range(w)) for _ in range(w))
def chunk(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d))
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, w, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))
PY

bash "$SCRIPT" apply "$T/wall.png"
for f in .config/gtk-3.0/gtk.css .config/gtk-4.0/gtk.css .config/fuzzel/fuzzel_theme.ini .config/hypr/hyprland/colors.lua .local/state/quickshell/user/generated/terminal/kitty-theme.conf .local/share/color-schemes/BloomAdaptive.colors; do
	[[ -s "$T/home/$f" ]] || fail "$f wasn't written"
	if grep -q '{{' "$T/home/$f"; then fail "$f has an unfilled colour"; fi
done
grep -qE '@define-color accent_color #[0-9a-f]{6};' "$T/home/.config/gtk-4.0/gtk.css" || fail "no accent in GTK 4"
grep -qE 'selection=[0-9a-f]{8}$' "$T/home/.config/fuzzel/fuzzel_theme.ini" || fail "fuzzel colour format"
grep -qE 'active_border += "rgba\([0-9a-f]{8}\)"' "$T/home/.config/hypr/hyprland/colors.lua" || fail "Hyprland colour format"
grep -qx BloomAdaptiveA "$T/plasma" || fail "the Qt scheme wasn't applied"
echo "ok - every app's colours are written from the wallpaper"

bash "$SCRIPT" apply "$T/wall.png"
grep -q original-fuzzel "$T/state/bloom/app-themes/.config/fuzzel/fuzzel_theme.ini" || fail "a second apply overwrote the backup"
echo "ok - a second wallpaper keeps the first backup"

bash "$SCRIPT" restore
grep -q original-fuzzel "$T/home/.config/fuzzel/fuzzel_theme.ini" || fail "fuzzel wasn't restored"
grep -q original-hypr "$T/home/.config/hypr/hyprland/colors.lua" || fail "Hyprland wasn't restored"
[[ ! -s "$T/home/.config/gtk-4.0/gtk.css" ]] || fail "a file that didn't exist before kept its theme"
echo "ok - leaving Adaptive restores everything"

bash "$SCRIPT" restore || fail "restoring twice is an error"
echo modified > "$T/home/.config/fuzzel/fuzzel_theme.ini"
bash "$SCRIPT" apply "$T/wall.png"
bash "$SCRIPT" restore
grep -q modified "$T/home/.config/fuzzel/fuzzel_theme.ini" || fail "a later Adaptive restored a stale backup"
echo "ok - each Adaptive session keeps its own backup"
