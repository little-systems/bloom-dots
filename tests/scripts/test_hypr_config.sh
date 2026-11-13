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
# Windows, workspaces, fades and layers ease in and out on Bloom's curves:
# a gentle start, a gentle landing and no overshoot, at fixed durations.
python3 - "$ROOT/hypr/desktop.lua" <<'PY' || fail "window motion doesn't ease gently"
import re, sys
text = open(sys.argv[1]).read()
curves = {m[0]: tuple(float(v) for v in m[1:]) for m in re.findall(
    r'hl\.curve\("(bloom\w*)",\s*\{\s*type = "bezier",\s*points = \{\s*\{([\d.]+),\s*([\d.]+)\},\s*\{([\d.]+),\s*([\d.]+)\}\s*\}\s*\}\)', text)}
anims = {m[0]: (float(m[1]), m[2]) for m in re.findall(
    r'hl\.animation\(\{\s*leaf = "(\w+)",\s*enabled = true,\s*speed = ([\d.]+),\s*bezier = "(\w+)"[^}]*\}\)', text)}
leaves = {"windows", "windowsIn", "windowsOut", "windowsMove", "workspaces", "fade", "fadeIn", "fadeOut", "layers", "layersIn", "layersOut", "border"}
assert leaves <= set(anims), f"leaves left on Hyprland's defaults: {sorted(leaves - set(anims))}"
for leaf, (speed, curve) in anims.items():
    assert curve in curves, f"{leaf} uses {curve}, not one of Bloom's curves"
    x1, y1, x2, y2 = curves[curve]
    assert all(0 <= v <= 1 for v in (y1, y2)), f"{curve} overshoots"
    assert x1 >= 0.25 and y1 <= 0.1, f"{curve} starts abruptly"
    assert x2 <= 0.3 and y2 == 1, f"{curve} lands abruptly"
for leaf in ("windowsIn", "windowsMove", "workspaces"):
    assert 2 <= anims[leaf][0] <= 2.5, f"{leaf} isn't 200-250 ms"
for leaf in ("windowsOut", "fadeOut", "layersOut"):
    assert anims[leaf][0] <= 1.5, f"{leaf} closes slower than 150 ms"
assert re.search(r'leaf = "windowsIn"[^}]*style = "popin 95%"', text), "windows don't open with popin 95%"
assert re.search(r'leaf = "workspaces"[^}]*style = "slide"', text), "workspaces don't slide"
PY
echo "ok - windows ease in and out gently, with no overshoot"
# A lone tiled window fills its workspace; floating ones keep their corners.
python3 - "$ROOT/hypr/desktop.lua" <<'PY' || fail "tiling isn't polished"
import re, sys
text = open(sys.argv[1]).read()
assert re.search(r'hl\.workspace_rule\(\{[^}]*"w\[tv1\]"[^}]*gaps_out = 0[^}]*\}\)', text), "a lone window keeps its gaps"
rule = re.search(r'hl\.window_rule\(\{\s*name = "bloom-lone-window".*?\}\)\n', text, re.S)
assert rule and "float = false" in rule[0] and 'workspace = "w[tv1]"' in rule[0], "the lone-window rule must skip floating windows"
assert "border_size = 0" in rule[0] and "rounding = 0" in rule[0], "a lone window keeps its border or corners"
# smart_split picks the direction from the cursor, so tall windows split into
# skinny columns; dwindle's default splits by the window's shape instead.
assert not re.search(r'smart_split = true', text), "splits follow the cursor's triangle and make skinny columns"
PY
echo "ok - a lone tiled window fills its workspace; splits follow each window's shape"
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
