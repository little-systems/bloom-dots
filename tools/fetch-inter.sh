#!/bin/sh
# Builds shell/assets/fonts/BloomInter-{400,500,600,700}.ttf from the Inter
# files Google Fonts serves Bloom's stylesheet (tools/build-inter.py). Needs
# curl and a python3 with fontTools and brotli: FONTTOOLS_PYTHON names one
# (e.g. a venv's), else python3.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/shell/assets/fonts"
PY="${FONTTOOLS_PYTHON:-python3}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
# Bloom's stylesheet, as Chromium is served it (WOFF2 subsets).
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36"
curl -fsSL -A "$UA" -o "$TMP/inter.css" "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
n=0
for url in $(grep -oE "https://fonts\.gstatic\.com/[^)]+\.woff2" "$TMP/inter.css" | awk '!seen[$0]++'); do
	n=$((n + 1))
	curl -fsSL -o "$TMP/subset-$n.woff2" "$url"
done
curl -fsSL -o "$OUT/OFL.txt" "https://github.com/google/fonts/raw/main/ofl/inter/OFL.txt"
# shellcheck disable=SC2046
"$PY" -I "$ROOT/tools/build-inter.py" "$OUT" $(ls "$TMP"/subset-*.woff2)
