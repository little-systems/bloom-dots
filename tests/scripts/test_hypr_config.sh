#!/usr/bin/env bash
# Bloom's Hyprland files: what the lock screen needs from the compositor, and
# (where Hyprland is installed) that both files load.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
grep -q 'session_lock_xray = true' "$ROOT/hypr/bloom.lua" || fail "the lock can't fade over the desktop (no xray): it goes black"
grep -q 'allow_session_lock_restore = true' "$ROOT/hypr/bloom.lua" || fail "a crashed lock screen can't take the lock back"
echo "ok - the lock fades over the live desktop and survives a crash"
# File dialogs float; ordinary windows whose titles merely start alike don't.
python3 - "$ROOT/hypr/desktop.lua" <<'PY' || fail "dialog titles float wrongly"
import re, sys
text = open(sys.argv[1]).read()
patterns = [re.compile(p.replace("\\\\", "\\")) for p in re.findall(r'title = "([^"]+)"', text)]
floats = lambda title: any(p.match(title) for p in patterns)
assert all(floats(t) for t in ("Open File", "Save As", "Open — Kate", "Save File - Chromium", "Library", "site.com wants to open")), "a dialog doesn't float"
assert not any(floats(t) for t in ("OpenAI - Google Chrome", "Save the date", "My Library", "Opened")), "an ordinary window floats"
PY
echo "ok - file dialogs float, look-alike windows don't"
if ! command -v Hyprland >/dev/null; then
	echo "skipped: Hyprland is not installed"
	exit 0
fi
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/config/hypr/custom"
printf 'dofile("%s/hypr/desktop.lua")\ndofile("%s/hypr/bloom.lua")\n' "$ROOT" "$ROOT" > "$T/hyprland.lua"
XDG_CONFIG_HOME="$T/config" Hyprland --verify-config -c "$T/hyprland.lua" 2>&1 | grep -q '^config ok$' || fail "Hyprland rejects Bloom's config"
echo "ok - Hyprland accepts Bloom's desktop and integration"
