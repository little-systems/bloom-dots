#!/bin/sh
# Decodes clipboard images for the launcher's thumbnails. Usage: clip-thumbs.sh ID...
# Prints "id<TAB>path" per image. The folder is private and in the runtime dir,
# so what was copied stays off the disk and goes at logout. That dir is memory,
# so an image over 32 MiB is skipped and only the newest 60 are kept.
dir="${XDG_RUNTIME_DIR:?}/bloom-clips"
max_bytes=33554432
keep=60
[ "$#" -gt "$keep" ] && keep=$#
mkdir -p "$dir" && chmod 700 "$dir" || exit 1
for id in "$@"; do
	case "$id" in *[!0-9]*) continue ;; esac
	file="$dir/$id"
	if [ ! -s "$file" ]; then
		# One byte past the cap tells an oversized image from one that fits.
		printf '%s\t\n' "$id" | timeout 3 cliphist decode 2>/dev/null | head -c $((max_bytes + 1)) > "$file.tmp"
		if [ "$(wc -c < "$file.tmp")" -le "$max_bytes" ] && [ -s "$file.tmp" ]; then
			mv "$file.tmp" "$file"
		else
			rm -f "$file.tmp"
		fi
	fi
	# Served images count as newest, so pruning can't remove what was just printed.
	[ -s "$file" ] && touch "$file" && printf '%s\t%s\n' "$id" "$file"
done
# Newest first; everything past the newest $keep goes.
find "$dir" -maxdepth 1 -type f -regex '.*/[0-9]+' -printf '%T@ %f\n' | sort -rn | tail -n +$((keep + 1)) |
	while read -r _ old; do rm -f "$dir/$old"; done
exit 0
