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
# Windows, workspaces, fades and layers move on Bloom's springs: stiffness
# from tokens.js, critically damped like the shell's macos style (no bounce).
python3 - "$ROOT/hypr/desktop.lua" <<'PY' || fail "window motion isn't on Bloom's springs"
import math, re, sys
text = open(sys.argv[1]).read()
curves = {m[0]: (float(m[1]), float(m[2]), float(m[3])) for m in re.findall(
    r'hl\.curve\("(\w+)",\s*\{\s*type = "spring",\s*mass = ([\d.]+),\s*stiffness = ([\d.]+),\s*damping = ([\d.]+)\s*\}\)', text)}
anims = dict(re.findall(r'hl\.animation\(\{\s*leaf = "(\w+)",[^}]*?spring = "(\w+)"[^}]*\}\)', text))
leaves = {"windows", "windowsIn", "windowsOut", "windowsMove", "workspaces", "fade", "fadeIn", "fadeOut", "layers", "layersIn", "layersOut", "border"}
assert leaves <= set(anims), f"leaves left on Hyprland's defaults: {sorted(leaves - set(anims))}"
for leaf, curve in anims.items():
    assert curve in curves, f"{leaf} uses an undefined spring {curve}"
for name, (mass, k, c) in curves.items():
    assert 1.0 <= c / (2 * math.sqrt(k * mass)) <= 1.02, f"{name} isn't critically damped (it bounces or drags)"
assert re.search(r'leaf = "windowsIn"[^}]*style = "popin 95%"', text), "windows don't open with popin 95%"
assert re.search(r'leaf = "workspaces"[^}]*style = "slide"', text), "workspaces don't slide"
assert "linear" not in re.findall(r'leaf = "windowsOut"[^}]*', text)[0], "windows close on a linear curve"
PY
echo "ok - windows move on Bloom's critically damped springs"
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
