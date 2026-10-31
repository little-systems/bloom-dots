#!/bin/sh
# The system facts Settings lists and changes, one tab-separated record a line.
#   autostart-list | autostart-set ID on|off
#   mime-apps MIME | vpn-list | package-of ID
user="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
system="${BLOOM_XDG_AUTOSTART:-/etc/xdg/autostart}"
apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications ${BLOOM_XDG_APPS:-/usr/share/applications}"

field() { sed -n "s/^$2=//p" "$1" | head -1; }

case "$1" in
	autostart-list)
		for file in "$user"/*.desktop "$system"/*.desktop; do
			[ -f "$file" ] || continue
			id="$(basename "$file" .desktop)"
			# A file in the user's folder overrides the system's.
			[ "$file" != "$user/$id.desktop" ] && [ -f "$user/$id.desktop" ] && continue
			name="$(field "$file" Name)"
			state=on
			[ "$(field "$file" Hidden)" = true ] && state=off
			printf '%s\t%s\t%s\n' "$id" "${name:-$id}" "$state"
		done
		;;
	autostart-set)
		case "$2" in *[!A-Za-z0-9._-]*|'') exit 2 ;; esac
		target="$user/$2.desktop"
		mkdir -p "$user" || exit 1
		if [ ! -f "$target" ]; then
			[ -f "$system/$2.desktop" ] || exit 1
			cp "$system/$2.desktop" "$target" || exit 1
		fi
		sed -i '/^Hidden=/d' "$target" || exit 1
		[ "$3" = off ] && sed -i '/^\[Desktop Entry\]/a Hidden=true' "$target"
		exit 0
		;;
	mime-apps)
		for dir in $apps; do
			[ -d "$dir" ] || continue
			grep -l "^MimeType=.*$2;" "$dir"/*.desktop 2>/dev/null | while read -r file; do
				printf '%s\t%s\n' "$(basename "$file")" "$(field "$file" Name)"
			done
		done
		;;
	vpn-list)
		nmcli -t -f NAME,TYPE,ACTIVE con show 2>/dev/null | awk -F: '$2 ~ /vpn|wireguard/ { print $1 "\t" $2 "\t" $3 }'
		;;
	package-of)
		for dir in $apps; do
			[ -f "$dir/$2.desktop" ] && exec pacman -Qoq "$dir/$2.desktop"
		done
		exit 1
		;;
	*)
		echo "usage: $0 autostart-list|autostart-set|mime-apps|vpn-list|package-of" >&2
		exit 2
		;;
esac
