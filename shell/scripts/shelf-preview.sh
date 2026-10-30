#!/bin/sh
# What a shelf tile shows for a path (Bloom's shelf_preview.rs, Linux side).
# Usage: shelf-preview.sh <path> [thumbnail candidates...]
# Line 1: "folder", "text", "file" or "missing". Line 2: the first thumbnail
# candidate that exists (a file manager's, by the freedesktop spec), or
# nothing. Then, for a text file without one, its opening bytes: 1600 are
# plenty for the 400 characters a tile shows. Pictures the shell reads
# itself.
p=$1
shift
thumb=""
for t in "$@"; do
	if [ -f "$t" ]; then thumb=$t; break; fi
done
if [ -d "$p" ]; then
	printf 'folder\n%s\n' "$thumb"
elif [ ! -e "$p" ]; then
	printf 'missing\n\n'
else
	case "$(printf '%s' "${p##*/}" | sed -n 's/.*\.\([^.]*\)$/\1/p' | tr '[:upper:]' '[:lower:]')" in
	txt | md | markdown | log | csv | tsv | json | xml | yml | yaml | toml | ini | cfg | conf | env | \
		js | jsx | ts | tsx | mjs | cjs | py | rs | c | h | cpp | hpp | cs | java | kt | go | rb | php | \
		swift | html | htm | css | scss | sh | ps1 | bat | cmd | sql | lua | srt | vtt)
		printf 'text\n%s\n' "$thumb"
		[ -n "$thumb" ] || head -c 1600 -- "$p"
		;;
	*) printf 'file\n%s\n' "$thumb" ;;
	esac
fi
