#!/usr/bin/env bash
# Adaptive app theming (spec §5.3). `apply IMAGE` themes other apps from the
# wallpaper, backing their files up the first time. `restore` puts them back. It
# deletes nothing: a file that didn't exist before is left empty, which the apps
# read as no theme. Everything happens under $BLOOM_THEME_HOME (default $HOME).
set -euo pipefail

home="${BLOOM_THEME_HOME:-$HOME}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/bloom/app-themes"
config="$(cd "$(dirname "${BASH_SOURCE[0]}")/../theming" && pwd)/matugen.toml"
targets=(
	.config/gtk-3.0/gtk.css
	.config/gtk-4.0/gtk.css
	.config/fuzzel/fuzzel_theme.ini
	.config/hypr/hyprland/colors.lua
	.config/kdeglobals
	.local/state/quickshell/user/generated/terminal/kitty-theme.conf
)

reload_apps() {
	pkill -USR1 -x kitty || true
}

# The manifest lists what existed, so its presence means the backup is whole.
backup() {
	[[ -e "$state/manifest" ]] && return
	local rel
	mkdir -p "$state"
	chmod 700 "$state"
	: > "$state/manifest.new"
	for rel in "${targets[@]}"; do
		if [[ -f "$home/$rel" ]]; then
			mkdir -p "$state/$(dirname "$rel")"
			cp -p -- "$home/$rel" "$state/$rel"
			printf '%s\n' "$rel" >> "$state/manifest.new"
		fi
	done
	mv "$state/manifest.new" "$state/manifest"
}

# Plasma ignores a scheme it thinks is already set, so two names take turns.
apply_qt() {
	command -v plasma-apply-colorscheme >/dev/null || return 0
	local schemes="$home/.local/share/color-schemes" name=BloomAdaptiveA
	grep -q '^ColorScheme=BloomAdaptiveA' "$home/.config/kdeglobals" 2>/dev/null && name=BloomAdaptiveB
	sed "s/^ColorScheme=.*/ColorScheme=$name/; s/^Name=.*/Name=Bloom Adaptive ${name: -1}/" "$schemes/BloomAdaptive.colors" > "$schemes/$name.colors"
	HOME="$home" plasma-apply-colorscheme "$name" >/dev/null 2>&1 || true
}

case "${1:-}" in
	apply)
		[[ -n "${2:-}" ]] || { echo "usage: $0 apply IMAGE" >&2; exit 2; }
		backup
		HOME="$home" matugen image "$2" --config "$config" --mode dark --source-color-index 0 >/dev/null
		apply_qt
		reload_apps
		;;
	restore)
		[[ -e "$state/manifest" ]] || exit 0
		for rel in "${targets[@]}"; do
			if grep -qxF "$rel" "$state/manifest"; then
				cp -p -- "$state/$rel" "$home/$rel"
			elif [[ -e "$home/$rel" ]]; then
				: > "$home/$rel"
			fi
		done
		mv "$state/manifest" "$state/manifest.restored"
		reload_apps
		;;
	*)
		echo "usage: $0 apply IMAGE | restore" >&2
		exit 2
		;;
esac
