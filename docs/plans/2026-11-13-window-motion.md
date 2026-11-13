# Window Motion and Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Windows, workspaces, fades and shell layers move on Bloom's critically damped springs, tiling gets polished defaults, and Bloom's Reduce Motion also turns Hyprland's animations off.

**Architecture:** Everything compositor-side is Hyprland 0.57 Lua in `hypr/desktop.lua` (loaded first, so user files override it). Reduce Motion is read by `hypr/bloom.lua` from `settings.json` after the user's custom files load, so it survives reloads and logins; the shell runs `hyprctl reload` when the setting changes. Timing is measured on the real compositor, because the Hyprland wiki doesn't say how `speed` interacts with a spring.

**Tech Stack:** Hyprland 0.57 Lua (`hl.curve`, `hl.animation`, `hl.workspace_rule`, `hl.window_rule`), Lua 5.4 stub harness, Python unittest, QML/JS (qmltestrunner), wf-recorder + ffmpeg for measuring.

**Spec:** `docs/specs/2026-11-13-window-motion-design.md`

## Global Constraints

- Hyprland 0.57 Lua config only; `Hyprland --verify-config` must print `config ok` for Bloom's files (existing check in `tests/scripts/test_hypr_config.sh`).
- Springs: `hl.curve(name, { type = "spring", mass = 1, stiffness = k, damping = c })` with stiffness taken from `shell/common/tokens.js` springs and **critical damping**, `c = 2 * sqrt(k * mass)`, exactly as the shell's `macos` style does (`shell/common/Spring.qml:18`). No bounce anywhere.
- Timing targets (measured, Task 4): window open and workspace switch land in 200–250 ms; window close in 120–150 ms; nothing slower than today's defaults.
- Window open style `popin 95%`; workspaces `slide`; close is a quick fade with the same popin, never `linear`.
- Personal config still wins (it loads after `desktop.lua`); only Reduce Motion overrides it, because it is an accessibility choice.
- Reduce Motion never forces animations **on**: when it is off, Bloom leaves `animations.enabled` to `desktop.lua`, the Settings page toggle (`custom/bloom-settings.lua`) and the user's files.
- Idle CPU stays at the v1.0.0 level (0.91% on UHD 620); nothing may keep the compositor redrawing when nothing moves.
- Work on branch `feat/window-motion` in a worktree; commits follow conventional commits ending with the `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` line; commit as `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit`.
- Tests never touch the live session except the explicitly live steps in Task 4, which use an empty workspace and restore the owner's wallpaper and workspace afterwards.

## Review Focus

1. `settings.json` missing, unreadable, malformed, or holding `"true"` as a string: Hyprland's config must still load; only a real `true` (JSON bool or the string `"true"`) turns animations off. Test in Task 3.
2. The user's own `custom/bloom.lua` sets `animations = { enabled = true }` while Reduce Motion is on: Reduce Motion still wins (it is applied after the custom files). Test in Task 3.
3. Shell start, and the settings file loading for the first time, must not run `hyprctl reload`; only a real change of the value does. Test in Task 3.
4. A lone **floating** or fullscreen window keeps its border and rounding; only a lone tiled window drops them. Test in Task 2.
5. The Settings page's Animations toggle set to off, with Reduce Motion off: animations stay off (Bloom emits no `animations` config at all in that case). Test in Task 3.

---

### Task 1: Bloom's springs and animation tree

**Files:**
- Modify: `hypr/desktop.lua` (the `hl.config({ ... animations = { enabled = true } ... })` block stays; new curves and animations go right after it)
- Test: `tests/scripts/test_hypr_config.sh`

**Interfaces:**
- Produces: curve names `bloomWindow` (k 500, from `springs.standard`), `bloomQuick` (k 1000, from `springs.radius`), both `mass = 1` and critically damped. Task 4 tunes only the `speed` values on `hl.animation` calls, never the curve names.

- [ ] **Step 1: Write the failing test** — add a Python block to `tests/scripts/test_hypr_config.sh`, before the `command -v Hyprland` check, printing `ok - windows move on Bloom's critically damped springs`:

```python
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
```

(Each Python block is its own `python3 - "$ROOT/hypr/desktop.lua" <<'PY' ... PY || fail "..."` heredoc, like the existing dialog check.)

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test_hypr_config.sh`
Expected: FAIL with `leaves left on Hyprland's defaults: [...]`

- [ ] **Step 3: Implement the curves and the animation tree in `hypr/desktop.lua`**

Two `hl.curve` springs (`bloomWindow`: stiffness 500, damping 44.72; `bloomQuick`: stiffness 1000, damping 63.25; mass 1) and one `hl.animation` per leaf in the test's set, all `enabled = true`: `windows`, `windowsIn` (`popin 95%`), `windowsMove`, `workspaces` (`slide`), `layers`, `layersIn` (`fade`), `border` on `bloomWindow`; `windowsOut` (`popin 95%`), `fade`, `fadeIn`, `fadeOut`, `layersOut` (`fade`) on `bloomQuick`. Starting `speed`: 2.5 for `bloomWindow` leaves, 1.5 for `bloomQuick` leaves (Task 4 measures and tunes). One comment line above them saying the stiffness comes from `tokens.js` and the damping is critical like the shell's `macos` style.

- [ ] **Step 4: Run it to verify it passes**

Run: `bash tests/scripts/test_hypr_config.sh`
Expected: all lines `ok`, including `ok - windows move on Bloom's critically damped springs` and `ok - Hyprland accepts Bloom's desktop and integration`

- [ ] **Step 5: Commit** — `feat(hypr): move windows on Bloom's critically damped springs`

### Task 2: Polished tiling

**Files:**
- Modify: `hypr/desktop.lua` (`general`/`dwindle` in the `hl.config` block; new rules after the floating rules)
- Test: `tests/scripts/test_hypr_config.sh`

**Interfaces:**
- Produces: workspace rule on selector `w[tv1]` with `gaps_out = 0, gaps_in = 0`; window rule `bloom-lone-window` matching `float = false, workspace = "w[tv1]"` with `border_size = 0, rounding = 0`; `dwindle = { preserve_split = true, smart_split = true }`.

- [ ] **Step 1: Write the failing test** — Python block in `test_hypr_config.sh` printing `ok - a lone tiled window fills its workspace; splits follow the cursor`:

```python
import re, sys
text = open(sys.argv[1]).read()
assert re.search(r'hl\.workspace_rule\(\{[^}]*"w\[tv1\]"[^}]*gaps_out = 0[^}]*\}\)', text), "a lone window keeps its gaps"
rule = re.search(r'hl\.window_rule\(\{\s*name = "bloom-lone-window".*?\}\)\n', text, re.S)
assert rule and "float = false" in rule[0] and 'workspace = "w[tv1]"' in rule[0], "the lone-window rule must skip floating windows"
assert "border_size = 0" in rule[0] and "rounding = 0" in rule[0], "a lone window keeps its border or corners"
assert re.search(r'dwindle = \{[^}]*smart_split = true', text), "new windows don't split toward the cursor"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/scripts/test_hypr_config.sh`
Expected: FAIL with `a lone window keeps its gaps`

- [ ] **Step 3: Implement the rules and dwindle option in `hypr/desktop.lua`** — the exact Lua field names must be what Hyprland 0.57 accepts; `--verify-config` in the same test is the arbiter (if `w[tv1]` or a field name is rejected, find the 0.57 name with `Hyprland --verify-config` and record the ruling). A comment line per rule saying what the user sees.

- [ ] **Step 4: Run it to verify it passes**

Run: `bash tests/scripts/test_hypr_config.sh`
Expected: all `ok`, including `ok - Hyprland accepts Bloom's desktop and integration`

- [ ] **Step 5: Commit** — `feat(hypr): a lone window fills its workspace and splits follow the cursor`

### Task 3: Reduce Motion reaches Hyprland

**Files:**
- Modify: `hypr/bloom.lua` (after the loop that loads `custom/*.lua`)
- Create: `shell/common/motion.js`
- Modify: `shell/shell.qml` (next to the existing `Render.reduceMotion` binding)
- Modify: `docs/SETTINGS.md` (`bloom-reduce-motion` row)
- Create: `tests/units/reduce_motion_cases.py`
- Modify: `tests/units/test_units.sh` (run the new cases)
- Create: `tests/qml/tst_motion.qml`

**Interfaces:**
- Produces: `motion.js` `function reloadNeeded(previous, next)` → `bool`; true only when `previous !== undefined && previous !== next`.
- Produces: in `bloom.lua`, a local `reduce_motion()` → `bool` reading `${XDG_CONFIG_HOME:-$HOME/.config}/bloom/settings.json`; when true, `hl.config({ animations = { enabled = false } })` runs after the custom files.

- [ ] **Step 1: Write the failing Lua cases** — `tests/units/reduce_motion_cases.py`, unittest, skipped without `lua`, running `hypr/bloom.lua` under the harness style of `tests/units/session_start_cases.py` (an `hl` stub whose `config` appends `options.animations` to a list printed as JSON at the end; `on`, `exec_cmd` no-ops):
  - `test_reduce_motion_turns_animations_off`: settings `{"bloom-reduce-motion": true}` → last animations call is `{"enabled": false}`.
  - `test_string_true_counts`: `{"bloom-reduce-motion": "true"}` → `{"enabled": false}`.
  - `test_off_missing_or_broken_leaves_animations_alone`: `false`, no file, `"{not json"`, an unreadable file (chmod 000) → no animations call at all, and the run exits 0.
  - `test_beats_the_users_own_file`: `custom/bloom.lua` containing `hl.config({ animations = { enabled = true } })` plus reduce motion true → last call `{"enabled": false}`.

- [ ] **Step 2: Write the failing JS case** — `tests/qml/tst_motion.qml` (TestCase importing `../../shell/common/motion.js`): `reloadNeeded(undefined, false) === false`, `reloadNeeded(undefined, true) === false`, `reloadNeeded(false, false) === false`, `reloadNeeded(false, true) === true`, `reloadNeeded(true, false) === true`.

- [ ] **Step 3: Run both to verify they fail**

Run: `python3 tests/units/reduce_motion_cases.py` and `qmltestrunner -input tests/qml/tst_motion.qml` (with `QT_QPA_PLATFORM=offscreen`, as `tests/run-all.sh` runs QML tests)
Expected: Lua cases FAIL (no animations call); QML FAIL (motion.js missing)

- [ ] **Step 4: Implement** `reduce_motion()` in `hypr/bloom.lua` (read with `io.open`, match `"bloom%-reduce%-motion"%s*:%s*"?true"?` on the raw text, `pcall`-safe so a bad file never stops the config), `motion.js` `reloadNeeded`, and in `shell/shell.qml` a property mirroring `Settings.values["bloom-reduce-motion"]` whose change handler runs `Quickshell.execDetached(["hyprctl", "reload"])` when `Motion.reloadNeeded(previous, next)`; keep the previous value in a plain property. Update the `docs/SETTINGS.md` row to: "Land every spring at once instead of animating it, and turn off window animations."

- [ ] **Step 5: Run to verify they pass**

Run: `python3 tests/units/reduce_motion_cases.py`, the QML test, and `bash tests/units/test_units.sh` (after adding the new cases to it)
Expected: all pass

- [ ] **Step 6: Commit** — `feat(motion): Reduce Motion turns off window animations too`

### Task 4: Measure, tune and feel-check on the live desktop

**Files:**
- Modify: `hypr/desktop.lua` (`speed` values only)
- Modify: `docs/specs/2026-11-13-window-motion-design.md` (a short "Measured" section)

**Interfaces:**
- Consumes: Task 1 curve and leaf names; Task 3's Reduce Motion path.

- [ ] **Step 1: Measure the current timings** — on an empty workspace (5) with Bloom's wallpaper set and confirmed (as the README screenshots did), record the screen with `wf-recorder -r 60` while opening and closing a floating kitty window and switching workspace 5→6→5; find each animation's duration from frame differences (`ffmpeg -vf "select='gt(scene,0.002)',showinfo"` timestamps, first to last changed frame). Write the numbers down.

- [ ] **Step 2: Tune `speed`** on the Task 1 leaves until open and workspace switch measure 200–250 ms and close 120–150 ms; re-run `bash tests/scripts/test_hypr_config.sh` after each change (must stay all `ok`). If `speed` turns out not to affect springs, tune stiffness instead and keep the damping critical (the Task 1 test enforces it); ledger that ruling.

- [ ] **Step 3: Check behavior live** — on the empty workspace: one kitty fills the workspace with no gaps, border or corners; a second kitty splits toward the cursor and both regain gaps; Super+drag swaps them smoothly; a floating window alone keeps its corners. Screenshot each to the scratchpad (never the owner's other workspaces).

- [ ] **Step 4: Check Reduce Motion live** — `bloom ipc settings set bloom-reduce-motion true`: `hyprctl getoption animations:enabled` (or the Lua equivalent) reports off after the reload; set it back to `false`: animations return. Restore the owner's wallpaper and workspace 1.

- [ ] **Step 5: Idle CPU** — 2 minutes idle with no cursor movement; Hyprland plus `qs` CPU must be within noise of v1.0.0's 0.91%.

- [ ] **Step 6: Commit** — record the measured numbers in the spec's "Measured" section; `perf(hypr): tune window motion to measured timings`. Then hand the owner the live feel check before merge.
