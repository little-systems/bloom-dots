#!/usr/bin/env bash
# The bundled Bloom Inter (shell/assets/fonts) covers every script subset
# Google Fonts serves Bloom: each weight's character map holds a letter from
# Latin, Latin Extended, Cyrillic, Greek, Greek Extended and Vietnamese, and
# its names and weight are what Fonts.qml expects.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FONTS="$ROOT/shell/assets/fonts"

# fc-query prints the character set as hex ranges ("20-7e a0-17f ...").
covers() {
	local file=$1 code=$((16#$2))
	fc-query -f '%{charset}' "$file" | tr ' ' '\n' | while IFS=- read -r lo hi; do
		[[ -n "$lo" ]] || continue
		hi=${hi:-$lo}
		if (( code >= 16#$lo && code <= 16#$hi )); then echo yes; break; fi
	done | grep -q yes
}

for weight in 400 500 600 700; do
	file="$FONTS/BloomInter-$weight.ttf"
	[[ -f "$file" ]] || { echo "FAIL: missing $file"; exit 1; }
	for code in 41 142 416 3a9 1f00 1ec7 20ac; do
		covers "$file" "$code" || { echo "FAIL: BloomInter-$weight lacks U+$code"; exit 1; }
	done
	family=$(fc-query -f '%{family[0]}' "$file")
	want="Bloom Inter"; [[ $weight == 500 ]] && want="Bloom Inter Medium"
	[[ "$family" == "$want" ]] || { echo "FAIL: BloomInter-$weight family is '$family', not '$want'"; exit 1; }
done
[[ -f "$FONTS/OFL.txt" ]] || { echo "FAIL: the font's licence is missing"; exit 1; }
echo "ok - Bloom Inter covers Google's subsets at every weight, under its own names, with its licence"

# Every bundled font ships with its license notice (OFL requires it).
for font in "$FONTS"/*.ttf "$FONTS"/*.woff2; do
	name="$(basename "$font")"
	family="${name%%-*}"
	grep -q "$family" "$ROOT/licenses/fonts.txt" || { echo "FAIL: no license notice for $name" >&2; exit 1; }
done
grep -q 'SIL OPEN FONT LICENSE Version 1.1' "$ROOT/licenses/fonts.txt" || { echo "FAIL: OFL text missing" >&2; exit 1; }
echo "ok - every bundled font has its license notice"
