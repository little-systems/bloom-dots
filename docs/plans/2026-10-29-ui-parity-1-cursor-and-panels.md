# UI Parity 1: Cursor Behaviour and the Notch Panels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the notch panels from Phase 5 and the cursor behaviour of every surface match Windows Bloom 1:1. The owner reported both (2026-10-29: "phase 5 is not up to Bloom standards", "even the cursor behaviour is wrong").

**Architecture:**
- **Bloom's CSS becomes tokens:** `Tokens.qp`, `.cc`, `.calendar`, `.timer`, `.shelf`, `.alert`, one entry per CSS rule, each with its selector in a comment.
- **Panels are rewritten in the codebase's normal QML style:** one property per line, no hard-coded `y:` stacks. Layout comes from Bloom's flex and grid rules, with `Column`/`Row`/`Grid` and the token gaps.
- **Shared parts** (`QpHeader`, `QpSwitch`, `QpRow`, `QpButton`, `QpChip`, `QpFooter`, `PointerArea`) replace the ad-hoc copies in each panel.
- **One cursor rule:** every clickable sets Bloom's cursor, and a test helper walks each surface to prove it.

**Tech Stack:** Quickshell 0.3.2, Qt 6.12 Quick/QtTest. No new services.

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md` §4.1 (Notch: Command Center, Calendar + Pomodoro + Todo, Shelf, Wi-Fi/BT/Devices, device alerts) and Appendix A. The reference is Bloom @ `b5fb962`: `src/App.tsx`, `src/App.css`, `src/components/{WifiPanel,BluetoothPanel,ConnectedDevicesPanel}.tsx`, `src/components/QuickPanel.css`, `src/devices/*`.

## Owner decisions (2026-10-29)

1. **Command Center round buttons:** Bloom's six, in Bloom's order and icons:
   - DND toggles Bloom's notification DND;
   - Energy Saver toggles power-profiles power-saver;
   - System Tray reveals the dock;
   - Notification Center opens the history panel;
   - Bloom Settings opens `~/.config/bloom/settings.json` until Phase 7;
   - Restart Bloom.

   Idle and Night light leave the Command Center for now. Their services stay, reachable over IPC.
2. **Footers:** "More Wi-Fi settings" and "More Bluetooth settings" open `nm-connection-editor` / `blueman-manager` (or `systemsettings kcm_bluetooth`) when installed, and are hidden when not.
3. **Tasks (todo) is removed:** "if the OG bloom has tasks then keep it as toggle or remove it", and Bloom has none. The notch calendar is Bloom's calendar and timer only. The todo service and its IPC are removed with it. The spec's D9 "todo as a notch tab" is withdrawn.

## Global Constraints

- **Source of truth:** Bloom's CSS values, copied as tokens with the CSS selector in a comment. If a value isn't in Bloom, the plan says where it comes from.
- **Fonts:** Inter (D10).
  - `font-weight: 600` is `Font.DemiBold`, 500 is `Font.Medium`, 700 is `Font.Bold`.
  - CSS `opacity` on text is element `opacity`, not a colour alpha, so it multiplies with hover changes as in Bloom.
- **Cursors (Bloom's CSS map):**
  - `pointer` on every clickable;
  - `text` on editable text (`.timer-clock`, `.timer-edit-input`, inputs);
  - `default` on the notch body (`.bloom`) and disabled controls (`:disabled → default`).
- **Motion:**
  - CSS `transition: X Ns ease` uses `[0.25, 0.1, 0.25, 1]`;
  - `cubic-bezier(a,b,c,d)` is used as written;
  - framer duration-only transitions use easeOut `[0, 0, 0.58, 1]`;
  - framer `[0.22, 1, 0.36, 1]` (RollDigit) as written;
  - hover lifts such as `translateY(-0.5px)` and press scales such as `scale(0.98)` are kept.
- **Perf:** no animation runs at rest; frame-count tests cover every panel.
- **Tests:** never touch the live session (the existing hermetic rules).
- **Live tree:** keep every save loadable, merge with `git fetch . <branch>:main && git switch main`, and never edit `~/.config` without the owner's OK.
- **Commits:** conventional commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, authored with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit …`.
- **Style:** one property per line, tabs; comments say why. Codex's one-line style in the Phase 5 files goes.

## Review Focus

1. **Hover and press feedback on every clickable:** the cursor changes, and the hover background or colour appears (Bloom has one on every control). Nothing is clickable without both.
2. **Long names:**
   - Wi-Fi SSIDs and Bluetooth device names elide in their rows;
   - the Command Center's network name elides in a 7.5 px status line;
   - shelf file names elide.
3. **Timer edits:** typing digits, Enter, Escape and blur commit or cancel as in Bloom. An invalid entry turns the digits red. The digits roll when the value changes and don't roll at rest.
4. **Empty and disabled states:**
   - Wi-Fi or Bluetooth off: "Wi-Fi is off" / "Bluetooth is off";
   - no devices: the empty state;
   - an empty shelf: the dashed drop target;
   - the timer's reset button disabled at 0 (opacity 0.08, default cursor).
5. **Light theme:** every hover and active colour follows Bloom's `var(--bloom-…)` fallbacks through `Theme`, not hard-coded white.

---

## Bloom reference values (copied from the CSS; the tokens are these exact numbers)

**Panel content box** (`.command-center-content-minimal`, `.qp`, `.shelf-content`): top 36 (under the clock strip), bottom radius 18.
- **Padding:**
  - Command Center 12/14;
  - quick panels 4 12 8, gap 6, base text 11 px;
  - shelf 12 14;
  - calendar split view 16 all round, gap 16, plus a 1 px top margin; its bottom radius is 28.

**Calendar** (`.calendar-*`):
- **Columns:** calendar column flex 1.2, timer column flex 1. The timer column has a 1 px left border in `border`, 16 px left padding, and its content centred.
- **Header:** month and year 13/600 at opacity 0.9, line-height 1.3, 8 px below.
- **Grid:** 7 equal columns, gap 2.
- **Weekday names:** 9/600 at opacity 0.4, 2 px bottom padding.
- **Days:** square cells (aspect ratio 1), 10 px, radius 4. Today: a `text` background with `bgExpanded` text at 600.

**Timer** (`.timer-*`, `.roll-*`):
- **Section:** column, gap 18, centred.
- **Main block:** column, gap 4.
- **Status line:** 14 px tall, 10/500, tracking 0.2, opacity 0.4 (0.9 when finished).
  - Texts: "Set duration", "Time's up", "Paused · ends h:mm", "ends h:mm", "Click to edit".
- **Clock:** digits gap 5, `text` cursor.
  - Each digit: a 34×58 box, clipped; the number is 36/600 with tracking −0.5.
  - Compact when minutes have more than 2 digits: 26×46 at 28 px.
  - Colon: 32/600 at opacity 0.3, 2 px horizontal padding.
- **RollDigit motion** on change: enter from y 72% with rotateX −50 and opacity 0; leave to y −72% with rotateX 50; 0.4 s ease `[0.22, 1, 0.36, 1]`.
- **Edit underline:** 2 px, radius 2, in the current colour. While editing it grows to 74% width at opacity 0.3 over 0.25 s ease.
- **Controls row:** gap 8 = 32 px spacer, play button, reset button.
  - **Play:** fills the row, 44 tall, radius 22, `text` background with `bgExpanded` text, 12/600, icon gap 7, 14 px icon. Hover opacity 0.9; press scale 0.97 over 0.15 s ease.
  - **Reset:** 32×32 circle, transparent, opacity 0.35 (hover 0.8, disabled 0.08), press scale 0.9; 14 px icon, stroke 2.5.
- **Presets:** 4 columns, gap 4. Each: 6 px vertical padding, radius 7, 10/600, opacity 0.5 (hover 1). Active: `border` background at opacity 1.
- **States:** paused colour `textMuted`; finished `#ff453a`, with the clock pulsing (`timer-clock-pulse` 1.9 s ease-in-out, 0.65 s delay, repeating).

**Command Center** (`.cc-*`):
- **Layout:** column, `space-between`.
- **Tiles:** 2 columns, gap 10, grid height 78.
  - **Tile:** 34 tall, padding 5×8, gap 8, radius 10, `groupBg` with a 1 px `border`. Hover: `border` background and translateY −0.5. Press: scale 0.98 over 0.15 s `cubic-bezier(0.16, 1, 0.3, 1)`.
  - **Icon circle:** 20 px, `groupBg`, 12 px icon.
  - **Title:** 9/600 in `text`. **Status:** 7.5/500 in `textMuted`, elided. Line-height 1.15.
  - **Active tile:** `text` background and border; title in `bgExpanded`; status `bgExpanded` at 0.5; icon circle in `bgExpanded`.
  - **Chevron button:** 18×18, radius 6, opacity 0.55 (hover 1 with a `groupBg` background), 12 px glyph.
- **Round buttons:** a row with `space-between` and 4 px side padding.
  - **Button:** 32×32 circle, `groupBg`, 1 px `border`, `textMuted` icon.
  - Hover: `border` background, `text` icon, translateY −1. Press: scale 0.95. Transition 0.2 s `cubic-bezier(0.16, 1, 0.3, 1)`.
  - **Active:** `text` background with `bgExpanded` icon and shadow `0 2px 8px border`.
- **Sliders:** gap 8. Each row is 18 tall with gap 10.
  - **Label:** 75 wide, gap 6, 9/600 in `textMuted`; icon 12 px at 0.7.
  - **Track:** 6 tall, radius 3, `groupBg` (hover `border`).
  - **Fill:** `text`, radius 3 (hover: shadow `0 0 4px border`).
  - **Percentage:** 28 wide, right-aligned, 9/600 in `textMuted` (hover `text`), tabular figures.

**Quick panels** (`.qp-*`):
- **Header:** gap 4. Title 12/600 fills the row.
- **Icon button:** 24×24, radius 8, `textMuted` (hover `groupBg` background with `text` colour; disabled opacity 0.4), 14 px glyph.
- **Switch:** 30×17, radius 9, `groupBg` (on: `text`). Knob 13 px at 2/2, `textMuted` (on: `bgExpanded`, x + 13), 0.2 s `cubic-bezier(0.16, 1, 0.3, 1)`.
- **List:** gap 2, a 4 px themed scrollbar, 2 px right padding.
- **Rows:**
  - **Row:** radius 10; expanded and hover background `groupBg`.
  - **Main line:** padding 5×8, gap 9.
  - **Icon:** a 24 px circle in `groupBg` with a 13 px glyph; active rows use `text` with a `bgExpanded` glyph.
  - **Text:** name at 600 (11 px base), elided; subline 9.5 px `textMuted`; line-height 1.25.
  - **Badge:** 11 px in `textMuted` at 0.45.
- **Row actions:** column, gap 6, padding 0 8 8 41.
- **Button:** min-width 64, height 24, padding 0 10, radius 8, 1 px `border`, `groupBg`, 10.5/600, 13 px icons.
  - Hover: `border` background. Primary: `text` with `bgExpanded` text (hover opacity 0.9). Disabled: opacity 0.45.
- **Input:** 26 tall, padding 0 9, radius 8, 1 px `border` (focus `textMuted`), `groupBg`.
- **Chips:** 20 tall, padding 0 8, radius 10, 1 px `border`, `textMuted`, 10/600. On: `text` with `bgExpanded` text.
- **Note:** 10 px `textMuted`. **Error:** `#ff8a80`, 10 px, padding 0 8 7 41.
- **Empty state:** centred, gap 8, padding 0 24, `textMuted`, 18 px icon.
- **Footer:** centred, padding 2×8, radius 6, 10 px `textMuted` (hover `text`).
- **Spinner:** 0.9 s linear.
- **Wi-Fi header:** back, title "Wi-Fi", **refresh** (RefreshCw, spinning while scanning), switch. Footer: "More Wi-Fi settings".
  - Row subline: Connecting… / Connected / Saved / Open / Secured. Lock badge on secured networks.
  - Actions: password input when needed, then Connect (primary) or Disconnect, plus Forget when saved.
- **Bluetooth header:** back, title "Bluetooth" (or "Add a device"), add (Plus), switch. Footer: "More Bluetooth settings".
  - Action: "Connects on its own when it's turned on and in range."; Connect (primary) or Disconnect; Remove.
  - Pairing prompts (PIN) appear when the backend supports them; until then the "Add a device" flow says what's missing, as `docs/ui-parity.md` records.

**Devices — Bloom's "battery hub"** (`.bh-*`):
- **Header:** a 22 px icon circle, title "Connected devices".
- **Groups:** gap 8. Titles 9.5/600, tracking 0.04 em, uppercase, `textMuted`, padding 0 8; the "low" group title is `#ff453a`.
- **Rows:** padding 4×8, gap 9, radius 10, hover `groupBg`.
- **Art:** 30×30; non-device icons 18 px.
- **Meters:** gap 8. Each meter is 40 wide, right-aligned, gap 3.
  - Value 10.5/600 with tabular figures; label 9 px `textMuted`; a 9 px charging bolt in `#32d74b`.
  - Bar: 3 tall, radius 2, `rgba(255,255,255,.14)`; fill `#32d74b` (low: `#ff453a`, and the value turns red too), 0.4 s ease.
- **Unknown battery:** "No battery info", 9.5 px `textMuted`.

**Shelf** (`.shelf-*`):
- **Empty:** the drop target fills the panel, 12 px at opacity 0.55, 1 px dashed white at 0.25, radius 12.
- **Grid:** a horizontal row, gap 8, scrolls; 5 px scrollbar.
- **Tile:** 104 wide, padding 6, gap 4, radius 12, white 0.06 background (hover 0.12), pointer cursor.
  - **Preview:** 84 tall, radius 8, white 0.05, opacity 0.85. Text tiles: 0.075 with an inset 2 px left line at 0.16; text 10 px, line-height 1.45, fading out at 72%.
  - **Name:** 11 px at 0.85, elided.
  - **Remove button:** 18 px circle at top 4 / right 4, black 0.55, shown on tile hover (0.12 s).
- **Notice:** a pill 10 px from the bottom, black 0.75, 11 px.

**Panel arrows** (`.panel-arrow`): 18 px circles beside the clock, 4 px outside it, `textMuted` (hover `text`, 0.15 s), pointer cursor.

**Device alert** (`.device-alert`):
- **Layout:** fills the pill, padding 0 18 0 14, gap 12, pointer cursor.
- **Text:** name 13.5/600, elided; status 12 px `textMuted`.
- **Battery ring:** 28 px, stroke 2.6. Track white 0.14; level `#32d74b` (low `#ff453a`), round caps, 0.6 s. Value 9.5/600.
- **Buds:** gap 7; each bud's label 9/600 `textMuted`.

---

## File map

| File | Responsibility |
|---|---|
| `shell/common/tokens.js` | + `qp`, `cc`, `calendar`, `timer`, `shelf`, `alert`, `panelArrow`, `cursor` |
| `shell/common/PointerArea.qml` | Tap plus hover with Bloom's cursor and a `hovered` state; `PressArea` gains the cursor |
| `shell/modules/notch/qp/QpHeader.qml`, `QpSwitch.qml`, `QpRow.qml`, `QpButton.qml`, `QpChip.qml`, `QpInput.qml`, `QpFooter.qml`, `QpEmpty.qml` | Bloom's quick-panel parts |
| `shell/modules/notch/RollDigit.qml` | Bloom's rolling timer digit |
| `shell/modules/notch/CalendarPanel.qml`, `CommandCenter.qml`, `ControlTile.qml`, `WifiPanel.qml`, `BluetoothPanel.qml`, `ConnectedDevicesPanel.qml`, `ShelfPanel.qml`, `BatteryRing.qml` | Rewritten to the reference |
| `shell/modules/notch/NotchView.qml`, `PanelHost.qml` | Panel arrows, device alert, `default` cursor on the body |
| `shell/modules/dock/*.qml`, `shell/modules/notifications/*.qml`, `shell/modules/osd/*.qml` | Cursor fixes only (their visuals are groups 2–3) |
| `tests/qml/cursors.js` | Walks an item tree and lists clickables without Bloom's cursor |
| `tests/qml/tst_cursors.qml`, `tst_qp.qml`, `tst_rolldigit.qml`, `tst_panels.qml`, `tst_calendar.qml`, `tst_shelf.qml`, `tst_devices.qml` | Tests |

## Verified facts (2026-10-29)

- **Live screenshots** of all six panels (owner session, `bloom ipc notch openPanel <name>`) show these differences from the reference:
  - **Calendar:** cells too large and the wrong weekday opacity; plain 36 px timer text instead of RollDigits; presets don't follow `.timer-preset-segment`.
  - **Command Center:** a different set of round buttons.
  - **Wi-Fi:** a search icon instead of refresh, and no footer.
  - **Devices:** not the battery-hub groups and meters.
  - **Shelf:** the empty state is close, but tiles are unverified.
- **Cursor audit:** 11 QML files have clickable handlers with no `cursorShape`, including all of the dock, the notification cards, the window previews, the workspace segment and the player buttons (`PressArea`). Bloom sets `cursor: pointer` on all of these (the CSS map in Global Constraints).
- **QML facts:** `HoverHandler.cursorShape` and `MouseArea.cursorShape` set the Wayland cursor shape (Qt 6.12); `TapHandler` sets none.

---

### Task 1: Cursor rule and its test

**Files:**
- Create: `shell/common/PointerArea.qml`, `tests/qml/cursors.js`, `tests/qml/tst_cursors.qml`
- Modify: `shell/common/tokens.js` (`cursor`), `shell/modules/notch/PressArea.qml`, and every file in the cursor audit

**Interfaces:**
- Produces:
  - `PointerArea { signal clicked(); signal rightClicked(); readonly property bool hovered; readonly property bool pressed; property bool enabled; property int cursor: Qt.PointingHandCursor }`;
  - `Cursors.missing(root)` → string[], the object paths of clickables without a pointer cursor.

- [ ] **Step 1: Write the failing test**

`tests/qml/cursors.js`:

```js
.pragma library

// Clickables without Bloom's pointer cursor. A clickable is an enabled
// TapHandler or a MouseArea with acceptedButtons; it is covered when the same
// item has a HoverHandler or MouseArea whose cursorShape is not ArrowCursor.
function _handlers(item) {
	const out = [];
	for (let i = 0; i < item.data.length; i++)
		out.push(item.data[i]);
	return out;
}

function _isTap(h) {
	return (h.toString().indexOf("TapHandler") === 0 && h.enabled)
		|| (h.toString().indexOf("QQuickMouseArea") === 0 && h.enabled && h.acceptedButtons !== 0);
}

function _covers(h) {
	return (h.toString().indexOf("HoverHandler") === 0 || h.toString().indexOf("QQuickMouseArea") === 0)
		&& h.cursorShape !== undefined && h.cursorShape !== 0;
}

function missing(root) {
	const bad = [];
	const walk = (item, path) => {
		if (!item || !item.visible)
			return;
		const hs = _handlers(item);
		if (hs.some(_isTap) && !hs.some(_covers))
			bad.push(path + "/" + (item.objectName || item.toString()));
		for (let i = 0; i < item.children.length; i++)
			walk(item.children[i], path + "/" + (item.objectName || i));
	};
	walk(root, "");
	return bad;
}
```

`tests/qml/tst_cursors.qml` instantiates each surface the way its own tests do: NotchView open on each panel, DockView expanded with items, DockMenu open, AddAppPopup open, NotificationCards with two cards, OSD. It asserts `compare(Cursors.missing(view), [], "every clickable shows Bloom's pointer")`.

- [ ] **Step 2: Run it to verify it fails**, listing today's offenders (expected: the dock, menus, cards, previews, segment, player buttons).

- [ ] **Step 3: Implement**
  - `PressArea` and `PointerArea` add `HoverHandler { cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }`.
  - Each offender gets a `HoverHandler { cursorShape: Qt.PointingHandCursor }` beside its handler, or switches to `PointerArea`.
  - The timer clock uses `Qt.IBeamCursor`.
  - The notch body gets `Qt.ArrowCursor` explicitly (Bloom `.bloom { cursor: default }`), so a pointer from a child never sticks.

- [ ] **Step 4: Run the test and the suite.** Expected: `missing` is `[]` for every surface; `CI=true tests/run-all.sh` passes.

- [ ] **Step 5: Commit** `fix: show Bloom's pointer and text cursors on every control`.

### Task 2: Tokens and quick-panel parts

**Files:**
- Create: `shell/modules/notch/qp/*.qml`, `tests/qml/tst_qp.qml`
- Modify: `shell/common/tokens.js`

- [ ] **Step 1: Write the failing tests.** `tst_qp.qml` checks each part against the reference values:
  - `QpSwitch`: 30×17, knob 13 at x 2, then 15 when on, knob colour `bgExpanded` when on.
  - `QpRow` collapsed: height `5 + max(24, two text lines) + 5`; icon 24; name elides at the row width; hover background `groupBg`.
  - `QpButton`: primary colours, disabled at 0.45, height 24, min width 64.
  - `QpChip`: on and off colours.
  - `QpHeader`: a 24 px back button, title 12/600, a slot for actions.
  - Every part passes `Cursors.missing() == []`.
  - Hover transitions take 0.15 s.
- [ ] **Step 2: Run them to verify they fail** (the parts are missing).
- [ ] **Step 3: Implement** the tokens (the reference values above, each with its CSS selector in a comment) and the parts.
- [ ] **Step 4: Tests pass; the suite passes.**
- [ ] **Step 5: Commit** `feat: add Bloom's quick-panel parts`.

### Task 3: Command Center to Bloom

(Uses the owner's answer to question 1.)

- [ ] **Step 1: Failing tests** (`tst_panels.qml`):
  - **Tiles:** 2×2 order Wi-Fi, Dock Mode, Bluetooth, Notch Mode; tile height 34; title 9 px DemiBold; status 7.5 px; a long SSID elides.
  - **Active tiles:** Wi-Fi on, Bluetooth on, dock or notch mode `fixed`, all with the active colours.
  - **Wi-Fi and Bluetooth tiles:** the chevron opens the subpanel, a click on the tile toggles the radio, and a right-click opens the subpanel.
  - **Round buttons:** six in the chosen order, 32 px, `space-between`, active states.
  - **Sliders:** rows 18 tall, track 6, the percentage on the right.
  - **Frames:** a frame-count test at rest.
- [ ] **Step 2: Watch them fail.**
- [ ] **Step 3: Rewrite** `CommandCenter.qml` and `ControlTile.qml` from the reference: Column `space-between`, `Grid` 2×2, a row of round buttons, a column of sliders.
- [ ] **Step 4: Tests and the suite pass.**
- [ ] **Step 5: Commit** `feat: match the Command Center to Bloom`.

### Task 4: Calendar, timer and tasks

- [ ] **Step 1: Failing tests:**
  - **`tst_rolldigit.qml`:**
    - a value change rolls (enter from +72%, leave to −72%, 0.4 s);
    - no frames at rest;
    - the compact size is 26×46 at 28 px.
  - **`tst_calendar.qml`:**
    - the column ratio is 1.2 : 1 with the divider;
    - weekdays at opacity 0.4, 9 px; days square, 10 px; today highlighted;
    - the status texts for each state;
    - the play button is 44 tall and fills the row between a 32 px spacer and a 32 px reset;
    - reset is disabled at 0 (opacity 0.08, arrow cursor);
    - presets: 4 columns, the active one with a `border` background;
    - an invalid edit turns the digits red; Enter commits; Escape cancels;
    - the finished state is red and pulses;
    - no Tasks link or view (owner decision 3).
- [ ] **Step 2: Watch them fail.**
- [ ] **Step 3: Implement** `RollDigit.qml` (y and rotateX; Qt has no perspective, so rotateX becomes `scaleY = cos(angle)`, the 2B ruling for flips) and rewrite `CalendarPanel.qml`.
- [ ] **Step 4: Tests and the suite pass.**
- [ ] **Step 5: Commit** `feat: match the calendar and timer to Bloom`.

### Task 5: Wi-Fi and Bluetooth panels

- [ ] **Step 1: Failing tests:**
  - the headers (refresh/add, switch);
  - the empty states ("Wi-Fi is off", "Bluetooth is off");
  - row sublines and the lock badge;
  - expanded actions (Connect/Disconnect/Forget/Remove) and the password input;
  - error text in `#ff8a80`;
  - the footer, hidden when no settings tool exists (question 2).
- [ ] **Step 2: Watch them fail.**
- [ ] **Step 3: Rewrite** both panels with the qp parts.
- [ ] **Step 4: Tests and the suite pass.**
- [ ] **Step 5: Commit** `feat: match the Wi-Fi and Bluetooth panels to Bloom`.

### Task 6: Devices (battery hub), shelf, panel arrows, device alert

- [ ] **Step 1: Failing tests:**
  - battery-hub groups and order (Bloom `groupDevices`: low first, then This PC, audio and others), with the meters;
  - "No battery info";
  - shelf tiles: 104 wide, an 84 px preview, the remove button on hover, a fading text tile;
  - panel arrows 18 px at 4 px off the clock;
  - device alert sizes and the ring.
- [ ] **Step 2: Watch them fail.**
- [ ] **Step 3: Implement** from the reference.
- [ ] **Step 4: Tests and the suite pass.**
- [ ] **Step 5: Commit** `feat: match devices, shelf and alerts to Bloom`.

### Task 7: Owner live check

The owner opens each panel, hovers and presses every control, and compares against Bloom on Windows or its screenshots. Findings become fixes with tests before the merge.
