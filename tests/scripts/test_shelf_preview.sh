#!/usr/bin/env bash
# shell/scripts/shelf-preview.sh: what a shelf tile shows for a path.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/shell/scripts/shelf-preview.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/Photos"
printf 'first line\nsecond line\n' > "$TMP/notes.md"
head -c 50000 /dev/zero | tr '\0' 'a' > "$TMP/big.log"
printf 'x' > "$TMP/clip.mp4"

expect() {
	local got
	local out
	out=$(sh "$SCRIPT" "$1")
	got=${out%%$'\n'*}
	[[ "$got" == "$2" ]] || { echo "FAIL: $1 -> '$got', not '$2'"; exit 1; }
}
expect "$TMP/Photos" folder
expect "$TMP/notes.md" text
expect "$TMP/clip.mp4" file
expect "$TMP/nothing-here.txt" missing
out=$(sh "$SCRIPT" "$TMP/notes.md")
[[ "$out" == $'text\n\nfirst line\nsecond line' ]] || { echo "FAIL: kind, an empty thumbnail line, then the text: $out"; exit 1; }
# A text file is read only so far: 1600 bytes are plenty for 400 characters.
out=$(sh "$SCRIPT" "$TMP/big.log")
size=$(( ${#out} - 6 ))
(( size <= 1600 )) || { echo "FAIL: read $size bytes of a large file"; exit 1; }
# The thumbnail candidates after the path: the first that exists comes back
# on the second line (none: an empty line).
touch "$TMP/thumb-normal.png"
out=$(sh "$SCRIPT" "$TMP/clip.mp4" "$TMP/thumb-large.png" "$TMP/thumb-normal.png")
[[ "$out" == $'file\n'"$TMP/thumb-normal.png" ]] || { echo "FAIL: thumbnail line: $out"; exit 1; }
out=$(sh "$SCRIPT" "$TMP/clip.mp4" "$TMP/none.png")
[[ "$out" == $'file\n' || "$out" == "file" ]] || { echo "FAIL: no thumbnail: $out"; exit 1; }
echo "ok - shelf previews: folders, a text file's opening, other files, missing paths"
