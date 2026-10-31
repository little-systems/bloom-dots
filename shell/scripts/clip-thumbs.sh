#!/bin/sh
# Decodes clipboard images for the launcher's thumbnails. Usage: clip-thumbs.sh ID...
# Prints "id<TAB>path" per image. The folder is private and in the runtime dir,
# so what was copied stays off the disk and goes at logout.
dir="${XDG_RUNTIME_DIR:?}/bloom-clips"
mkdir -p "$dir" && chmod 700 "$dir" || exit 1
for id in "$@"; do
	case "$id" in *[!0-9]*) continue ;; esac
	file="$dir/$id"
	if [ ! -s "$file" ]; then
		printf '%s\t\n' "$id" | timeout 3 cliphist decode > "$file.tmp" 2>/dev/null && mv "$file.tmp" "$file"
	fi
	[ -s "$file" ] && printf '%s\t%s\n' "$id" "$file"
done
