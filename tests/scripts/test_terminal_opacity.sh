#!/usr/bin/env bash
# terminal-opacity.sh keeps the old value and puts it back. kitty is never signalled.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir "$T/bin"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/pkill"
chmod +x "$T/bin/pkill"
export PATH="$T/bin:$PATH"
echo 'background_opacity 0.700' > "$T/c"
sh "$ROOT/shell/scripts/terminal-opacity.sh" 0.8 "$T/c"
grep -q 'background_opacity 0.8' "$T/c" || fail "not set"
sh "$ROOT/shell/scripts/terminal-opacity.sh" 0.6 "$T/c"
sh "$ROOT/shell/scripts/terminal-opacity.sh" restore "$T/c"
grep -q 'background_opacity 0.700' "$T/c" || fail "the original wasn't restored"
sh "$ROOT/shell/scripts/terminal-opacity.sh" restore "$T/c"
grep -q 'background_opacity 0.700' "$T/c" || fail "a second restore changed it"
echo "ok - the terminal's opacity is set and put back"
