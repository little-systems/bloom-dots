#!/usr/bin/env bash
# recognize-music.sh with fake tools: it never records or contacts Shazam.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/shell/scripts/recognize-music.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir "$T/bin"
fake() { printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\n%s\n' "$1" "$T" "${2:-}" > "$T/bin/$1"; chmod +x "$T/bin/$1"; }
fake notify-send
fake parec 'for last; do :; done; echo x > "$last"'
fake songrec 'echo "{\"track\":{\"title\":\"Song\",\"subtitle\":\"Band\"}}"'
export PATH="$T/bin:$PATH" BLOOM_LISTEN_SECONDS=1
bash "$S"
grep -q 'notify-send -a Bloom Song Band' "$T/calls" || fail "the song wasn't named"
echo "ok - a recognized song is named"
fake songrec 'echo "{}"'
bash "$S"
grep -q "identify that song" "$T/calls" || fail "no match wasn't reported"
echo "ok - no match says so"
fake parec 'exit 1'
: > "$T/calls"
bash "$S"
grep -q "listen to the sound" "$T/calls" || fail "a failed recording wasn't reported"
echo "ok - a failed recording says so"
