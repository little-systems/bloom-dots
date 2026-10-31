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
