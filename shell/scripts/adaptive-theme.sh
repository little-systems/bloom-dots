#!/usr/bin/env bash
# Application theming for every Bloom mode (spec §5.3). `palette` themes other
# apps from the selected palette, `apply IMAGE` from the wallpaper, `restore`
# puts them back. Renderers write into a staging copy; theme-owner.py installs
# only files Bloom still owns, backing originals up first, and leaves anything
# the owner edited, deleted or symlinked alone. Exit 3 means some files were
# left alone (listed on stdout). Everything happens under $BLOOM_THEME_HOME
# (default $HOME and the XDG roots).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme_home="${BLOOM_THEME_HOME:-$HOME}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/bloom/app-themes"
config="$here/../theming/matugen.toml"
mkdir -p "$state"
chmod 700 "$state"
# The shell and Settings may request a palette at the same time.
exec 9>>"$state/.lock"
flock 9
export BLOOM_THEME_LOCKED=1
owner() { python3 "$here/theme-owner.py" "$@" 9>&-; }
status=0
note() { local rc=0; "$@" || rc=$?; [[ $rc == 3 ]] && status=3 && return 0; return "$rc"; }

reload_apps() {
	[[ "${BLOOM_THEME_NO_RELOAD:-0}" == 1 ]] && return 0
	pkill -USR1 -x kitty || true
	if command -v hyprctl >/dev/null; then hyprctl reload >/dev/null 2>&1 || true; fi
}

# Plasma ignores a scheme it thinks is already set, so two names take turns.
render_qt() {
	local root="$1" schemes="$1/.local/share/color-schemes" name=BloomAdaptiveA
	[[ -f "$schemes/BloomAdaptive.colors" ]] || return 0
	grep -q '^ColorScheme=BloomAdaptiveA' "$root/.config/kdeglobals" 2>/dev/null && name=BloomAdaptiveB
	sed "s/^ColorScheme=.*/ColorScheme=$name/; s/^Name=.*/Name=Bloom Adaptive ${name: -1}/" "$schemes/BloomAdaptive.colors" > "$schemes/$name.colors"
	# Write the palette even without Plasma's command, so Qt sees it on launch.
	python3 - "$root/.config/kdeglobals" "$schemes/$name.colors" "$name" <<'PY_QT'
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
	qt_scheme="$name"
}

apply_qt() {
	local name="$qt_scheme"
	[[ -n "$name" ]] || return 0
	if [[ "${BLOOM_THEME_NO_RELOAD:-0}" != 1 ]] && command -v plasma-apply-colorscheme >/dev/null; then
		HOME="$theme_home" XDG_CONFIG_HOME="$theme_home/.config" XDG_DATA_HOME="$theme_home/.local/share" plasma-apply-colorscheme "$name" 9>&- >/dev/null 2>&1 || true
	fi
}

desktop_mode() {
	[[ "${BLOOM_THEME_NO_RELOAD:-0}" == 1 ]] && return 0
	command -v gsettings >/dev/null || return 0
	note owner gsettings color-scheme "prefer-$1"
	note owner gsettings gtk-theme "$(python3 "$here/app-theme.py" --gtk-theme "$1")"
}

# Render into a staging copy of the current targets, then install owned files.
stage="$(mktemp -d "$state/.stage-XXXXXX")"
trap 'rm -rf "$stage"' EXIT
qt_scheme=""

case "${1:-}" in
	palette)
		owner seed "$stage"
		mode="$(BLOOM_THEME_OUT="$stage" python3 "$here/app-theme.py")"
		render_qt "$stage"
		note owner commit "$stage"
		apply_qt
		desktop_mode "$mode"
		reload_apps
		;;
	apply)
		[[ -n "${2:-}" ]] || { echo "usage: $0 apply IMAGE" >&2; exit 2; }
		owner seed "$stage"
		HOME="$stage" matugen image "$2" --config "$config" --mode dark --source-color-index 0 >/dev/null
		render_qt "$stage"
		note owner commit "$stage"
		apply_qt
		desktop_mode dark
		reload_apps
		;;
	restore)
		note owner restore
		reload_apps
		;;
	*)
		echo "usage: $0 palette < PALETTE.json | apply IMAGE | restore" >&2
		exit 2
		;;
esac
exit "$status"
