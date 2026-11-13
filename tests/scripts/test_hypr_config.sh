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
# Window motion and behavior match illogical-impulse exactly (the owner's
# choice): its curves, timings, styles, corners, dimming, snapping and splits.
python3 - "$ROOT/hypr/desktop.lua" <<'PY' || fail "window motion or behavior doesn't match illogical-impulse"
import re, sys
text = open(sys.argv[1]).read()
curves = {m[0]: tuple(float(v) for v in m[1:]) for m in re.findall(
    r'hl\.curve\("(\w+)",\s*\{\s*type = "bezier",\s*points = \{\s*\{(-?[\d.]+),\s*(-?[\d.]+)\},\s*\{(-?[\d.]+),\s*(-?[\d.]+)\}\s*\}\s*\}\)', text)}
anims = {m[0]: (float(m[1]), m[2], m[3]) for m in re.findall(
    r'hl\.animation\(\{\s*leaf = "(\w+)",\s*enabled = true,\s*speed = ([\d.]+),\s*bezier = "(\w+)"(?:,\s*style = "([^"]+)")?\s*\}\)', text)}
want_curves = {"expressiveFastSpatial": (0.42, 1.67, 0.21, 0.90), "expressiveSlowSpatial": (0.39, 1.29, 0.35, 0.98),
    "expressiveDefaultSpatial": (0.38, 1.21, 0.22, 1.00), "emphasizedDecel": (0.05, 0.7, 0.1, 1),
    "emphasizedAccel": (0.3, 0, 0.8, 0.15), "standardDecel": (0, 0, 0, 1), "menu_decel": (0.1, 1, 0, 1),
    "menu_accel": (0.52, 0.03, 0.72, 0.08), "stall": (1, -0.1, 0.7, 0.85)}
want = {"windowsIn": (3, "emphasizedDecel", "popin 80%"), "fadeIn": (3, "emphasizedDecel", ""),
    "windowsOut": (2, "emphasizedDecel", "popin 90%"), "fadeOut": (2, "emphasizedDecel", ""),
    "windowsMove": (3, "emphasizedDecel", "slide"), "border": (10, "emphasizedDecel", ""),
    "layersIn": (2.7, "emphasizedDecel", "popin 93%"), "layersOut": (2.4, "menu_accel", "popin 94%"),
    "fadeLayersIn": (0.5, "menu_decel", ""), "fadeLayersOut": (2.7, "stall", ""),
    "workspaces": (7, "menu_decel", "slide"), "specialWorkspaceIn": (2.8, "emphasizedDecel", "slidevert"),
    "specialWorkspaceOut": (1.2, "emphasizedAccel", "slidevert"), "zoomFactor": (3, "standardDecel", "")}
for name, points in want_curves.items():
    assert curves.get(name) == points, f"curve {name} is {curves.get(name)}, not {points}"
for leaf, value in want.items():
    assert anims.get(leaf) == value, f"{leaf} is {anims.get(leaf)}, not {value}"
for setting in ("gaps_in = 4", "gaps_out = 5", "gaps_workspaces = 50", "resize_on_border = true",
        "rounding = 18", "rounding_power = 2.5", "dim_inactive = true", "dim_strength = 0.05", "dim_special = 0.2",
        "smart_split = false", "smart_resizing = false", "animate_manual_resizes = false",
        "animate_mouse_windowdragging = false", "hide_special_on_workspace_change = true",
        "enabled = true, window_gap = 4, monitor_gap = 5, respect_gaps = true"):
    assert setting in text, f"missing: {setting}"
assert "bloom-lone-window" not in text and "w[tv1]" not in text, "illogical-impulse doesn't make a lone window fill the screen"
PY
echo "ok - window motion and behavior match illogical-impulse"
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
