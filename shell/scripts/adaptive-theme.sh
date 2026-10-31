#!/usr/bin/env bash
# Application theming for every Bloom mode (spec §5.3). `apply IMAGE` themes other apps from the
# wallpaper, backing their files up the first time. `restore` puts them back. It
# deletes nothing: a file that didn't exist before is left empty, which the apps
# read as no theme. Everything happens under $BLOOM_THEME_HOME (default $HOME).
set -euo pipefail

theme_home="${BLOOM_THEME_HOME:-$HOME}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/bloom/app-themes"
config="$(cd "$(dirname "${BASH_SOURCE[0]}")/../theming" && pwd)/matugen.toml"
mkdir -p "$state"
chmod 700 "$state"
# The shell and Settings may request a palette at the same time.
exec 9>"$state/.lock"
flock 9
targets=(
	.config/gtk-3.0/gtk.css
	.config/gtk-4.0/gtk.css
	.config/gtk-3.0/settings.ini
	.config/gtk-4.0/settings.ini
	.config/fuzzel/fuzzel_theme.ini
	.config/hypr/hyprland/colors.lua
	.config/kdeglobals
	.local/state/quickshell/user/generated/terminal/kitty-theme.conf
)

reload_apps() {
	[[ "${BLOOM_THEME_NO_RELOAD:-0}" == 1 ]] && return 0
	pkill -USR1 -x kitty || true
	if command -v hyprctl >/dev/null; then hyprctl reload >/dev/null 2>&1 || true; fi
}

# The manifest lists what existed, so its presence means the backup is whole.
backup() {
	[[ -e "$state/manifest" ]] && return
	local rel
	mkdir -p "$state"
	chmod 700 "$state"
	: > "$state/manifest.new"
	for rel in "${targets[@]}"; do
		if [[ -f "$theme_home/$rel" ]]; then
			mkdir -p "$state/$(dirname "$rel")"
			cp -p -- "$theme_home/$rel" "$state/$rel"
			printf '%s\n' "$rel" >> "$state/manifest.new"
		fi
	done
	if [[ "${BLOOM_THEME_NO_RELOAD:-0}" != 1 ]] && command -v gsettings >/dev/null; then
		gsettings get org.gnome.desktop.interface color-scheme > "$state/gnome-color-scheme" 2>/dev/null || true
		gsettings get org.gnome.desktop.interface gtk-theme > "$state/gnome-gtk-theme" 2>/dev/null || true
	fi
	mv "$state/manifest.new" "$state/manifest"
}

# Plasma ignores a scheme it thinks is already set, so two names take turns.
apply_qt() {
	local schemes="$theme_home/.local/share/color-schemes" name=BloomAdaptiveA
	grep -q '^ColorScheme=BloomAdaptiveA' "$theme_home/.config/kdeglobals" 2>/dev/null && name=BloomAdaptiveB
	sed "s/^ColorScheme=.*/ColorScheme=$name/; s/^Name=.*/Name=Bloom Adaptive ${name: -1}/" "$schemes/BloomAdaptive.colors" > "$schemes/$name.colors"
	# Write the palette even without Plasma's command, so Qt sees it on launch.
	python3 - "$theme_home/.config/kdeglobals" "$schemes/$name.colors" "$name" <<'PY_QT'
import configparser, pathlib, sys
path, scheme, name = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
c = configparser.ConfigParser(interpolation=None, strict=False); c.optionxform = str
c.read(path)
palette = configparser.ConfigParser(interpolation=None); palette.optionxform = str; palette.read(scheme)
for group in palette.sections():
    if group.startswith('Colors:'):
        if not c.has_section(group): c.add_section(group)
        for key, value in palette[group].items(): c[group][key] = value
if not c.has_section('General'): c.add_section('General')
c['General']['ColorScheme'] = name
path.parent.mkdir(parents=True, exist_ok=True)
with path.open('w') as f: c.write(f, space_around_delimiters=False)
PY_QT
	if [[ "${BLOOM_THEME_NO_RELOAD:-0}" != 1 ]] && command -v plasma-apply-colorscheme >/dev/null; then
		HOME="$theme_home" XDG_CONFIG_HOME="$theme_home/.config" XDG_DATA_HOME="$theme_home/.local/share" plasma-apply-colorscheme "$name" 9>&- >/dev/null 2>&1 || true
	fi
}

desktop_mode() {
	[[ "${BLOOM_THEME_NO_RELOAD:-0}" == 1 ]] && return 0
	command -v gsettings >/dev/null || return 0
	gsettings set org.gnome.desktop.interface color-scheme "prefer-$1" >/dev/null 2>&1 || true
	local gtk_theme
	gtk_theme="$(python3 "$(dirname "${BASH_SOURCE[0]}")/app-theme.py" --gtk-theme "$1")"
	gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" >/dev/null 2>&1 || true
}

case "${1:-}" in
	palette)
		backup
		mode="$(python3 "$(dirname "${BASH_SOURCE[0]}")/app-theme.py")"
		apply_qt
		desktop_mode "$mode"
		reload_apps
		;;
	apply)
		[[ -n "${2:-}" ]] || { echo "usage: $0 apply IMAGE" >&2; exit 2; }
		backup
		HOME="$theme_home" matugen image "$2" --config "$config" --mode dark --source-color-index 0 >/dev/null
		apply_qt
		desktop_mode dark
		reload_apps
		;;
	restore)
		[[ -e "$state/manifest" ]] || exit 0
		for rel in "${targets[@]}"; do
			if grep -qxF "$rel" "$state/manifest"; then
				cp -p -- "$state/$rel" "$theme_home/$rel"
			elif [[ -e "$theme_home/$rel" ]]; then
				: > "$theme_home/$rel"
			fi
		done
		if [[ "${BLOOM_THEME_NO_RELOAD:-0}" != 1 ]] && command -v gsettings >/dev/null; then
			for key in color-scheme gtk-theme; do
				[[ -s "$state/gnome-$key" ]] && gsettings set org.gnome.desktop.interface "$key" "$(cat "$state/gnome-$key")" >/dev/null 2>&1 || true
			done
		fi
		mv "$state/manifest" "$state/manifest.restored"
		reload_apps
		;;
	*)
		echo "usage: $0 palette < PALETTE.json | apply IMAGE | restore" >&2
		exit 2
		;;
esac
