#!/usr/bin/env bash
# clip-thumbs.sh with a fake cliphist: private folder, and only numeric ids.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$T/bin" "$T/run"
printf '#!/bin/sh\necho decoded >> "%s/calls"\nprintf IMG\n' "$T" > "$T/bin/cliphist"
chmod +x "$T/bin/cliphist"
export PATH="$T/bin:$PATH" XDG_RUNTIME_DIR="$T/run"
out="$(sh "$ROOT/shell/scripts/clip-thumbs.sh" 12 '../evil' 34)"
[[ "$out" == *"12"*"34"* ]] || fail "ids missing: $out"
[[ "$out" != *evil* ]] || fail "a bad id got through"
[[ "$(stat -c %a "$T/run/bloom-clips")" == 700 ]] || fail "the folder isn't private"
[[ "$(cat "$T/run/bloom-clips/12")" == IMG ]] || fail "not decoded"
sh "$ROOT/shell/scripts/clip-thumbs.sh" 12 >/dev/null
[[ "$(wc -l < "$T/calls")" == 2 ]] || fail "a cached image was decoded again"
echo "ok - thumbnails are private, validated and cached"

# Budgets: an image over 32 MiB is skipped, and the cache keeps the newest 60.
printf '#!/bin/sh\nhead -c 34000000 /dev/zero\n' > "$T/bin/cliphist"
out="$(sh "$ROOT/shell/scripts/clip-thumbs.sh" 99)"
[[ -z "$out" && ! -e "$T/run/bloom-clips/99" && ! -e "$T/run/bloom-clips/99.tmp" ]] || fail "an oversized image was kept"
printf '#!/bin/sh\nprintf IMG\n' > "$T/bin/cliphist"
for n in $(seq 100 169); do : > "$T/run/bloom-clips/$n"; printf IMG > "$T/run/bloom-clips/$n"; touch -d "@$((1700000000 + n))" "$T/run/bloom-clips/$n"; done
sh "$ROOT/shell/scripts/clip-thumbs.sh" 200 >/dev/null
count="$(find "$T/run/bloom-clips" -type f | wc -l)"
(( count <= 60 )) || fail "the cache kept $count images"
[[ -s "$T/run/bloom-clips/200" && -s "$T/run/bloom-clips/169" && ! -e "$T/run/bloom-clips/100" ]] || fail "the cache dropped the wrong images"
echo "ok - oversized images are skipped and the cache keeps the newest"
