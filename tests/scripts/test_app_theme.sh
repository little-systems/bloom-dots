#!/usr/bin/env bash
# The selected palette reaches app configs; commands use fakes, not the session.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export XDG_DATA_DIRS="$T/share"
export BLOOM_THEME_HOME="$T/home" XDG_STATE_HOME="$T/state" PATH="$T/bin:$PATH" THEME_TEST_CALLS="$T/calls"
mkdir -p "$T/bin" "$T/home/.config/gtk-3.0" "$T/home/.local/state/quickshell/user/generated/terminal"
cat > "$T/bin/gsettings" <<'FAKE'
#!/bin/sh
# Stateful like the real tool: get returns the last value set.
f="$THEME_TEST_CALLS.$3"
if [ "$1" = get ]; then cat "$f" 2>/dev/null || echo "'default'"; else echo "$*" >> "$THEME_TEST_CALLS"; echo "$4" > "$f"; fi
FAKE
for command in pkill hyprctl plasma-apply-colorscheme; do
	printf '#!/bin/sh\necho "%s $*" >> "$THEME_TEST_CALLS"\n' "$command" > "$T/bin/$command"
done
chmod +x "$T/bin/"*
echo '/* owner style */' > "$T/home/.config/gtk-3.0/gtk.css"
printf '[Settings]\ngtk-font-name=Example 11\n' > "$T/home/.config/gtk-3.0/settings.ini"
printf 'background_opacity 0.7\n' > "$T/home/.local/state/quickshell/user/generated/terminal/kitty-transparency.conf"
mkdir -p "$T/home/.local/share/themes/adw-gtk3/gtk-3.0" "$T/home/.local/share/themes/adw-gtk3-dark/gtk-3.0"
touch "$T/home/.local/share/themes/adw-gtk3/gtk-3.0/gtk.css" "$T/home/.local/share/themes/adw-gtk3-dark/gtk-3.0/gtk.css"
SCRIPT="$ROOT/shell/scripts/adaptive-theme.sh"
fail() { echo "FAIL: $1" >&2; exit 1; }
apply() {
	printf '%s\n' "$1" | bash "$SCRIPT" palette
}
apply '{"surface":{"r":245,"g":245,"b":247},"text":{"r":28,"g":28,"b":30},"accent":{"r":0,"g":122,"b":255},"light":true}'
grep -q 'window_bg_color #f5f5f7;' "$T/home/.config/gtk-4.0/gtk.css" || fail 'light GTK palette'
grep -q 'accent_color #007aff;' "$T/home/.config/gtk-4.0/gtk.css" || fail 'selected accent'
grep -q '^background #f5f5f7$' "$T/home/.local/state/quickshell/user/generated/terminal/kitty-theme.conf" || fail 'light terminal'
grep -q 'BackgroundNormal=#f5f5f7' "$T/home/.config/kdeglobals" || fail 'Qt palette'
grep -q 'prefer-light' "$T/calls" || fail 'desktop color scheme'
grep -q 'gtk-application-prefer-dark-theme=false' "$T/home/.config/gtk-3.0/settings.ini" || fail 'GTK preference'
grep -q 'gtk-theme-name=adw-gtk3$' "$T/home/.config/gtk-3.0/settings.ini" || fail 'installed light GTK theme'
grep -q 'gtk-font-name=Example 11' "$T/home/.config/gtk-3.0/settings.ini" || fail 'kept GTK font'
apply '{"surface":{"r":0,"g":0,"b":0},"text":{"r":255,"g":255,"b":255},"accent":{"r":52,"g":199,"b":89},"light":false}'
grep -q 'window_bg_color #000000;' "$T/home/.config/gtk-4.0/gtk.css" || fail 'dark GTK palette'
grep -q 'accent_color #34c759;' "$T/home/.config/gtk-4.0/gtk.css" || fail 'custom accent'
grep -q 'prefer-dark' "$T/calls" || fail 'dark desktop scheme'
grep -q 'gtk-theme-name=adw-gtk3-dark$' "$T/home/.config/gtk-3.0/settings.ini" || fail 'installed dark GTK theme for Electron'
grep -q 'gtk-theme adw-gtk3-dark' "$T/calls" || fail 'desktop uses installed GTK theme'
grep -q 'owner style' "$T/state/bloom/app-themes/originals/.config/gtk-3.0/gtk.css" || fail 'first backup retained'
grep -qx 'background_opacity 0.7' "$T/home/.local/state/quickshell/user/generated/terminal/kitty-transparency.conf" || fail 'app theming changed opacity'
if apply '{"surface":{"r":999,"g":0,"b":0}}' 2>/dev/null; then fail 'invalid palette accepted'; fi
grep -q 'window_bg_color #000000;' "$T/home/.config/gtk-4.0/gtk.css" || fail 'invalid palette changed files'
bash "$SCRIPT" restore
grep -q 'owner style' "$T/home/.config/gtk-3.0/gtk.css" || fail 'original restored'
echo 'ok - light, dark and selected accents propagate to GTK, Qt, terminal and desktop without changing opacity'
