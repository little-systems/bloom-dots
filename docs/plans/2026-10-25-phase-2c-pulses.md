# Phase 2C: Pulses and the Workspace Peek Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Bloom's notch pulses to Linux and add the workspace peek:
- **Charging pulse:** plugging in or unplugging widens the collapsed pill to 200 px for 4 s and shows "Charging • 80%" or "On Battery • 80%" with the battery glyph.
- **Low-battery pulse:** dropping to `bloom-low-battery-threshold` while discharging shows a red "Low Battery • 15%" for 5 s, once per crossing.
- **Update pulse:** when `checkupdates` finds new pacman updates, a green "Update Available" shows for 6 s. A green 5 px dot then stays under the clock while updates are pending.
- **Workspace pulse (new, D7):** switching workspace shows the workspace's name and a row of page dots for 2 s.
- **Peek mode:** each pulse also shows the hidden notch for as long as it lasts, as Bloom's event peek does.

**Architecture:**
- **Pulse rules** are plain JS (`pulses.js`), unit-tested:
  - which events fire;
  - which pulse wins when several are live;
  - labels, page dots and the peek extension.
- **Updates service:** a singleton that runs `checkupdates` hourly while something holds it, with a watchdog. Its parsing is in `updates.js`.
- **Workspaces:** `WorkspaceData.qml` reads this screen's Hyprland workspace. It is loaded only under Hyprland, as `HyprEvents.qml` is.
- **NotchView** stays pure UI. It takes `battery`, `updates` and `workspace` objects, decides when pulses fire, and swaps the collapsed row between its normal view and `PulseView` using framer's `AnimatePresence mode="wait"` timing.

**Tech Stack:** Quickshell 0.3.2 (`Quickshell.Io` Process, `Quickshell.Hyprland`, `Quickshell.Services.UPower`), Qt 6.12 Quick/Effects/Shapes/QtTest, pacman-contrib `checkupdates`, headless sway (tests).

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md`:
- §4.1 Notch "Pulses" and "workspace peek on change (D7)";
- §4.2 "Update indicator";
- §5.1 "Updates: `checkupdates` every hour";
- Appendix A: Motion "Pulses", Geometry "Pulses 200 wide", Colour "Status".

This is plan 2C, the last of three for Phase 2. It builds on 2B as merged at `8656a7b`.

## Global Constraints

- **Platform:** Arch Linux; Hyprland ≥ 0.56 (Lua config); Quickshell ≥ 0.3.
- **Layer surfaces never resize while animating:** the notch surface stays 1000×480, and only its input mask follows the pill (spec §3.3).
- **Settings:** `bloom-*` keys in native JSON types, plus Bloom for Windows' string forms. An invalid value uses its default and logs a warning.
- **Polling** happens only while something visible needs it (spec §5.1). `checkupdates` runs hourly, only while a notch with the update indicator on exists, plus on an explicit `bloom ipc updates check`.
- **Missing tools hide their feature** (spec §6). Without `checkupdates`, no dot and no update pulse; the shell logs one plain line, not a warning.
- **Motion:** framer-motion parity through `Spring`.
  - A value with no transition: opacity and `filter` use `[0.25, 0.1, 0.35, 1]` over 300 ms; scale uses a 550/30 spring with `restSpeed` 10.
  - Both are from motion-dom 12.43.0 `default-transitions.mjs`, verified below.
- **Perf:** a pulse at rest draws no frames. Springs and blur run only during the 300 ms swaps. The frame-count tests in `tst_notchview.qml` guard this.
- **Files:** nothing under `~/.config` or `~/dots-hyprland` changes, except Task 7, run by the owner after approving it.
- **Commits:** conventional commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit …`.
- **Style:** QML and JS use tabs. Comments explain why, not what.

## Review Focus

1. **Login and startup.** UPower reports the battery a moment after the shell starts, and Hyprland's workspace is set as the notch loads. Neither may fire a "Charging" or workspace pulse at login.
   - A battery that is already low at login *does* pulse once, as Bloom.
   - Tests: Task 5 `test_noPulseFromStartupValues`, `test_lowBatteryAtLoginPulsesOnce`.
2. **Hovering during a pulse.** The status strip takes the pill (Bloom `!isHovered`). The pulse comes back on leave if its time hasn't run out, and is gone if it has.
   - Test: Task 5 `test_hoverHidesAPulse`.
3. **Rapid workspace switching** (Super+1, 2, 3 in quick succession):
   - one workspace pulse whose label and dots follow, without stacking swaps;
   - a peek that ends 2 s after the *last* switch;
   - a shorter peek never cuts a longer one (an update peek) short.
   - Tests: Task 2 `test_peekNeverShortens`, Task 5 `test_rapidWorkspaceSwitchesShowOnePulse`.
4. **`checkupdates` absent, offline or stalled.**
   - Absent: no dot and one log line.
   - Offline (exit 1): the last good count stays, so the dot doesn't flicker.
   - Stalled: the watchdog ends it after 2 min.
   - Tests: Task 3 `test_parse`, `test_rose`, `test_updates.sh`.
5. **A desktop with no laptop battery, or a non-Hyprland session.**
   - No battery pulses.
   - No workspace pulse and no Hyprland warnings (the Hyprland module isn't loaded).
   - The update dot still works.
   - Tests: Task 5 `test_noBatteryNoPulse`, Task 6 `test_notch.sh` (sway).

## Rulings made while planning (the owner sees these at review)

1. **Workspace pulse content (new; Bloom has no workspace peek).** The 200 px pulse slot shows a row of page dots and the label "Workspace 3", or the workspace's name if it has one.
   - **Dots:** 5 px, gap 5; the active one is a 14 px pill; idle dots at 0.35.
   - **When dots show:** only when the monitor has 2–6 workspaces. More than 6 would crowd the 176 px row.
   - **Duration:** 2 s.
   - **Change it at review:** if the owner wants a different look (label only, a number, or a longer time), it is one component and one token.
2. **Which pulse wins** when several are live: workspace > update > low battery > charging.
   - The workspace pulse is the newest by nature and only 2 s long. Bloom had one slot with update first.
   - The others keep their timers, so a battery pulse still in its time shows again once the workspace pulse ends.
3. **Update pulses fire only when the count rises**, including the first check after login. Bloom pulsed on every check that found an update, which on Arch would be every hour.
4. **`bloom-show-update-indicator` off stops the checks entirely.** No dot, no pulse and no `checkupdates`. Bloom kept checking for its own updater.
5. **A peek extends and never shortens.** Bloom's `triggerEventPeek` replaced the timer, so a 2 s workspace peek would cut a 6 s update peek short and hide a pulse still on screen.
6. **Swap timing:** `AnimatePresence mode="wait"` waits for the exiting view's animations. The exit scale spring (550/30, restSpeed 10) and the 300 ms opacity fade end within a frame of each other, so the swap waits a fixed 300 ms.
7. **Blur:** framer's `filter: blur(4px)` becomes a `MultiEffect` blur with `blurMax` 8 and `blur` = px / 8 (2B's px/blurMax convention). The effect redraws only while blur or opacity changes.
8. **`bloom update` (shell self-update, spec §4.2) is not in 2C.** It belongs with the installer (Phase 7). 2C only covers pacman updates.

---

## File map

| File | Responsibility |
|---|---|
| `shell/services/settings.js`, `docs/SETTINGS.md` | `bloom-show-update-indicator`, `bloom-workspace-peek-enabled`; threshold doc |
| `shell/common/tokens.js` | + `pulse` and `updates` tokens |
| `shell/modules/notch/pulses.js` | Pulse rules: events, winner, labels, dots, peek extension |
| `shell/modules/notch/music.js` | `contentWidth` gains the 200 px pulse width |
| `shell/services/updates.js`, `shell/services/Updates.qml` | `checkupdates` parsing; hourly held checks with a watchdog |
| `shell/services/Battery.qml` | + `ready` |
| `shell/modules/notch/UpdateArrow.qml`, `PageDots.qml`, `PulseItem.qml`, `PulseView.qml` | Pulse visuals and the wait-mode swap |
| `shell/modules/notch/NotchView.qml` | Fires pulses, swaps the row, update dot, peek |
| `shell/modules/notch/WorkspaceData.qml`, `NotchWindow.qml`, `shell/shell.qml` | Wiring; `updates` IPC |
| `tests/qml/tst_settings.qml`, `tst_pulses.qml`, `tst_music.qml`, `tst_updates.qml`, `tst_pulseview.qml`, `tst_notchview.qml` | Unit and component tests |
| `tests/integration/test_updates.sh`, `test_notch.sh` | Updates service and the notch's dot, end to end |

## Verified facts this plan relies on (checked on the owner's machine, 2026-10-25)

- **Bloom pulse behaviour** (App.tsx, App.css @ b5fb962):
  - **Charging:** `showPowerPulse` fires when `isCharging` differs from its previous value after `isReady`. It lasts 4000 ms; in peek mode `triggerEventPeek(4000)`. `isCharging` is the battery's charging flag (battery.rs `CHARGING_FLAG`), not AC power.
  - **Low battery:** fires when `isReady && level <= threshold && !isCharging` and it hasn't been shown. It lasts 5000 ms, with peek 5000. It re-arms when charging or when the level goes above the threshold. Default threshold 20.
  - **Update:** fires on each `update-available` event with `available: true`. It lasts 6000 ms, with peek 6000. `available: false` ends it.
  - **Width:** `getDynamicWidth` returns 200 for any pulse when not hovered. It comes after the music-hover, status-hover, calendar/shelf/panels and open-player checks, and before the collapsed music width.
  - **Content:** `AnimatePresence mode="wait"` between `standard-view`, `pulse-view` and `update-pulse-view`.
    - Pulse items: `initial {opacity 0, scale 0.95, blur 4px}`, `animate {1, 1, 0}`, `exit {0, 1.05, 4px}`, no transition given.
    - Standard view: opacity 0 ↔ 1, no transition.
  - **Layout:** `.power-pulse-content` is a centred flex row with gap 10. Label 13/600, white (light mode `--bloom-text`).
    - Low battery label `#FF453A`; update label `#32D74B`.
    - The battery pulse shows the update arrow first while an update is pending, then the battery glyph, then "Low Battery" / "Charging" / "On Battery", " • ", level, "%".
  - **Update arrow** (`GreenDownArrowIcon`):
    - circle: 18×18, fill `rgba(50,215,75,0.15)`, 1 px border `rgba(50,215,75,0.35)`, shadow `0 0 8px rgba(50,215,75,0.25)`;
    - glyph: 10×10, viewBox 24, stroke `#32D74B` width 3, round caps and joins;
    - paths: line 12,4→12,16; polyline 18,10 12,16 6,10; line 6,20→18,20.
  - **Update dot:** 5 px circle `#32d74b`, under the clock.
    - It is centred on `.time-center`, which holds a 24 px `.time-flip-container` centred in the 36 px row.
    - `top: 100%; margin-top: -4px` puts the dot's top at row y = 6 + 24 − 4 = 26.
    - Shown when `updateAvailable && bloom-show-update-indicator` (default true), in both status and collapsed-music modes.
- **framer defaults** (motion-dom 12.43.0, `animation/utils/default-transitions.mjs`):
  - scale → `{ spring, stiffness 550, damping 30 (target ≠ 0), restSpeed 10 }`;
  - other non-transform values → `{ keyframes, ease [0.25, 0.1, 0.35, 1], duration 0.3 }`.
- **`checkupdates`** (pacman-contrib 1.13.1, installed):
  - exit 0 means updates, one `name old -> new` line each (7 lines today);
  - exit 2 means none; exit 1 means it failed.
  - It needs no root (it syncs a private db copy).
- **Quickshell `Process`** (probe, 2026-10-25):
  - `StdioCollector.onStreamFinished` runs before `onExited(code, status)`, and the collector's `text` is complete inside `onExited`.
  - Setting `running = false` kills the process; `onExited` then gets code 15.
  - A missing binary never emits `exited`. It logs a WARN "Process failed to start" and only flips `running` to false. So the command runs through `sh -c` and reports 127 instead.
- **Quickshell Hyprland** (probe on the live session, 2026-10-25):
  - `Hyprland.focusedMonitor.activeWorkspace` has `id` 2 and `name` "2";
  - `Hyprland.workspaces.values` lists `HyprlandWorkspace`s with `id`, `name`, `monitor` and `toplevels`;
  - `Hyprland.monitorFor(screen)` exists (qmltypes).
  - Under `QT_QPA_PLATFORM=offscreen`, `Quickshell.screens` is empty, so the per-screen path is checked live in Task 7.
- **UPower:** `UPowerDevice.ready` exists (qmltypes, `bindableReady`).

---

### Task 1: Pulse settings

**Files:**
- Modify: `shell/services/settings.js` (after `"bloom-low-battery-threshold"`)
- Modify: `docs/SETTINGS.md` (regenerated)
- Test: `tests/qml/tst_settings.qml`

**Interfaces:**
- Produces: settings `bloom-show-update-indicator` (bool, default true) and `bloom-workspace-peek-enabled` (bool, default true).

- [ ] **Step 1: Write the failing test**

Add to `tests/qml/tst_settings.qml`, after `test_musicDefaults`:

```qml
	function test_pulseDefaults() {
		const d = Settings.defaults();
		compare(d["bloom-show-update-indicator"], true);
		compare(d["bloom-workspace-peek-enabled"], true);
		const off = Settings.validate({ "bloom-show-update-indicator": "false" });
		compare(off.values["bloom-show-update-indicator"], false, "Bloom's string form");
		compare(off.warnings, []);
	}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | tail -5`
Expected: FAIL in `test_pulseDefaults` (`undefined` vs `true`).

- [ ] **Step 3: Add the keys**

In `shell/services/settings.js`, replace the `"bloom-low-battery-threshold"` entry and add two keys after it:

```js
	"bloom-low-battery-threshold": {
		type: "number",
		min: 5,
		max: 50,
		default: 20,
		doc: "Battery percentage at or below which the battery fill turns red and the notch shows a low-battery pulse."
	},
	"bloom-show-update-indicator": {
		type: "bool",
		default: true,
		doc: "Check for pacman updates hourly (needs pacman-contrib) and show a green dot under the clock while some are pending, with a pulse when new ones arrive."
	},
	"bloom-workspace-peek-enabled": {
		type: "bool",
		default: true,
		doc: "Briefly show the workspace in the notch when you switch to it (Hyprland)."
	},
```

- [ ] **Step 4: Regenerate the reference and run the tests**

Run: `node tools/gen-settings-doc.mjs && /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | tail -3 && node tools/gen-settings-doc.mjs --check`
Expected: `Totals: N passed, 0 failed`, and the doc check passes.

- [ ] **Step 5: Commit**

```bash
git add shell/services/settings.js docs/SETTINGS.md tests/qml/tst_settings.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the update indicator and workspace peek settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Pulse rules and tokens

**Files:**
- Create: `shell/modules/notch/pulses.js`
- Modify: `shell/modules/notch/music.js` (`contentWidth`)
- Modify: `shell/common/tokens.js` (append `pulse`, `updates`)
- Test: `tests/qml/tst_pulses.qml` (new), `tests/qml/tst_music.qml`

**Interfaces:**
- Produces (`pulses.js`, imported as `Pulses`):
  - `powerPulse(prevCharging, charging)` → bool. `prevCharging` is `null` until the battery is first known.
  - `lowBatteryStep(armed, b)` → `{ fire: bool, armed: bool }`, with `b = { available, ready, level, charging, threshold }`.
  - `workspacePulse(prevId, id)` → bool. `prevId` is `null` until known.
  - `activePulse(s)` → `"" | "workspace" | "update" | "low" | "power"`, with `s = { workspace, update, low, power, hovered, open }`.
  - `viewKey(kind)` → `"" | "workspace" | "update" | "battery"`.
  - `batteryLabel(kind, b)` → string.
  - `workspaceLabel(ws)` → string.
  - `pageDots(ws)` → array of ids (empty means no dots).
  - `peekUntil(now, current, ms)` → number (ms epoch).
- Produces (`music.js`): `contentWidth(s)` reads `s.pulse` (string; non-empty means 200).
- Produces (tokens): `Tokens.pulse`, `Tokens.updates` (values below).

- [ ] **Step 1: Write the failing tests**

Create `tests/qml/tst_pulses.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/notch/pulses.js" as Pulses

TestCase {
	name: "PulseRules"

	function test_powerPulse() {
		verify(Pulses.powerPulse(false, true), "plugged in");
		verify(Pulses.powerPulse(true, false), "unplugged");
		verify(!Pulses.powerPulse(true, true));
		verify(!Pulses.powerPulse(null, true), "the first reading is not a change");
	}

	function battery(props) {
		const b = { available: true, ready: true, level: 50, charging: false, threshold: 20 };
		for (const k in props) b[k] = props[k];
		return b;
	}

	// Bloom fires once per crossing and re-arms on charging or recovery.
	function test_lowBatteryStep() {
		let r = Pulses.lowBatteryStep(true, battery({ level: 20 }));
		verify(r.fire, "at the threshold");
		verify(!r.armed);
		r = Pulses.lowBatteryStep(r.armed, battery({ level: 19 }));
		verify(!r.fire, "once per crossing");
		r = Pulses.lowBatteryStep(r.armed, battery({ level: 19, charging: true }));
		verify(!r.fire);
		verify(r.armed, "charging re-arms");
		r = Pulses.lowBatteryStep(false, battery({ level: 21 }));
		verify(r.armed, "recovering above the threshold re-arms");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 10, charging: true })).fire, "not while charging");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 10, ready: false })).fire, "not before UPower answers");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 0, available: false })).fire, "no battery, no pulse");
		compare(Pulses.lowBatteryStep(false, battery({ level: 10, ready: false })).armed, false, "unknown keeps the state");
	}

	function test_workspacePulse() {
		verify(Pulses.workspacePulse(1, 2));
		verify(!Pulses.workspacePulse(2, 2), "the same workspace (its window list changed)");
		verify(!Pulses.workspacePulse(null, 2), "the workspace at login");
		verify(!Pulses.workspacePulse(2, null));
	}

	function s(props) {
		const o = { workspace: false, update: false, low: false, power: false, hovered: false, open: false };
		for (const k in props) o[k] = props[k];
		return o;
	}

	function test_activePulse() {
		compare(Pulses.activePulse(s({})), "");
		compare(Pulses.activePulse(s({ power: true })), "power");
		compare(Pulses.activePulse(s({ power: true, low: true })), "low");
		compare(Pulses.activePulse(s({ low: true, update: true })), "update");
		compare(Pulses.activePulse(s({ update: true, workspace: true })), "workspace");
		compare(Pulses.activePulse(s({ update: true, hovered: true })), "", "the status strip wins on hover");
		compare(Pulses.activePulse(s({ update: true, open: true })), "", "never over an open player");
	}

	function test_viewKey() {
		compare(Pulses.viewKey(""), "");
		compare(Pulses.viewKey("power"), "battery");
		compare(Pulses.viewKey("low"), "battery", "Bloom's one pulse-view: no swap between them");
		compare(Pulses.viewKey("update"), "update");
		compare(Pulses.viewKey("workspace"), "workspace");
	}

	function test_batteryLabel() {
		compare(Pulses.batteryLabel("low", { level: 15, charging: false }), "Low Battery • 15%");
		compare(Pulses.batteryLabel("power", { level: 80, charging: true }), "Charging • 80%");
		compare(Pulses.batteryLabel("power", { level: 80, charging: false }), "On Battery • 80%");
	}

	function test_workspaceLabel() {
		compare(Pulses.workspaceLabel({ id: 3, name: "3" }), "Workspace 3");
		compare(Pulses.workspaceLabel({ id: 4, name: "" }), "Workspace 4");
		compare(Pulses.workspaceLabel({ id: 5, name: "web" }), "web");
	}

	function test_pageDots() {
		compare(Pulses.pageDots({ id: 2, ids: [1, 2, 3] }), [1, 2, 3]);
		compare(Pulses.pageDots({ id: 1, ids: [1] }), [], "one workspace: nothing to place");
		compare(Pulses.pageDots({ id: 7, ids: [1, 2, 3, 4, 5, 6, 7] }), [], "more than 6 would crowd the row");
		compare(Pulses.pageDots({ id: 2, ids: [3, 1, 2] }), [1, 2, 3], "in order");
	}

	// Review focus 3: a short peek never cuts a longer one short.
	function test_peekNeverShortens() {
		compare(Pulses.peekUntil(1000, 0, 2000), 3000);
		compare(Pulses.peekUntil(1000, 7000, 2000), 7000, "an update peek still running");
		compare(Pulses.peekUntil(6000, 7000, 2000), 8000);
	}
}
```

Add to `tests/qml/tst_music.qml`, after `test_contentWidth`:

```qml
	// Bloom: a pulse widens the collapsed pill to 200, after the hover and
	// open-player checks.
	function test_pulseWidth() {
		compare(widthOf({ pulse: "power" }), 200, "status mode");
		compare(widthOf({ pulse: "update", mode: "music" }), 200, "collapsed music");
		compare(widthOf({ pulse: "", mode: "status" }), 140);
		compare(widthOf({ pulse: "power", hovered: true }), 300, "the hovered strip wins");
		compare(widthOf({ pulse: "power", open: true, mode: "music" }), 340, "the open player wins");
	}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_pulses.qml 2>&1 | tail -3; /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_music.qml 2>&1 | grep -E "FAIL|Totals"`
Expected:
- `tst_pulses.qml` fails to load: `pulses.js` is missing.
- `tst_music.qml` fails `test_pulseWidth` (status mode returns 140).

- [ ] **Step 3: Write `pulses.js`**

Create `shell/modules/notch/pulses.js`:

```js
// Notch pulses ported from Bloom (App.tsx @ b5fb962), plus the workspace
// pulse (spec D7). Plain JS, shared with the unit tests.

// Bloom showPowerPulse: the charging flag changed. The first reading (the
// battery as UPower first reports it) is not a change.
function powerPulse(prevCharging, charging) {
	return prevCharging !== null && prevCharging !== charging;
}

// Bloom showLowBatteryPulse: once per drop to the threshold while
// discharging; charging or recovering above it re-arms. An unknown battery
// keeps the state as it was.
function lowBatteryStep(armed, b) {
	if (!b.available || !b.ready)
		return { fire: false, armed: armed };
	if (b.charging || b.level > b.threshold)
		return { fire: false, armed: true };
	return { fire: armed, armed: false };
}

function workspacePulse(prevId, id) {
	return prevId !== null && id !== null && prevId !== id;
}

// One slot: the newest kind (the workspace pulse is the shortest) first,
// then Bloom's update-over-battery order. Hover and the open player win
// over all of them (Bloom !isHovered).
function activePulse(s) {
	if (s.hovered || s.open)
		return "";
	if (s.workspace)
		return "workspace";
	if (s.update)
		return "update";
	if (s.low)
		return "low";
	if (s.power)
		return "power";
	return "";
}

// Bloom's AnimatePresence keys: charging and low battery share pulse-view,
// so switching between them changes the label without a swap.
function viewKey(kind) {
	if (kind === "low" || kind === "power")
		return "battery";
	return kind;
}

function batteryLabel(kind, b) {
	const state = kind === "low" ? "Low Battery" : b.charging ? "Charging" : "On Battery";
	return `${state} • ${b.level}%`;
}

function workspaceLabel(ws) {
	return ws.name && ws.name !== String(ws.id) ? ws.name : `Workspace ${ws.id}`;
}

// Page dots fit the 176 px row beside the label for up to 6 workspaces.
function pageDots(ws) {
	const ids = ws.ids.slice().sort((a, b) => a - b);
	return ids.length >= 2 && ids.length <= 6 ? ids : [];
}

// Bloom's triggerEventPeek replaced the running peek; here a shorter peek
// never ends a longer one early (it would hide a pulse still on screen).
function peekUntil(now, current, ms) {
	return Math.max(current, now + ms);
}
```

- [ ] **Step 4: Add the pulse width to `music.js`**

Replace `contentWidth` in `shell/modules/notch/music.js`:

```js
// Bloom getDynamicWidth, in its order.
function contentWidth(s) {
	if (s.onStatusHover)
		return 170 + (s.visualizer ? 30 : 0);
	if (s.mode === "status" && s.hovered)
		return Notch.statusWidth(true, s.widgetCount, s.fitWidth, s.use24h);
	if (s.open)
		return s.layout === "compact" ? 300 : 340;
	if (s.pulse)
		return 200;
	if (s.mode === "status")
		return Notch.statusWidth(false, s.widgetCount, s.fitWidth, s.use24h);
	let w = 140 - (s.use24h ? 16 : 0);
	if (s.visualizer && s.playing)
		w += 30;
	if (s.albumArt)
		w += 30;
	return w;
}
```

- [ ] **Step 5: Add the tokens**

Append to `shell/common/tokens.js`:

```js
// Pulses (Bloom App.tsx/App.css @ b5fb962; workspace pulse is new, D7).
var pulse = {
	width: 200,
	gap: 10,
	labelSize: 13,
	powerMs: 4000,
	lowBatteryMs: 5000,
	updateMs: 6000,
	workspaceMs: 2000,
	enterScale: 0.95,
	exitScale: 1.05,
	blur: 4,
	blurMax: 8,
	fadeMs: 300,
	arrow: { box: 18, glyph: 10, stroke: 3 },
	dot: { size: 5, top: 26 },
	pageDot: { size: 5, activeWidth: 14, gap: 5, idleOpacity: 0.35 }
};

// pacman updates (spec §5.1): hourly while held; a stalled check ends at 2 min.
var updates = { firstCheckMs: 60000, intervalMs: 3600000, timeoutMs: 120000 };
```

- [ ] **Step 6: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -3`
Expected: `Totals: N passed, 0 failed` (every existing music width test still passes).

- [ ] **Step 7: Commit**

```bash
git add shell/modules/notch/pulses.js shell/modules/notch/music.js shell/common/tokens.js tests/qml/tst_pulses.qml tests/qml/tst_music.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the notch pulse rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Updates service

**Files:**
- Create: `shell/services/updates.js`, `shell/services/Updates.qml`
- Modify: `shell/shell.qml` (an `updates` IpcHandler)
- Modify: `tests/integration/lib.sh` (`bloom_env` points `BLOOM_CHECKUPDATES` at a missing file, so no test ever runs the real `checkupdates`)
- Test: `tests/qml/tst_updates.qml` (new), `tests/integration/test_updates.sh` (new), `tests/integration/updates-fake.sh` (new)

**Interfaces:**
- Consumes: `Tokens.updates` (Task 2).
- Produces (`Updates` singleton, `qs.services`):
  - `hold(key: string, on: bool)`;
  - `check()`;
  - `count: int`, `available: bool` (count > 0), `installed: bool` (false after a 127);
  - `signal arrived()`: emitted when a check's count is higher than the last good one.
- Produces (IPC): `updates state` → JSON `{ "available": bool, "count": int, "installed": bool, "checking": bool }`; `updates check` → `"ok"`.

- [ ] **Step 1: Write the failing unit test**

Create `tests/qml/tst_updates.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/services/updates.js" as Updates

TestCase {
	name: "UpdatesParse"

	function test_parse() {
		const some = Updates.parse(0, "fuzzel 1.15.0-1 -> 1.15.0-2\njdk-openjdk 27.0.1-1 -> 27.0.1-2\n");
		verify(some.ok);
		compare(some.count, 2);
		compare(some.packages, ["fuzzel", "jdk-openjdk"]);
		const none = Updates.parse(2, "");
		verify(none.ok);
		compare(none.count, 0);
		verify(!Updates.parse(1, "").ok, "offline or a broken mirror");
		verify(!Updates.parse(15, "a 1 -> 2\n").ok, "killed by the watchdog");
		const missing = Updates.parse(127, "");
		verify(!missing.ok);
		verify(missing.missing, "checkupdates is not installed");
		compare(Updates.parse(0, "\n").count, 0, "blank output");
	}

	// Pulse when new updates appear, not every hour that some are pending.
	function test_rose() {
		verify(Updates.rose(0, 7), "the first check that finds updates");
		verify(Updates.rose(7, 9), "more arrived");
		verify(!Updates.rose(7, 7), "the same updates an hour later");
		verify(!Updates.rose(9, 2), "after a partial upgrade");
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_updates.qml 2>&1 | tail -3`
Expected: fails to load (`updates.js` missing).

- [ ] **Step 3: Write `updates.js`**

Create `shell/services/updates.js`:

```js
// checkupdates results (pacman-contrib). Plain JS, shared with the tests.
// Exit 0 lists one "name old -> new" line per update; 2 means none; anything
// else failed (1: offline or a sync error; 15: ended by the watchdog). The
// service runs it through `sh -c`, which reports 127 when it isn't installed.
function parse(code, stdout) {
	if (code === 127)
		return { ok: false, missing: true, count: 0, packages: [] };
	if (code === 2)
		return { ok: true, missing: false, count: 0, packages: [] };
	if (code !== 0)
		return { ok: false, missing: false, count: 0, packages: [] };
	const packages = stdout.split("\n").map(l => l.trim()).filter(l => l !== "").map(l => l.split(" ")[0]);
	return { ok: true, missing: false, count: packages.length, packages: packages };
}

// The pulse fires when new updates appear, not every hour that some are pending.
function rose(prevCount, count) {
	return count > prevCount;
}
```

- [ ] **Step 4: Run the unit test**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_updates.qml 2>&1 | tail -3`
Expected: `Totals: 4 passed, 0 failed` (initTestCase, test_parse, test_rose, cleanupTestCase).

- [ ] **Step 5: Write the failing integration test**

Create `tests/integration/updates-fake.sh`. It is a fake `checkupdates` driven by `$BLOOM_FAKE_UPDATES` (a file holding the exit code, then the lines):

```bash
#!/usr/bin/env bash
# A stand-in checkupdates for tests: the first line of $BLOOM_FAKE_UPDATES is
# the exit code, the rest is printed. "hang" as the code never answers.
set -euo pipefail
code="$(head -1 "$BLOOM_FAKE_UPDATES")"
if [[ "$code" == hang ]]; then exec sleep 600; fi
tail -n +2 "$BLOOM_FAKE_UPDATES"
exit "$code"
```

Create `tests/integration/test_updates.sh`:

```bash
#!/usr/bin/env bash
# The Updates service end to end with a fake checkupdates: counts, a failed
# check keeping the last good count, a missing tool, and arrivals.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
bloom_env

mkdir -p "$TEST_TMP/bin" "$XDG_CONFIG_HOME/bloom"
cp "$ROOT/tests/integration/updates-fake.sh" "$TEST_TMP/bin/checkupdates"
chmod +x "$TEST_TMP/bin/checkupdates"
export BLOOM_CHECKUPDATES="$TEST_TMP/bin/checkupdates" BLOOM_FAKE_UPDATES="$TEST_TMP/fake"
printf '{ "bloom-weather-enabled": false }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"

printf '0\nfuzzel 1 -> 2\njdk 1 -> 2\n' >"$BLOOM_FAKE_UPDATES"
start_shell
state() { ipc updates state | jq -c "{$1}"; }
state_is() { [[ "$(state "$1")" == "$2" ]]; }

assert_eq "$(ipc updates check)" "ok" "check"
wait_for "the first check" state_is "available,count,checking" '{"available":true,"count":2,"checking":false}'
pass "a check counts pending updates"

printf '1\n' >"$BLOOM_FAKE_UPDATES"
ipc updates check >/dev/null
wait_for "the failed check to finish" state_is "checking" '{"checking":false}'
assert_eq "$(state "count")" '{"count":2}' "a failed check keeps the last good count"
pass "offline keeps the dot steady"

printf '2\n' >"$BLOOM_FAKE_UPDATES"
ipc updates check >/dev/null
wait_for "no updates" state_is "available,count" '{"available":false,"count":0}'
pass "exit 2 clears it"

rm "$TEST_TMP/bin/checkupdates"
ipc updates check >/dev/null
wait_for "the missing tool" state_is "installed,available" '{"installed":false,"available":false}'
log_has "checkupdates is not installed" || fail "no note about the missing tool"
pass "a missing checkupdates hides the indicator"

problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no warnings"
```

The watchdog is not exercised here (its 2 min timeout is a token). Step 8 checks it by hand with a 1 s token.

- [ ] **Step 6: Run it to verify it fails**

Run: `bash tests/integration/test_updates.sh`
Expected: FAIL. `bloom ipc updates check` errors: there is no `updates` IPC target.

- [ ] **Step 7: Write the service and the IPC**

Create `shell/services/Updates.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "updates.js" as Logic
import "../common/tokens.js" as Tokens

// Pending pacman updates (spec §4.2, §5.1) for the notch's dot and pulse.
// Checks once a minute after something holds it, then hourly, and on demand
// (`bloom ipc updates check`). A failed check keeps the last good count so
// the dot doesn't flicker while offline.
Singleton {
	id: root

	property int count: 0
	property bool installed: true
	readonly property bool available: root.installed && root.count > 0
	readonly property bool checking: proc.running
	// A check found more updates than the last good one (the pulse).
	signal arrived()

	property var _holders: ({})
	readonly property bool active: Object.keys(root._holders).length > 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	function check() {
		if (!proc.running)
			proc.running = true;
	}

	function _finish(code, text) {
		const r = Logic.parse(code, text);
		if (r.missing) {
			if (root.installed)
				console.log("bloom updates: checkupdates is not installed (pacman-contrib); the update indicator is off");
			root.installed = false;
			root.count = 0;
			return;
		}
		root.installed = true;
		if (!r.ok)
			return;
		const rose = Logic.rose(root.count, r.count);
		root.count = r.count;
		if (rose)
			root.arrived();
	}

	onActiveChanged: {
		if (root.active)
			first.restart();
		else
			first.stop();
	}

	Timer {
		id: first
		interval: Tokens.updates.firstCheckMs
		onTriggered: root.check()
	}

	Timer {
		interval: Tokens.updates.intervalMs
		repeat: true
		running: root.active
		onTriggered: root.check()
	}

	Timer {
		id: watchdog
		interval: Tokens.updates.timeoutMs
		onTriggered: proc.running = false
	}

	Process {
		id: proc
		// Through sh so a missing checkupdates exits 127; a missing binary
		// started directly never reports an exit.
		// BLOOM_CHECKUPDATES points tests at a fake, so they never sync the real databases.
		command: ["sh", "-c", 'c="${BLOOM_CHECKUPDATES:-checkupdates}"; command -v "$c" >/dev/null || exit 127; exec "$c"']
		onRunningChanged: {
			if (proc.running)
				watchdog.restart();
			else
				watchdog.stop();
		}
		stdout: StdioCollector { id: out }
		onExited: code => root._finish(code, out.text)
	}
}
```

The rule "pulse only when the count rises" lives in `updates.js` (`rose`), not `pulses.js`. Only the service knows the last good count across failed checks.

Add to `shell/shell.qml`, after the `settings` IpcHandler:

```qml
	IpcHandler {
		target: "updates"

		function state(): string {
			return JSON.stringify({ available: Updates.available, count: Updates.count, installed: Updates.installed, checking: Updates.checking });
		}

		// Checks now (after an upgrade, the dot would otherwise wait an hour).
		function check(): string {
			Updates.check();
			return "ok";
		}
	}
```

In `tests/integration/lib.sh` `bloom_env`, after the `export QT_QPA_PLATFORM…` line, add:

```bash
	# Never sync the real pacman databases from a test (tests that need
	# updates point this at tests/integration/updates-fake.sh).
	export BLOOM_CHECKUPDATES="$TEST_TMP/no-checkupdates"
```

- [ ] **Step 8: Run the tests and check the watchdog**

Run: `bash tests/integration/test_updates.sh`
Expected: every `ok -` line, ending `ok - no warnings`.

Watchdog check (manual; revert afterwards):
1. Set `timeoutMs: 1000` in `Tokens.updates`.
2. Put `printf 'hang\n'` in the fake.
3. Run `ipc updates check` in a scratch copy of the test, and confirm `checking` returns to `false` within 2 s while `count` keeps its last value.
4. Restore `timeoutMs: 120000`, and ledger the result.

- [ ] **Step 9: Commit**

```bash
git add shell/services/updates.js shell/services/Updates.qml shell/shell.qml tests/integration/lib.sh tests/qml/tst_updates.qml tests/integration/test_updates.sh tests/integration/updates-fake.sh
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: check for pacman updates

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Pulse visuals and the wait-mode swap

**Files:**
- Create: `shell/modules/notch/UpdateArrow.qml`, `PageDots.qml`, `PulseItem.qml`, `PulseView.qml`
- Test: `tests/qml/tst_pulseview.qml` (new)

**Interfaces:**
- Consumes: `Pulses.viewKey`, `batteryLabel`, `workspaceLabel`, `pageDots`, `Tokens.pulse`, `Tokens.status.green/red`, `BatteryIcon.qml`.
- Produces:
  - **`PulseView`.** Inputs:
    - `kind: string` (from `activePulse`);
    - `battery: var { level, charging, threshold }`;
    - `updateAvailable: bool`;
    - `workspace: var { id, name, ids } | null`;
    - `textColor: color`.

    Outputs:
    - `readonly shownKey: string` (the view on screen: `""`, `"battery"`, `"update"` or `"workspace"`);
    - `readonly standardOpacity: real` (the normal row's opacity; NotchView binds its row to it).

    Child objectNames: `"pulse-battery"`, `"pulse-update"`, `"pulse-workspace"`, and each label `"pulse-label"`.
  - `PulseItem`: `present: bool`, `default property alias content`. It plays framer's initial/animate/exit for one AnimatePresence child.

- [ ] **Step 1: Write the failing component test**

Create `tests/qml/tst_pulseview.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 400
	height: 100

	Component {
		id: viewComponent
		PulseView {
			width: 176
			height: 36
			battery: ({ level: 80, charging: true, threshold: 20 })
			workspace: ({ id: 2, name: "2", ids: [1, 2, 3] })
		}
	}

	TestCase {
		name: "PulseView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		function label(v, key) {
			return findChild(findChild(v, "pulse-" + key), "pulse-label").text;
		}

		// AnimatePresence mode="wait": the normal row leaves before a pulse enters.
		function test_waitsForTheExit() {
			const v = make();
			compare(v.shownKey, "");
			compare(v.standardOpacity, 1);
			v.kind = "power";
			compare(v.shownKey, "", "still leaving");
			tryCompare(v, "shownKey", "battery", 600);
			tryCompare(v, "standardOpacity", 0, 300);
			compare(label(v, "battery"), "Charging • 80%");
			v.kind = "";
			tryCompare(v, "shownKey", "", 600);
			tryCompare(v, "standardOpacity", 1, 600);
		}

		function test_lowAndPowerShareOneView() {
			const v = make({ kind: "power" });
			tryCompare(v, "shownKey", "battery", 600);
			v.battery = { level: 15, charging: false, threshold: 20 };
			v.kind = "low";
			compare(v.shownKey, "battery", "no swap");
			compare(label(v, "battery"), "Low Battery • 15%");
			compare(findChild(findChild(v, "pulse-battery"), "pulse-label").color, Qt.color("#FF453A"));
		}

		function test_updateViewAndArrow() {
			const v = make({ kind: "update" });
			tryCompare(v, "shownKey", "update", 600);
			compare(label(v, "update"), "Update Available");
			compare(findChild(findChild(v, "pulse-update"), "pulse-label").color, Qt.color("#32D74B"));
			v.kind = "power";
			v.updateAvailable = true;
			tryCompare(v, "shownKey", "battery", 900);
			verify(findChild(findChild(v, "pulse-battery"), "update-arrow").shown, "Bloom shows the arrow beside the battery");
		}

		function test_workspaceDotsAndLabel() {
			const v = make({ kind: "workspace" });
			tryCompare(v, "shownKey", "workspace", 600);
			compare(label(v, "workspace"), "Workspace 2");
			compare(findChild(v, "page-dots").count, 3);
			v.workspace = { id: 3, name: "3", ids: [1, 2, 3] };
			compare(label(v, "workspace"), "Workspace 3", "follows without a swap");
			v.workspace = { id: 1, name: "1", ids: [1] };
			compare(findChild(v, "page-dots").count, 0);
		}

		// A key that flips back while leaving finishes the exit first, then
		// settles on what is wanted now.
		function test_flipWhileLeaving() {
			const v = make({ kind: "update" });
			tryCompare(v, "shownKey", "update", 600);
			v.kind = "";
			v.kind = "update";
			wait(700);
			compare(v.shownKey, "update");
			compare(findChild(v, "pulse-update").opacity, 1, "back in after the exit finished");
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_pulseview.qml 2>&1 | tail -3`
Expected: fails to load (`PulseView` is not a type).

- [ ] **Step 3: Write `UpdateArrow.qml`**

```qml
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../common/tokens.js" as Tokens

// Bloom's GreenDownArrowIcon: a green-tinted 18 px disc with a soft glow and
// a 10 px download arrow (viewBox 24, stroke 3, round caps).
Item {
	id: root
	objectName: "update-arrow"
	// `visible` reads false inside an effect source, so layout and tests use this.
	property bool shown: true
	visible: root.shown
	implicitWidth: Tokens.pulse.arrow.box
	implicitHeight: Tokens.pulse.arrow.box
	readonly property real _k: Tokens.pulse.arrow.glyph / 24

	RectangularShadow {
		anchors.fill: disc
		radius: disc.radius
		blur: 8
		color: Qt.rgba(50 / 255, 215 / 255, 75 / 255, 0.25)
	}

	Rectangle {
		id: disc
		anchors.fill: parent
		radius: width / 2
		color: Qt.rgba(50 / 255, 215 / 255, 75 / 255, 0.15)
		border.width: 1
		border.color: Qt.rgba(50 / 255, 215 / 255, 75 / 255, 0.35)
	}

	Shape {
		anchors.centerIn: parent
		width: Tokens.pulse.arrow.glyph
		height: Tokens.pulse.arrow.glyph
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			fillColor: "transparent"
			strokeColor: Tokens.status.green
			strokeWidth: Tokens.pulse.arrow.stroke * root._k
			capStyle: ShapePath.RoundCap
			joinStyle: ShapePath.RoundJoin
			scale: Qt.size(root._k, root._k)
			PathSvg { path: "M12 4L12 16M18 10L12 16L6 10M6 20L18 20" }
		}
	}
}
```

- [ ] **Step 4: Write `PageDots.qml`**

```qml
import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens

// The workspace pulse's page dots: one per workspace on this monitor, the
// active one stretched into a pill that springs between positions.
Row {
	id: root
	objectName: "page-dots"

	property var ids: []
	property int active: 0
	property color color: "white"
	// Inside a PulseItem the dots are an effect's hidden source, so their own
	// `visible` is always false; the pulse says when they are on screen.
	property bool animate: true
	readonly property int count: dots.count

	spacing: Tokens.pulse.pageDot.gap

	Repeater {
		id: dots
		model: root.ids

		Rectangle {
			id: dot
			required property int modelData
			readonly property bool current: dot.modelData === root.active
			height: Tokens.pulse.pageDot.size
			width: widthSpring.value
			radius: height / 2
			color: root.color
			opacity: dot.current ? 1 : Tokens.pulse.pageDot.idleOpacity
			Behavior on opacity { NumberAnimation { duration: 200 } }

			Spring {
				id: widthSpring
				autoRun: root.animate
				stiffness: 500
				damping: 30
				target: dot.current ? Tokens.pulse.pageDot.activeWidth : Tokens.pulse.pageDot.size
			}
		}
	}
}
```

- [ ] **Step 5: Write `PulseItem.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens

// One AnimatePresence child of Bloom's pulse: enters from opacity 0, scale
// 0.95, blur 4 px; leaves to 0, 1.05, 4 px. framer gives these values no
// transition, so opacity and blur ease over 300 ms and scale is its 550/30
// spring. The blur pass only redraws while those change.
Item {
	id: root

	property bool present: false
	default property alias content: holder.data

	visible: root.opacity > 0
	opacity: root.present ? 1 : 0
	Behavior on opacity {
		NumberAnimation { duration: Tokens.pulse.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
	}

	property real blurPx: root.present ? 0 : Tokens.pulse.blur
	Behavior on blurPx {
		NumberAnimation { duration: Tokens.pulse.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
	}

	onPresentChanged: {
		// Each entry starts from framer's `initial`, whatever the last exit left.
		if (root.present)
			scaleSpring.jump(Tokens.pulse.enterScale);
	}

	Spring {
		id: scaleSpring
		// A running spring redraws the whole window every frame; a hidden
		// pulse's spring waits (each entry jumps it to the start anyway).
		autoRun: root.visible
		stiffness: 550
		damping: 30
		restSpeed: 10
		initial: Tokens.pulse.enterScale
		target: root.present ? 1 : Tokens.pulse.exitScale
	}

	Item {
		id: holder
		anchors.fill: parent
		visible: false
	}

	MultiEffect {
		anchors.fill: parent
		source: holder
		scale: scaleSpring.value
		blurEnabled: true
		blurMax: Tokens.pulse.blurMax
		blur: root.blurPx / Tokens.pulse.blurMax
	}
}
```

- [ ] **Step 6: Write `PulseView.qml`**

```qml
import QtQuick
import "../../common/tokens.js" as Tokens
import "pulses.js" as Pulses

// Bloom's pulse slot in the collapsed row (AnimatePresence mode="wait"): the
// view on screen leaves before the next one enters, 300 ms each way.
// `standardOpacity` is the normal row's share of the same swap.
Item {
	id: root

	property string kind: ""
	property var battery: ({ level: 0, charging: false, threshold: 20 })
	property bool updateAvailable: false
	property var workspace: null
	property color textColor: "white"

	readonly property string wantedKey: Pulses.viewKey(root.kind)
	readonly property string shownKey: root._shown
	property string _shown: ""
	property bool _leaving: false
	property real standardOpacity: root._shown === "" && !root._leaving ? 1 : 0
	Behavior on standardOpacity {
		NumberAnimation { duration: Tokens.pulse.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
	}

	function _advance() {
		if (root._leaving || root.wantedKey === root._shown)
			return;
		root._leaving = true;
		leave.restart();
	}
	onWantedKeyChanged: root._advance()

	Timer {
		id: leave
		interval: Tokens.pulse.fadeMs
		onTriggered: {
			root._shown = root.wantedKey;
			root._leaving = false;
			root._advance();
		}
	}

	component Label: Text {
		objectName: "pulse-label"
		font.family: Tokens.type.family
		font.pixelSize: Tokens.pulse.labelSize
		font.weight: Font.DemiBold
		color: root.textColor
		elide: Text.ElideRight
	}

	PulseItem {
		objectName: "pulse-battery"
		anchors.fill: parent
		present: root._shown === "battery" && !root._leaving

		Row {
			anchors.centerIn: parent
			spacing: Tokens.pulse.gap
			UpdateArrow {
				anchors.verticalCenter: parent.verticalCenter
				shown: root.updateAvailable
			}
			BatteryIcon {
				anchors.verticalCenter: parent.verticalCenter
				level: root.battery.level
				charging: root.battery.charging
				threshold: root.battery.threshold
				color: root.textColor
			}
			Label {
				anchors.verticalCenter: parent.verticalCenter
				text: Pulses.batteryLabel(root.kind === "low" ? "low" : "power", root.battery)
				color: root.kind === "low" ? Tokens.status.red : root.textColor
			}
		}
	}

	PulseItem {
		objectName: "pulse-update"
		anchors.fill: parent
		present: root._shown === "update" && !root._leaving

		Row {
			anchors.centerIn: parent
			spacing: Tokens.pulse.gap
			UpdateArrow { anchors.verticalCenter: parent.verticalCenter }
			Label {
				anchors.verticalCenter: parent.verticalCenter
				text: "Update Available"
				color: Tokens.status.green
			}
		}
	}

	PulseItem {
		id: workspaceItem
		objectName: "pulse-workspace"
		anchors.fill: parent
		present: root._shown === "workspace" && !root._leaving

		Row {
			anchors.centerIn: parent
			spacing: Tokens.pulse.gap
			PageDots {
				id: pageDots
				anchors.verticalCenter: parent.verticalCenter
				ids: root.workspace ? Pulses.pageDots(root.workspace) : []
				active: root.workspace?.id ?? 0
				color: root.textColor
				animate: workspaceItem.visible
				visible: count > 0
			}
			Label {
				anchors.verticalCenter: parent.verticalCenter
				// Long workspace names elide inside the 176 px row.
				width: Math.min(implicitWidth, root.width - (pageDots.count > 0 ? pageDots.width + Tokens.pulse.gap : 0))
				text: root.workspace ? Pulses.workspaceLabel(root.workspace) : ""
			}
		}
	}
}
```

Notes:
- `Tokens.status.green` / `.red` already exist (2A) as `#32D74B` / `#FF453A`; check with `grep -n "status" shell/common/tokens.js`.
- The battery label uses "low" only for the low pulse. During a workspace or update pulse the battery view isn't on screen, so its label doesn't matter.

- [ ] **Step 7: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_pulseview.qml 2>&1 | tail -3`
Expected: `Totals: 7 passed, 0 failed`.

- [ ] **Step 8: Commit**

```bash
git add shell/modules/notch/UpdateArrow.qml shell/modules/notch/PageDots.qml shell/modules/notch/PulseItem.qml shell/modules/notch/PulseView.qml tests/qml/tst_pulseview.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the pulse views

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Pulses in the notch

**Files:**
- Modify: `shell/modules/notch/NotchView.qml`
- Test: `tests/qml/tst_notchview.qml`

**Interfaces:**
- Consumes: `Pulses.*` (Task 2), `PulseView` (Task 4), `Music.contentWidth` with `pulse` (Task 2).
- Produces (NotchView):
  - New inputs:
    - `battery` gains `ready: bool`; the default object gets `ready: false`;
    - `property var updates: ({ available: false, count: 0 })`;
    - `property bool updateIndicator: true`;
    - `property var workspace: null` (`{ id, name, ids }`);
    - `property bool workspacePeekEnabled: true`;
    - `property var pulseMs: ({ power: Tokens.pulse.powerMs, low: Tokens.pulse.lowBatteryMs, update: Tokens.pulse.updateMs, workspace: Tokens.pulse.workspaceMs })` (tests shorten it).
  - New methods: `updatesArrived()`, which NotchWindow calls on `Updates.arrived`.
  - New outputs:
    - `readonly property string pulse`;
    - `signal updatesWanted(bool wanted)`;
    - `stateObject()` gains `pulse` and `updateDot`.
  - `peek(ms)` now extends (`Pulses.peekUntil`).

- [ ] **Step 1: Write the failing tests**

Add to `tests/qml/tst_notchview.qml`, inside the TestCase before `framesIn`. The default component's battery needs `ready`: change `viewComponent`'s battery to `({ available: true, ready: true, level: 80, charging: false, threshold: 20, tooltip: "80% remaining" })`.

```qml
		function fast(props) {
			const p = props || {};
			p.pulseMs = { power: 600, low: 600, update: 600, workspace: 600 };
			return make(p);
		}

		function bat(props) {
			const b = { available: true, ready: true, level: 80, charging: false, threshold: 20, tooltip: "" };
			for (const k in props) b[k] = props[k];
			return b;
		}

		function test_chargingPulse() {
			const v = fast();
			settle(v);
			v.battery = bat({ charging: true });
			compare(v.pulse, "power");
			compare(v.target.width, 200, "Bloom: pulses are 200 wide");
			tryCompare(v, "pulse", "", 1500);
			compare(v.target.width, 140);
		}

		// Review focus 1.
		function test_noPulseFromStartupValues() {
			const v = fast({ battery: bat({ ready: false, charging: false }), workspace: null });
			v.battery = bat({ ready: true, charging: true });
			v.workspace = { id: 2, name: "2", ids: [1, 2] };
			settle(v);
			compare(v.pulse, "", "UPower's first answer and the login workspace are not changes");
		}

		function test_lowBatteryAtLoginPulsesOnce() {
			const v = fast({ battery: bat({ level: 12 }) });
			v.ready = true;
			compare(v.pulse, "low", "Bloom pulses a low battery as soon as it is ready");
			tryCompare(v, "pulse", "", 1500);
			v.battery = bat({ level: 11 });
			compare(v.pulse, "", "once per crossing");
			v.battery = bat({ level: 30, charging: true });
			v.battery = bat({ level: 19, charging: false });
			compare(v.pulse, "low", "re-armed after charging");
		}

		function test_noBatteryNoPulse() {
			const v = fast({ battery: bat({ available: false, level: 0 }) });
			settle(v);
			v.battery = bat({ available: false, level: 0, charging: true });
			compare(v.pulse, "", "a desktop has no battery pulses");
		}

		function test_updatePulseAndDot() {
			const v = fast();
			settle(v);
			const dot = findChild(v, "update-dot");
			verify(!dot.visible);
			v.updates = { available: true, count: 3 };
			v.updatesArrived();
			compare(v.pulse, "update");
			verify(dot.visible, "the dot stays while updates are pending");
			tryCompare(v, "pulse", "", 1500);
			verify(dot.visible);
			v.updateIndicator = false;
			verify(!dot.visible, "bloom-show-update-indicator off");
		}

		function test_workspacePulse() {
			const v = fast({ workspace: { id: 1, name: "1", ids: [1, 2] } });
			settle(v);
			v.workspace = { id: 2, name: "2", ids: [1, 2] };
			compare(v.pulse, "workspace");
			tryCompare(v, "pulse", "", 1500);
			v.workspacePeekEnabled = false;
			v.workspace = { id: 1, name: "1", ids: [1, 2] };
			compare(v.pulse, "", "turned off");
		}

		// Review focus 3.
		function test_rapidWorkspaceSwitchesShowOnePulse() {
			const v = fast({ mode: "peek", workspace: { id: 1, name: "1", ids: [1, 2, 3] } });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.workspace = { id: 2, name: "2", ids: [1, 2, 3] };
			wait(300);
			v.workspace = { id: 3, name: "3", ids: [1, 2, 3] };
			compare(v.pulse, "workspace");
			verify(!v.hidden, "peek mode shows it");
			wait(450);
			verify(!v.hidden && v.pulse === "workspace", "timed from the last switch, not the first");
			tryCompare(v, "hidden", true, 1500);
		}

		function test_shortPeekKeepsALongerOne() {
			const v = make({ mode: "peek", pulseMs: { power: 600, low: 600, update: 1500, workspace: 300 }, workspace: { id: 1, name: "1", ids: [1, 2] } });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.updates = { available: true, count: 1 };
			v.updatesArrived();
			v.workspace = { id: 2, name: "2", ids: [1, 2] };
			wait(700);
			verify(!v.hidden, "the update peek still runs");
			compare(v.pulse, "update", "back to the update pulse after the workspace one");
		}

		// Review focus 2.
		function test_hoverHidesAPulse() {
			const v = make({ pulseMs: { power: 2000, low: 600, update: 600, workspace: 600 } });
			settle(v);
			v.battery = bat({ charging: true });
			compare(v.pulse, "power");
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(v.pulse, "", "the status strip takes the pill");
			compare(v.target.width, 300);
			mouseMove(v, 500, 300);
			tryCompare(v, "pulse", "power", 500);
			tryCompare(v, "pulse", "", 2500);
		}

		function test_pulseHoldsWhileMusicIsCollapsed() {
			const v = fast({ media: playing() });
			settle(v);
			v.battery = bat({ charging: true });
			compare(v.target.width, 200, "pulses win over the collapsed music width");
		}

		function test_stateObjectShowsPulses() {
			const v = fast();
			settle(v);
			v.updates = { available: true, count: 1 };
			v.updatesArrived();
			const s = v.stateObject();
			compare(s.pulse, "update");
			compare(s.updateDot, true);
		}

		function test_updatesWanted() {
			const v = make();
			const s = spy(v, "updatesWanted");
			v.updateIndicator = false;
			compare(s.signalArguments[s.count - 1][0], false);
			v.updateIndicator = true;
			compare(s.signalArguments[s.count - 1][0], true);
		}
```

Add next to the frame-count tests:

```qml
		function test_settledPulseDrawsNoFrames() {
			const v = make({ pulseMs: { power: 5000, low: 600, update: 600, workspace: 600 } });
			settle(v);
			v.battery = bat({ charging: true });
			wait(1200);
			compare(framesIn(1000), 0, "a pulse at rest is static");
		}
```

`playing()` and `spy()` already exist in this file (2B).

- [ ] **Step 2: Run them to verify they fail**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_notchview.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: the new tests FAIL (`pulse` is undefined, there is no `update-dot`, and so on). The 2A/2B tests still pass.

- [ ] **Step 3: Implement**

In `shell/modules/notch/NotchView.qml`:

1. Imports: add `import "pulses.js" as Pulses`.
2. Inputs, after `property var battery`. Change the battery default to include `ready: false`, then add:

```qml
	property var updates: ({ available: false, count: 0 })
	property bool updateIndicator: true
	property var workspace: null
	property bool workspacePeekEnabled: true
	property var pulseMs: ({ power: Tokens.pulse.powerMs, low: Tokens.pulse.lowBatteryMs, update: Tokens.pulse.updateMs, workspace: Tokens.pulse.workspaceMs })
	signal updatesWanted(bool wanted)
```

3. Pulse state, after the music activity block:

```qml
	// Pulses (Bloom App.tsx; the workspace pulse is D7). Each kind has its own
	// timer; `pulse` is the one on screen.
	property bool _powerPulse: false
	property bool _lowPulse: false
	property bool _updatePulse: false
	property bool _workspacePulse: false
	readonly property string pulse: Pulses.activePulse({
		workspace: root._workspacePulse, update: root._updatePulse, low: root._lowPulse, power: root._powerPulse,
		hovered: root.pillHovered, open: root.open
	})

	function _fire(kind) {
		const ms = root.pulseMs[kind];
		if (kind === "power") { root._powerPulse = true; powerTimer.interval = ms; powerTimer.restart(); }
		else if (kind === "low") { root._lowPulse = true; lowTimer.interval = ms; lowTimer.restart(); }
		else if (kind === "update") { root._updatePulse = true; updateTimer.interval = ms; updateTimer.restart(); }
		else { root._workspacePulse = true; workspaceTimer.interval = ms; workspaceTimer.restart(); }
		if (root.mode === "peek")
			root.peek(ms);
	}

	Timer { id: powerTimer; onTriggered: root._powerPulse = false }
	Timer { id: lowTimer; onTriggered: root._lowPulse = false }
	Timer { id: updateTimer; onTriggered: root._updatePulse = false }
	Timer { id: workspaceTimer; onTriggered: root._workspacePulse = false }

	// The battery as UPower first reports it is not a change; Bloom started
	// watching once it was ready.
	property var _lastCharging: null
	property bool _lowArmed: true
	function _batteryCheck() {
		const b = root.battery;
		if (!root.ready || !b.available || !b.ready)
			return;
		if (Pulses.powerPulse(root._lastCharging, b.charging))
			root._fire("power");
		root._lastCharging = b.charging;
		const low = Pulses.lowBatteryStep(root._lowArmed, b);
		root._lowArmed = low.armed;
		if (low.fire)
			root._fire("low");
	}
	onBatteryChanged: root._batteryCheck()

	function updatesArrived() {
		if (root.updateIndicator && root.ready)
			root._fire("update");
	}
	onUpdatesChanged: if (!root.updates.available) { root._updatePulse = false; updateTimer.stop(); }
	onUpdateIndicatorChanged: {
		root.updatesWanted(root.updateIndicator);
		if (!root.updateIndicator) { root._updatePulse = false; updateTimer.stop(); }
	}

	// The workspace at login is seeded, not announced.
	property var _lastWorkspace: null
	onWorkspaceChanged: {
		const id = root.workspace ? root.workspace.id : null;
		if (root.ready && root.workspacePeekEnabled && Pulses.workspacePulse(root._lastWorkspace, id))
			root._fire("workspace");
		if (id !== null)
			root._lastWorkspace = id;
	}
```

4. In the existing `onReadyChanged` handler, after its `return` guard, add `root._batteryCheck();`. This is Bloom's `isReady` gate: a low battery present at login pulses once the drop-in starts. In the existing `Component.onCompleted`, add `root.updatesWanted(root.updateIndicator);`, and add `root._lastWorkspace = root.workspace ? root.workspace.id : null;`.
5. `peek(ms)` extends:

```qml
	property real _peekUntil: 0
	function peek(ms) {
		root._peekUntil = Pulses.peekUntil(Date.now(), root._peekUntil, ms);
		root.eventPeek = true;
		peekTimer.interval = Math.max(1, root._peekUntil - Date.now());
		peekTimer.restart();
	}
```

6. Width: in `target`'s `Music.contentWidth({...})` object, add `pulse: root.pulse`.
7. The row:
   - Wrap the existing `leftGroup`, `clock`, `rightGroup`, collapsed `Visualizer` and `artSlot` in a new `Item { id: standardRow; anchors.fill: parent; opacity: pulseView.standardOpacity }`. Their anchors stay as they are, relative to `parent`.
   - After it, still inside `mainRow`, add:

```qml
				PulseView {
					id: pulseView
					anchors.fill: parent
					kind: root.pulse
					battery: root.battery
					updateAvailable: root.updates.available && root.updateIndicator
					workspace: root.workspace
					textColor: root.textColor
				}

				// Bloom's update dot: centred under the clock's 24 px box (top: 100%,
				// margin-top: -4px), in status and collapsed music alike.
				Rectangle {
					objectName: "update-dot"
					visible: root.updates.available && root.updateIndicator
					x: clock.x + clock.width / 2 - width / 2
					y: Tokens.pulse.dot.top
					width: Tokens.pulse.dot.size
					height: width
					radius: width / 2
					color: Tokens.status.green
					opacity: standardRow.opacity
				}
```

8. In `stateObject()`, add `pulse: root.pulse, updateDot: root.updates.available && root.updateIndicator`.

If `mainRow`'s `clip: true` cuts the dot (row height 36, dot ends at 31), it doesn't, so leave it.

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | tail -3`
Expected: `Totals: N passed, 0 failed`, including all 2A/2B notch tests and `test_idleNotchDrawsNoFrames`.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/notch/NotchView.qml tests/qml/tst_notchview.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: show charging, battery, update and workspace pulses in the notch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Wiring and the end-to-end check

**Files:**
- Create: `shell/modules/notch/WorkspaceData.qml`
- Modify: `shell/services/Battery.qml` (+ `ready`), `shell/modules/notch/NotchWindow.qml`
- Modify: `tests/integration/lib.sh` (`wait_for` limit)
- Test: `tests/integration/test_notch.sh`

**Interfaces:**
- Consumes: `Updates` (Task 3), the NotchView inputs (Task 5).
- Produces: `WorkspaceData { property var screen; readonly property var workspace }`, which is `null` or `{ id, name, ids }`.

- [ ] **Step 1: Write the failing integration check**

In `tests/integration/test_notch.sh`, make these edits:

1. Before `start_shell`, add a fake `checkupdates` that reports two updates:

```bash
mkdir -p "$TEST_TMP/bin"
cp "$ROOT/tests/integration/updates-fake.sh" "$TEST_TMP/bin/checkupdates"
chmod +x "$TEST_TMP/bin/checkupdates"
export BLOOM_CHECKUPDATES="$TEST_TMP/bin/checkupdates" BLOOM_FAKE_UPDATES="$TEST_TMP/fake"
printf '0\nfuzzel 1 -> 2\njdk 1 -> 2\n' >"$BLOOM_FAKE_UPDATES"
```

2. After the "notch surface loads and settles" pass, add:

```bash
ipc updates check >/dev/null
wait_for "the update pulse" state_is "pulse,updateDot,width" '{"pulse":"update","updateDot":true,"width":200}'
WAIT_S=10 wait_for "the 6 s pulse to end" state_is "pulse,updateDot,width" '{"pulse":"","updateDot":true,"width":140}'
pass "new updates pulse, then leave the dot"
```

3. In `tests/integration/lib.sh`, `wait_for` takes its limit from `WAIT_S` (default 6), because the update pulse alone lasts 6 s:

```bash
# wait_for <description> <command...>: retries the command for up to
# $WAIT_S seconds (default 6).
wait_for() {
	local what="$1"
	shift
	for _ in $(seq 1 $(( ${WAIT_S:-6} * 10 ))); do
		if "$@" >/dev/null 2>&1; then return 0; fi
		sleep 0.1
	done
	fail "timed out waiting for: $what"
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/integration/test_notch.sh`
Expected: FAIL at "the update pulse" (`pulse` is null: NotchWindow isn't wired).

- [ ] **Step 3: Write `WorkspaceData.qml`**

```qml
import QtQuick
import Quickshell.Hyprland

// This screen's Hyprland workspace for the workspace pulse, in its own file
// so the Hyprland module is only touched under Hyprland (as HyprEvents.qml).
Item {
	id: root

	// Set by NotchWindow on load (a required property can't be met by a plain `source`).
	property var screen: null
	readonly property var monitor: root.screen ? Hyprland.monitorFor(root.screen) : null
	readonly property var workspace: {
		const ws = root.monitor?.activeWorkspace;
		if (!ws || ws.id <= 0)
			return null;
		const ids = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).map(w => w.id);
		if (ids.indexOf(ws.id) < 0)
			ids.push(ws.id);
		return { id: ws.id, name: ws.name, ids: ids };
	}
}
```

- [ ] **Step 4: Add `Battery.ready`**

In `shell/services/Battery.qml`, after `available`:

```qml
	// UPower has answered for this device (its first values are placeholders).
	readonly property bool ready: root.device?.ready ?? false
```

- [ ] **Step 5: Wire NotchWindow**

In `shell/modules/notch/NotchWindow.qml`:

1. After the `audio` Loader:

```qml
	readonly property bool _workspaceOn: HyprState.available && Settings.values["bloom-workspace-peek-enabled"]

	Loader {
		id: workspaces
		active: win._workspaceOn
		source: "WorkspaceData.qml"
		onLoaded: workspaces.item.screen = win.modelData
	}

	Connections {
		target: Updates
		function onArrived() { view.updatesArrived(); }
	}
```

2. In the `NotchView` block:
   - `battery:` gains `ready: Battery.ready`, so it reads `({ available: Battery.available, ready: Battery.ready, level: …, tooltip: Battery.tooltip })`.
   - Add:

```qml
		updates: ({ available: Updates.available, count: Updates.count })
		updateIndicator: Settings.values["bloom-show-update-indicator"]
		onUpdatesWanted: wanted => Updates.hold(win._key, wanted)
		workspace: workspaces.item?.workspace ?? null
		workspacePeekEnabled: Settings.values["bloom-workspace-peek-enabled"]
```

3. In `Component.onDestruction`, add `Updates.hold(win._key, false);`.

- [ ] **Step 6: Run everything**

Run: `bash tests/integration/test_notch.sh && tests/run-all.sh 2>&1 | tail -5`
Expected: `ok - new updates pulse, then leave the dot`, no shell warnings on sway, and `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add shell/modules/notch/WorkspaceData.qml shell/services/Battery.qml shell/modules/notch/NotchWindow.qml tests/integration/lib.sh tests/integration/test_notch.sh
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: wire pulses to UPower, pacman updates and Hyprland workspaces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Owner verification on the real session

Run only after the owner approves. It touches the running shell, not `~/.config`.

- [ ] **Step 1:** `systemctl --user restart bloom-shell`, then `bloom ipc shell ping` returns `pong`.
- [ ] **Step 2: Workspace.** The owner switches workspace with Super+2, then Super+1. Expected:
  - a 200 px pill with page dots and "Workspace 2", then "Workspace 1";
  - the swap fades through, with no jump;
  - after 2 s it is back to the clock.

  Then in peek mode (`bloom ipc settings set bloom-notch-mode peek`), the same switch reveals the notch for 2 s. Return to fixed afterwards.
- [ ] **Step 3: Charging.** The owner unplugs and replugs the charger. Expected: "On Battery • N%", then "Charging • N%", 4 s each, with the battery glyph.
- [ ] **Step 4: Updates.** `bloom ipc updates check`. Expected: with pending updates (7 today), "Update Available" in green for 6 s, then the green dot under the clock. `bloom ipc updates state` shows the count.
- [ ] **Step 5: Low battery** (optional; needs the battery near the threshold): `bloom ipc settings set bloom-low-battery-threshold 50` while on battery below 50 %. Expected: a red "Low Battery • N%" once. Reset with `bloom ipc settings set bloom-low-battery-threshold 20`.
- [ ] **Step 6: Still pending from 2B**, checked here with music playing:
  - in peek mode, a track change shows the notch for 3 s;
  - a fullscreen video hides the notch;
  - the collapsed visualizer is smooth.
- [ ] **Step 7:** Record the owner's verdict in the ledger. Any finding becomes a fix with a test, before the merge.
