# Phase 3B: Dock Interaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Bloom's dock fully hands-on.
- **Right-click menus:**
  - on apps: pin/unpin, change/reset icon, Add App, Bloom Options, desktop actions, a new window, close;
  - on empty dock space: Add App and Bloom Options;
  - on the workspace segment: Hide Workspaces.
- **Drag to reorder** pinned apps.
- **Add App popup:** a searchable list fused above the dock.
- **Custom icons**, chosen with a file picker.
- **Workspace segment** (spec D7): it takes the place of Bloom's Start button and shows this monitor's workspaces. Click to switch, scroll to step, and the active highlight springs between cells.

**Architecture:**
- **Rules** (menu contents and placement, reorder index, Add App sections and search, workspace cells, icon state) extend `dock.js` as plain, unit-tested JS.
- **Dock service:** gains reorder, custom icons (copied into `$XDG_STATE_HOME/bloom/dock-icons/`), a file picker (kdialog, zenity or qarma), window close, workspace switching, desktop actions, and restart/quit.
- **New components:** `DockMenu`, `AddAppPopup`, `WorkspaceSegment` and `DockToast`. `DockView` hosts them, and `DockWindow` gives the surface keyboard focus and a Hyprland focus grab while a menu or the popup is open, so a click elsewhere closes it.

**Tech Stack:** Quickshell 0.3.2 (`DesktopEntries`/`DesktopAction`, `Quickshell.Hyprland` `HyprlandFocusGrab`, `Hyprland.workspaces`, `WlrLayershell.keyboardFocus`, `Quickshell.Io`), Qt 6.12 Quick/QtTest, kdialog/zenity, hyprctl (Lua dispatch), headless sway (tests).

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md`:
- §4.1 Dock ("Context menus, drag to reorder, custom icons", "The workspace switcher segment (D7) replaces the start button");
- D7;
- §3.3 (fixed-size surfaces);
- §5.2 (UI state outside settings).

This is plan 3B of three for Phase 3, building on 3A as merged at `ae7db4a`.

## Global Constraints

- **Platform:** Arch Linux; Hyprland ≥ 0.56 (Lua config); Quickshell ≥ 0.3.
- **Fixed-size surfaces** (spec §3.3): the dock surface stays one fixed size. 3B raises its height from 420 to **500** px so the 440 px Add App card fits above the dock.
- **State, not settings:** pins, order and custom icons live in `$XDG_STATE_HOME/bloom/dock.json` and `…/dock-icons/`, never in settings. A damaged state file never breaks the dock (`pinsOf`/`iconsOf` sanitise).
- **Motion:** framer-motion parity through `Spring`.
  - Duration-only transitions use framer `easeOut` `[0, 0, 0.58, 1]`; `ease: "easeIn"` is `[0.42, 0, 1, 1]`; CSS `ease` is `[0.25, 0.1, 0.25, 1]`.
  - Bloom's `cubic-bezier(0.4, 0, 0.2, 1)` is used as written.
- **Perf:** no `Spring`/`FrameAnimation` runs at rest. The skeleton pulse runs only while the Add App card is open and still loading. Frame-count tests guard 0 frames with closed menus and popup.
- **Apps are never children of the shell:** every launch (desktop actions included) goes through `Apps.run` (its own systemd scope).
- **Tests:**
  - they never touch the real session: `BLOOM_LAUNCH_SCOPE=0`; fake pickers on `PATH` (`BLOOM_PICKER` points at a stub);
  - no `hyprctl dispatch` against the live Hyprland;
  - `test_dock.sh` keeps `XDG_DATA_DIRS` at its fixture.
- **Files:** nothing under `~/.config` or `~/dots-hyprland` changes, except Task 9, run by the owner after approving each step.
- **Live tree:** `~/.config/quickshell/bloom` symlinks this working tree and Quickshell live-reloads it.
  - Keep the tree loadable between edits.
  - Merge with `git fetch . <branch>:main && git switch main`, so the files never revert mid-merge.
- **Commits:** conventional commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit …`.
- **Style:** QML and JS use tabs. Comments explain why, not what.

## Review Focus

1. **A click outside the open menu or Add App card**: on another app, the desktop, or another monitor.
   - It closes, and that click still reaches what was under it. That needs Hyprland's focus grab; outside Hyprland, Escape and clicks inside the dock surface close it.
   - Tests: Task 4 `test_escapeCloses`, Task 7 `test_outsideClickInsideTheSurfaceCloses`, Task 9 live.
2. **Dragging a pinned app:**
   - a short click must not start a drag;
   - a drag must not end in a click (launch);
   - dropping off the row keeps the last order;
   - only pinned apps (not running ones, the divider or the segment) can be dragged.
   - Tests: Task 2 `test_reorderIndex`, Task 7 `test_dragReorders`, `test_dragIsNotAClick`.
3. **Picker absent, cancelled, or returning an unreadable file.**
   - Absent: a toast says what to install.
   - Cancel: nothing happens.
   - A bad file: the toast "Couldn't use that image", and the old icon stays.
   - Tests: Task 3 `test_dock.sh` (stub picker: path, cancel, missing), Task 7 `test_toast`.
4. **Add App search:**
   - an empty query shows Running, then All apps;
   - queries match the start of a name first, then anywhere;
   - Enter on an already-pinned app only closes;
   - arrow keys clamp at the ends;
   - entries still loading show the skeleton, not "No results".
   - Tests: Task 2 `test_addAppSections`, Task 5 `test_keyboard`, `test_loadingSkeleton`.
5. **Workspaces:**
   - Named workspaces (negative ids) and many workspaces show.
   - Special (scratchpad) workspaces never show.
   - The segment hides outside Hyprland and when `bloom-dock-workspaces-enabled` is off.
   - Tests: Task 2 `test_workspaceCells`, Task 6, Task 8 `test_dock.sh`.

## Rulings made while planning (the owner sees these at review)

1. **Workspace segment design (new; Bloom has no workspace switcher).**
   - **Placement:** first in the dock row, followed by a divider, where Bloom put Start.
   - **Shape:** a 36 px tall capsule using the icon tile's look (gradient tile, radius 12; plain in icon-only mode), padding 6, holding one 24×24 cell (radius 8, gap 2) per workspace on this monitor.
   - **Labels:** cells show the workspace number at 12/600, or the first letter of a named workspace's name. The active cell has a highlight in the text colour at 0.15, with full-opacity text; other numbers sit at 0.55.
   - **Motion:** the highlight springs between cells (300/25, the dock layout spring).
   - **Input:** a cell's tooltip reads "Workspace 3" or the name; click switches; the scroll wheel steps to the next or previous existing workspace.
   - **Setting:** `bloom-dock-workspaces-enabled` (default true). Its right-click menu offers "Hide Workspaces", as Bloom's Task View offered "Hide Task View".
2. **Menus, mapped from Bloom to Linux:**
   - **Dropped:** the Start button's Windows system actions (D7 replaces Start); "Clear Icon Cache" (there's no icon cache: icons come from the theme); "Open Settings" until the settings app exists (Phase 7).
   - **Tray menus → desktop actions:** Bloom's tray menus (the taskbar's jump list) become the desktop entry's actions (Firefox: New Window, New Private Window…). Tray menus come with SNI in 3C.
   - **Labels:** "Open New Instance" is "Open New Window".
   - **Bloom Options:** "Restart Bloom" and "Quit Bloom" run `systemctl --user restart|stop bloom-shell`.
   - **Pinning:** apps without a desktop entry show no "Pin to Dock" (3A pins only desktop entries).
3. **Closing a menu on an outside click:** Bloom used a global mouse hook; Wayland has none. A `HyprlandFocusGrab` covers the dock window while a menu or the popup is open, and Hyprland clears it on a click outside. Outside Hyprland: Escape, or a click elsewhere on the dock surface.
4. **Custom icons:**
   - "Change Icon…" opens the first of kdialog, zenity or qarma (kdialog is installed here). Without any, the toast says "Install kdialog or zenity to choose icons".
   - The file is copied to `$XDG_STATE_HOME/bloom/dock-icons/<id>.<ext>`, so moving the original doesn't break the dock.
   - Allowed: png, svg, jpg/jpeg, ico, bmp, as Bloom.
   - A file Qt can't load shows the toast "Couldn't use that image" and keeps the old icon.
5. **Keyboard:** the dock surface takes keyboard focus (`OnDemand`) only while the Add App card is open, for its search field.
6. **Surface height 420 → 500** (Global Constraints).
7. **Menu colours as Bloom:** hover `#3b82f6`, destructive hover `#ef4444` (light theme: hover `groupBg`). The menu's `backdrop-filter: blur(20px)` is dropped: a layer surface can't blur what's behind it without a compositor rule, and `bgExpanded` is already 0.92 opaque.
8. **Unverified, checked live in Task 9:** switching to a named workspace with `hl.dsp.focus({ workspace = "name:<name>" })` (numbered workspaces were verified).

---

## File map

| File | Responsibility |
|---|---|
| `shell/services/settings.js`, `docs/SETTINGS.md` | `bloom-dock-workspaces-enabled` |
| `shell/common/tokens.js` | `dock.surfaceHeight` 500; `dock.menu`, `dock.popup`, `dock.toast`, `dock.workspaces`, `dock.drag` |
| `shell/modules/dock/dock.js` | menu model, menu placement, reorder index, Add App sections, workspace cells, icon state, picker script |
| `shell/services/Dock.qml` | reorder, icons, picker, close, workspaces, actions, restart/quit, toast message |
| `shell/modules/notch/WorkspaceData.qml` | + `workspaces` (this monitor's `{ id, name }` list) |
| `shell/modules/dock/DockMenu.qml` | Bloom's context menu with one submenu |
| `shell/modules/dock/AddAppPopup.qml` | The Add App card |
| `shell/modules/dock/WorkspaceSegment.qml` | The workspace switcher |
| `shell/modules/dock/DockToast.qml` | Bloom's error toast |
| `shell/modules/dock/DockIcon.qml`, `DockView.qml` | Drag state, custom icons, hosting menus/popup/segment/toast |
| `shell/modules/dock/DockWindow.qml`, `DockFocusGrab.qml`, `shell/shell.qml` | Keyboard focus, focus grab, workspace data, IPC |
| `tests/qml/tst_dock.qml`, `tst_dockmenu.qml`, `tst_addapp.qml`, `tst_wsegment.qml`, `tst_dockview.qml`, `tst_settings.qml` | Unit and component tests |
| `tests/integration/test_dock.sh`, `tests/integration/fake-picker.sh` | Icons, reorder, picker paths and workspace setting, end to end |

## Verified facts this plan relies on (checked on the owner's machine, 2026-10-26)

- **Bloom** (Dock.tsx, Dock.css @ b5fb962):
  - **Context menu** (`.context-menu`):
    - **Box:** `bloom-bg-expanded`, 1 px `bloom-border`, radius 12, padding 6, min-width 160, `box-shadow 0 10px 30px rgba(0,0,0,.5)`.
    - **Items:** padding 8×12, 13 px/500, radius 6, hover `#3b82f6`; `.quit` hover `#ef4444`; `transition all .2s cubic-bezier(0.4,0,0.2,1)`.
    - **Divider:** 1 px `bloom-border`, margin 4×8.
    - **Submenu:** to the right (`left: 100%; bottom: -6px`), min-width 140, same box, arrow "▶" 8 px at 0.5 opacity with margin-left 10.
    - **Light theme:** hover `group-bg`, shadow `0 8px 32px rgba(0,0,0,.08)`.
    - **Placement** (measured before paint): `left = clamp(x, 8, width − w − 8)`, `top = max(8, y − h − 8)`.
    - **Items (app):** Pin/Unpin; if pinned: divider, "Change Icon...", "Reset Icon" (custom only); divider; "Add App to Dock..."; "Bloom Options ▶" (Open Settings, Restart Bloom, Clear Icon Cache, divider, Quit Bloom); then, when there are tray menus or the app runs, a divider, the tray menus and "Open New Instance" (running only); then, if running, a `.quit` "Close window" or "Close all windows".
    - **Items (background):** "Add App to Dock...", "Bloom Options ▶".
    - **Task View menu:** "Open Task View", divider, "Hide Task View".
  - **Reorder** (`Reorder.Group axis="x"`, pinned items only):
    - the dragged icon takes the `drag` variant `{ y: -10, scale: 1.1, opacity: 0.8 }`;
    - the order updates live as it crosses neighbours, and is saved on drag end;
    - a click is ignored while dragging;
    - tooltips hide while dragging.
  - **Add App popup:**
    - **Card:** 360×440, `bloom-bg-expanded`, radius 18, 1 px border, `box-shadow 0 -12px 40px rgba(0,0,0,.4)`, fused into the dock top (bottom = dock height − 14).
    - **Motion:** opacity 0.15 s plus `scaleY` spring 300/28/0.9 from the bottom; exit opacity and `scaleY` 0 over 0.16 s easeIn.
    - **Search row:** margin 10/10/4, padding 10×12, radius 12, `group-bg`; search glyph 14 px muted; input 14/400 "Search apps...".
    - **List:** padding 6/10/10.
    - **Rows:** min-height 48, padding 8×10, gap 12, radius 10; hover `group-bg`.
    - **Selected row:** accent 28 % with an inset 1 px accent 55 % edge.
    - **Row parts:** icon 32 px radius 8 on `group-bg` (initial letter 13/600 muted); name 14/500 elided; a "+"/"✓" glyph 24×24, radius 7, 15/500 muted, shown on hover or selection. Pinned rows show ✓ in accent.
    - **Section label:** 11/600, tracking 0.06 em, uppercase, muted, padding 10/10/4.
    - **Empty text:** 13/500 muted, padding 40: "No results", or "Running apps show up here — search to pin anything else".
    - **Skeleton:** 8 rows pulsing 1.1 s ease-in-out between opacity 0.5 and 1.
    - **Search:** debounced 150 ms. An empty query lists running unpinned apps under "Running", then "All apps" (60, not pinned or running). A query matches the start of the name first, then anywhere, sorted by name, 50 at most.
    - **Keys:** arrows move the selection (clamped); Enter pins, or only closes if already pinned; Escape closes. A click on a row pins it (a pinned row only closes).
  - **Toast:** `bottom: 80px`, `rgba(40,40,40,.95)`, 1 px `rgba(255,255,255,.1)`, colour `#f87171`, padding 8×16, radius 8, 12/500; opacity plus `y` 10 → 0 over 0.2 s; 4 s.
  - **Custom icons:** only on pinned apps; accepted `.png,.ico,.jpg,.jpeg,.svg,.bmp`.
- **Hyprland 0.56 (Lua):**
  - `hl.dsp.window.close({ window = "address:0x…" })` closes exactly that window. With an unknown address it answers `ok` and closes nothing; the active probe window survived (tested on a throwaway kitty window).
  - `hl.dsp.focus({ workspace = <id> })` answers `ok`; a no-op on the current workspace.
- **Quickshell 0.3.2:**
  - `HyprlandFocusGrab` has `active`, `windows` and a `cleared` signal.
  - `WlrKeyboardFocus` is `None` / `Exclusive` / `OnDemand`.
  - `DesktopEntry.actions[]` have `name` and `command` (argv): Firefox has "New Window", "New Private Window" and "Open Profile Manager"; Dolphin and kitty have none.
- **Pickers:** `kdialog` is installed (`--getopenfilename`); zenity and qarma are not.

---

### Task 1: Workspace setting and 3B tokens

**Files:**
- Modify: `shell/services/settings.js`, `docs/SETTINGS.md`, `shell/common/tokens.js`
- Test: `tests/qml/tst_settings.qml`

**Interfaces:**
- Produces:
  - setting `bloom-dock-workspaces-enabled` (bool, default true);
  - `Tokens.dock.surfaceHeight` 500;
  - `Tokens.dock.menu`, `.popup`, `.toast`, `.workspaces`, `.drag` (values below).

- [ ] **Step 1: Write the failing test**

Add to `tests/qml/tst_settings.qml` after `test_dockDefaults`:

```qml
	function test_dockWorkspacesSetting() {
		compare(Settings.defaults()["bloom-dock-workspaces-enabled"], true);
		compare(Settings.validate({ "bloom-dock-workspaces-enabled": "false" }).values["bloom-dock-workspaces-enabled"], false);
	}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "FAIL|Totals"`
Expected: FAIL in `test_dockWorkspacesSetting`.

- [ ] **Step 3: Add the setting and tokens**

After `"bloom-dock-win-number-enabled"` in `shell/services/settings.js`:

```js
	"bloom-dock-workspaces-enabled": {
		type: "bool",
		default: true,
		doc: "Show this monitor's workspaces at the start of the dock (Hyprland)."
	},
```

In `Tokens.dock`, change `surfaceHeight: 420` to `surfaceHeight: 500` with the comment `// Room for the Add App card (440) over the dock, and 3C previews.` Then add these fields:

```js
	// Context menu (Dock.css .context-menu).
	menu: {
		radius: 12, padding: 6, minWidth: 160, submenuMinWidth: 140, margin: 8,
		item: { paddingV: 8, paddingH: 12, size: 13, radius: 6 },
		divider: { marginV: 4, marginH: 8 },
		arrow: { size: 8, opacity: 0.5, gap: 10 },
		hover: "#3b82f6", dangerHover: "#ef4444",
		shadow: { y: 10, blur: 30, alpha: 0.5 }, shadowLight: { y: 8, blur: 32, alpha: 0.08 },
		fadeMs: 200
	},
	// Add App card (Dock.css .add-app-popup).
	popup: {
		width: 360, height: 440, radius: 18, tuck: 14,
		shadow: { y: -12, blur: 40, alpha: 0.4 },
		search: { margin: 10, marginBottom: 4, paddingV: 10, paddingH: 12, radius: 12, gap: 10, icon: 14, size: 14 },
		list: { top: 6, side: 10, bottom: 10 },
		row: { height: 48, paddingV: 8, paddingH: 10, gap: 12, radius: 10, icon: 32, iconRadius: 8, initial: 13, name: 14, pin: 24, pinRadius: 7, pinSize: 15 },
		label: { size: 11, tracking: 0.66, top: 10, side: 10, bottom: 4 },
		empty: { size: 13, padding: 40 },
		selectedAlpha: 0.28, selectedEdgeAlpha: 0.55,
		skeleton: { rows: 8, pulseMs: 1100, line: 12 },
		debounceMs: 150, browseLimit: 60, searchLimit: 50,
		fadeMs: 150, exitMs: 160
	},
	// Error toast (Dock.css .dock-toast).
	toast: { bottom: 80, paddingV: 8, paddingH: 16, radius: 8, size: 12, color: "#f87171", slide: 10, fadeMs: 200, showMs: 4000 },
	// Workspace segment (new, D7).
	workspaces: { padding: 6, cell: 24, cellRadius: 8, gap: 2, size: 12, idleOpacity: 0.55, highlightAlpha: 0.15 },
	// Bloom's drag variant.
	drag: { y: -10, scale: 1.1, opacity: 0.8 },
```

Add the springs to `Tokens.springs`:

```js
	// Add App card (Dock.tsx AddAppPopup).
	popupScale: { stiffness: 300, damping: 28, mass: 0.9 },
```

Add `{ name: "add app card", stiffness: 300, damping: 28, mass: 0.9 }` to `SPRINGS` in `tests/parity/spring-parity.mjs`.

- [ ] **Step 4: Regenerate the reference and run the tests**

Run: `node tools/gen-settings-doc.mjs && /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "FAIL|Totals" && node tests/parity/spring-parity.mjs | tail -2`
Expected: `0 failed`; parity `ok`.

- [ ] **Step 5: Commit**

```bash
git add shell/services/settings.js docs/SETTINGS.md shell/common/tokens.js tests/parity/spring-parity.mjs tests/qml/tst_settings.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock workspaces setting and 3B tokens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Interaction rules

**Files:**
- Modify: `shell/modules/dock/dock.js`
- Test: `tests/qml/tst_dock.qml`

**Interfaces:**
- Produces (`Dock` = `dock.js`):
  - `menuFor(t)` → `Entry[]`
    - `t = { kind: "app"|"background"|"workspaces", id, pinned, pinnable, running, windows, hasCustomIcon, actions: string[] }`.
    - `Entry = { kind: "item"|"divider"|"submenu", key, label, danger, children? }`.
    - Item keys: `pin`, `unpin`, `change-icon`, `reset-icon`, `add-app`, `restart`, `quit`, `action:<n>`, `new-window`, `close`, `hide-workspaces`.
  - `menuPosition(x, y, w, h, viewW)` → `{ left, top }`
  - `reorderIndex(centers, draggedCenter)` → int (index among the other pinned slots where the dragged one goes)
  - `moveKey(keys, key, index)` → string[]
  - `addAppSections(all, running, pinned, query)` → `[{ title: string|null, items: App[] }]`, with `App = { id, name, icon }`
  - `workspaceCells(list, activeId)` → `[{ id, label, tip, active }]`, where `list` is `[{ id, name }]`
  - `segmentWidth(n)` → number
  - `iconsOf(value)` → `{ id: path }`
  - `iconFile(id, source)` → string (a file name such as `org.kde.dolphin.png`), or `""` for a bad extension
  - `pickerScript` → string (sh) printing the chosen path; exit 127 when no picker, 1 when cancelled

- [ ] **Step 1: Write the failing tests**

Append inside the TestCase in `tests/qml/tst_dock.qml`:

```qml
	function labels(entries) {
		return entries.map(e => e.kind === "divider" ? "-" : e.kind === "submenu" ? e.label + ">" : e.label);
	}

	function app(props) {
		const t = { kind: "app", id: "firefox", pinned: false, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] };
		for (const k in props) t[k] = props[k];
		return t;
	}

	// Bloom Dock.tsx menus, mapped to Linux (plan ruling 2).
	function test_menuFor() {
		compare(labels(Dock.menuFor(app({}))), ["Pin to Dock", "-", "Add App to Dock...", "Bloom Options>"]);
		compare(labels(Dock.menuFor(app({ pinned: true }))),
			["Unpin from Dock", "-", "Change Icon...", "-", "Add App to Dock...", "Bloom Options>"]);
		compare(labels(Dock.menuFor(app({ pinned: true, hasCustomIcon: true, running: true, windows: 2, actions: ["New Window", "New Private Window"] }))),
			["Unpin from Dock", "-", "Change Icon...", "Reset Icon", "-", "Add App to Dock...", "Bloom Options>",
			 "-", "New Window", "New Private Window", "Open New Window", "Close all windows"]);
		compare(labels(Dock.menuFor(app({ running: true, windows: 1, pinnable: false }))),
			["Add App to Dock...", "Bloom Options>", "-", "Open New Window", "Close window"], "no pin without a desktop entry");
		const bloom = Dock.menuFor(app({})).find(e => e.kind === "submenu");
		compare(labels(bloom.children), ["Restart Bloom", "-", "Quit Bloom"]);
		verify(bloom.children[2].danger);
		const close = Dock.menuFor(app({ running: true, windows: 1 })).pop();
		compare(close.key, "close");
		verify(close.danger);
		compare(labels(Dock.menuFor({ kind: "background" })), ["Add App to Dock...", "Bloom Options>"]);
		compare(labels(Dock.menuFor({ kind: "workspaces" })), ["Hide Workspaces"]);
		compare(Dock.menuFor(app({ actions: ["A", "B"] })).filter(e => e.key && e.key.startsWith("action:")).map(e => e.key), ["action:0", "action:1"]);
	}

	function test_menuPosition() {
		compare(Dock.menuPosition(500, 400, 160, 120, 1920), { left: 500, top: 272 }, "opens above the pointer");
		compare(Dock.menuPosition(1900, 400, 160, 120, 1920), { left: 1752, top: 272 }, "kept inside the right edge");
		compare(Dock.menuPosition(2, 60, 160, 120, 1920), { left: 8, top: 8 }, "and the left and top edges");
	}

	// framer Reorder: the dragged item takes the slot whose neighbour centre it passed.
	function test_reorderIndex() {
		const centers = [18, 66, 114]; // the other three pinned icons
		compare(Dock.reorderIndex(centers, 0), 0);
		compare(Dock.reorderIndex(centers, 30), 1);
		compare(Dock.reorderIndex(centers, 70), 2);
		compare(Dock.reorderIndex(centers, 500), 3);
		compare(Dock.reorderIndex([], 50), 0);
		compare(Dock.moveKey(["a", "b", "c"], "a", 2), ["b", "c", "a"]);
		compare(Dock.moveKey(["a", "b", "c"], "c", 0), ["c", "a", "b"]);
		compare(Dock.moveKey(["a", "b", "c"], "b", 1), ["a", "b", "c"]);
	}

	function a(id, name) {
		return { id: id, name: name, icon: "" };
	}

	function test_addAppSections() {
		const all = [a("kitty", "kitty"), a("firefox", "Firefox"), a("dolphin", "Dolphin"), a("gimp", "GIMP"), a("chrome", "Google Chrome")];
		const running = [a("chrome", "Google Chrome")];
		const browse = Dock.addAppSections(all, running, ["firefox"], "");
		compare(browse.map(s => s.title), ["Running", "All apps"]);
		compare(browse[0].items.map(i => i.id), ["chrome"]);
		compare(browse[1].items.map(i => i.id), ["dolphin", "gimp", "kitty"], "sorted, without pinned or running");
		const q = Dock.addAppSections(all, running, ["firefox"], "  i ");
		compare(q.length, 1);
		compare(q[0].title, null);
		compare(q[0].items.map(i => i.id), ["dolphin", "firefox", "gimp", "kitty"], "contains 'i', by name; a search covers pinned too");
		const g = Dock.addAppSections(all, [], [], "g");
		compare(g[0].items.map(i => i.id), ["gimp", "chrome"], "starts-with before contains");
		compare(Dock.addAppSections([], [], [], ""), [], "nothing to show");
	}

	function test_workspaceCells() {
		const cells = Dock.workspaceCells([{ id: -1337, name: "web" }, { id: 3, name: "3" }, { id: 1, name: "1" }, { id: -1338, name: "mail" }], 3);
		compare(cells.map(c => c.label), ["1", "3", "W", "M"], "numbered first, then named as created");
		compare(cells.map(c => c.tip), ["Workspace 1", "Workspace 3", "web", "mail"]);
		compare(cells.map(c => c.active), [false, true, false, false]);
		compare(Dock.workspaceCells([{ id: 2, name: "2" }, { id: -98, name: "special:magic" }], 2).map(c => c.id), [2], "no special workspaces");
		compare(Dock.segmentWidth(3), 6 + 3 * 24 + 2 * 2 + 6);
		compare(Dock.segmentWidth(1), 36);
	}

	function test_iconState() {
		compare(Dock.iconsOf({ pinned: [], icons: { firefox: "/s/firefox.png", bad: 3 } }), { firefox: "/s/firefox.png" });
		compare(Dock.iconsOf(null), {});
		compare(Dock.iconFile("org.kde.dolphin", "/home/x/Pics/My Icon.PNG"), "org.kde.dolphin.png");
		compare(Dock.iconFile("firefox", "/a/b.svg"), "firefox.svg");
		compare(Dock.iconFile("firefox", "/a/b.exe"), "", "only Bloom's image types");
		compare(Dock.iconFile("../evil", "/a/b.png"), "___evil.png", "ids can't leave the icons folder");
	}

	function test_pickerScript() {
		verify(Dock.pickerScript.indexOf("kdialog") < Dock.pickerScript.indexOf("zenity"), "kdialog first (installed here)");
		verify(Dock.pickerScript.indexOf("exit 127") > 0);
		verify(Dock.pickerScript.indexOf('"$BLOOM_PICKER"') >= 0, "tests point it at a stub");
	}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dock.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: the seven new tests FAIL (`… is not a function`); the 18 existing ones pass.

`segmentWidth(1)` is 6 + 24 + 6 = 36: a single cell makes a square tile, the size of an app icon.

- [ ] **Step 3: Implement**

Append to `shell/modules/dock/dock.js`:

```js
// Context menus (Bloom Dock.tsx), mapped to Linux: desktop actions stand in
// for the taskbar's tray/jump list, and there is no Start menu (D7).
function _item(key, label, danger) {
	return { kind: "item", key: key, label: label, danger: !!danger };
}
var _divider = { kind: "divider" };

function menuFor(t) {
	if (t.kind === "workspaces")
		return [_item("hide-workspaces", "Hide Workspaces")];
	const bloom = { kind: "submenu", key: "bloom", label: "Bloom Options", children: [_item("restart", "Restart Bloom"), _divider, _item("quit", "Quit Bloom", true)] };
	const addApp = _item("add-app", "Add App to Dock...");
	if (t.kind === "background")
		return [addApp, bloom];
	const out = [];
	if (t.pinned)
		out.push(_item("unpin", "Unpin from Dock"));
	else if (t.pinnable)
		out.push(_item("pin", "Pin to Dock"));
	if (t.pinned) {
		out.push(_divider, _item("change-icon", "Change Icon..."));
		if (t.hasCustomIcon)
			out.push(_item("reset-icon", "Reset Icon"));
	}
	if (out.length > 0)
		out.push(_divider);
	out.push(addApp, bloom);
	const actions = (t.actions || []).map((name, i) => _item("action:" + i, name));
	if (actions.length > 0 || t.running) {
		out.push(_divider);
		out.push.apply(out, actions);
		if (t.running)
			out.push(_item("new-window", "Open New Window"));
	}
	if (t.running)
		out.push(_item("close", t.windows > 1 ? "Close all windows" : "Close window", true));
	return out;
}

// Bloom: just above the pointer, kept 8 px inside the dock window.
function menuPosition(x, y, w, h, viewW) {
	const m = 8;
	return { left: Math.max(m, Math.min(x, viewW - w - m)), top: Math.max(m, y - h - m) };
}

// framer Reorder: where the dragged item goes among the others, by the
// neighbour centres it has passed.
function reorderIndex(centers, draggedCenter) {
	let i = 0;
	while (i < centers.length && draggedCenter > centers[i])
		i++;
	return i;
}

function moveKey(keys, key, index) {
	const rest = keys.filter(k => k !== key);
	rest.splice(index, 0, key);
	return rest;
}

// Bloom AddAppPopup: browse = running (unpinned) then all apps (60, not
// pinned or running); search = starts-with then contains, by name, 50 max.
function addAppSections(all, running, pinned, query) {
	const byName = (x, y) => x.name.localeCompare(y.name);
	const s = query.trim().toLowerCase();
	if (!s) {
		const suggestions = running.filter(r => pinned.indexOf(r.id) < 0);
		const ids = suggestions.map(r => r.id);
		const rest = all.filter(x => pinned.indexOf(x.id) < 0 && ids.indexOf(x.id) < 0).sort(byName).slice(0, 60);
		const out = [];
		if (suggestions.length > 0)
			out.push({ title: "Running", items: suggestions });
		if (rest.length > 0)
			out.push({ title: "All apps", items: rest });
		return out;
	}
	const starts = [];
	const contains = [];
	for (const x of all) {
		const n = x.name.toLowerCase();
		if (n.startsWith(s))
			starts.push(x);
		else if (n.indexOf(s) >= 0)
			contains.push(x);
	}
	return [{ title: null, items: starts.sort(byName).concat(contains.sort(byName)).slice(0, 50) }];
}

// The workspace segment (D7): this monitor's workspaces, no scratchpads;
// numbered ones in order, then named ones (ids -1337, -1338, …) as created.
function workspaceCells(list, activeId) {
	const rank = w => w.id > 0 ? w.id : 1e9 - w.id;
	return list
		.filter(w => !w.name.startsWith("special:"))
		.slice()
		.sort((x, y) => rank(x) - rank(y))
		.map(w => {
			const named = w.name && w.name !== String(w.id);
			return { id: w.id, label: named ? w.name.slice(0, 1).toUpperCase() : String(w.id), tip: named ? w.name : "Workspace " + w.id, active: w.id === activeId };
		});
}

function segmentWidth(n) {
	return 2 * 6 + n * 24 + Math.max(0, n - 1) * 2;
}

// Custom icons from dock.json: string paths only.
function iconsOf(value) {
	const icons = value && value.icons && typeof value.icons === "object" ? value.icons : {};
	const out = {};
	for (const id in icons)
		if (typeof icons[id] === "string" && icons[id] !== "")
			out[id] = icons[id];
	return out;
}

var ICON_TYPES = ["png", "ico", "jpg", "jpeg", "svg", "bmp"];

// The copy's name in dock-icons/: the app id (made path-safe) plus the
// source's extension; "" for anything but Bloom's image types.
function iconFile(id, source) {
	const m = /\.([A-Za-z0-9]+)$/.exec(source);
	const ext = m ? m[1].toLowerCase() : "";
	if (ICON_TYPES.indexOf(ext) < 0)
		return "";
	return id.replace(/[^A-Za-z0-9_.-]/g, "_").replace(/\.\./g, "__") + "." + ext;
}

// Prints the chosen file. Exit 1 = cancelled, 127 = no picker installed.
// BLOOM_PICKER (tests) replaces the search with a stub.
var pickerScript = 'f="Images (*.png *.svg *.jpg *.jpeg *.ico *.bmp)"; '
	+ 'if [ -n "$BLOOM_PICKER" ]; then exec "$BLOOM_PICKER"; fi; '
	+ 'if command -v kdialog >/dev/null 2>&1; then exec kdialog --title "Choose an icon" --getopenfilename "$HOME" "$f"; fi; '
	+ 'for z in zenity qarma; do if command -v $z >/dev/null 2>&1; then exec $z --file-selection --title="Choose an icon" --file-filter="Images | *.png *.svg *.jpg *.jpeg *.ico *.bmp"; fi; done; '
	+ 'exit 127';
```

`iconFile("../evil", …)`: the regex turns `/` into `_`, giving `.._evil`; the `..` replacement then gives `___evil`. The test expects `___evil.png`.

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dock.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 27 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/dock/dock.js tests/qml/tst_dock.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock interaction rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Dock service actions and IPC

**Files:**
- Modify: `shell/services/Dock.qml`, `shell/services/Apps.qml`, `shell/shell.qml` (the `dock` IpcHandler)
- Create: `tests/integration/fake-picker.sh`
- Test: `tests/integration/test_dock.sh`

**Interfaces:**
- Consumes: `dock.js` (Task 2), `Apps.run`.
- Produces:
  - **`Dock`:**
    - **State:** `icons: { id: path }`, `toast: string`, `toastSerial: int` (bumped per message);
    - **Reorder and icons:**
      - `reorder(ids: string[])`;
      - `setIcon(id, path)` → string (`"ok"`, `"not pinned"`, `"unsupported type"`; a failed copy toasts);
      - `resetIcon(id)` → string;
      - `pickIcon(id)`: opens the picker, then `setIcon`;
    - **Menu actions:** `menuTarget(id)` → the `menuFor` argument; `runMenu(id, key)`;
    - **Windows and workspaces:** `closeWindows(id)`, `switchWorkspace(id)`, `stepWorkspace(dir, cells)`;
    - **Session:** `restartShell()`, `quitShell()`.
  - **`Apps`:** `all()` → `[{ id, name, icon }]` sorted by name; `actions(id)` → string[]; `runAction(id, n)`.
  - **IPC `dock`:** `setIcon(id, path)`, `resetIcon(id)`, `reorder(ids: string)` (a JSON array), `state()` gains `icons`.

- [ ] **Step 1: Write the failing integration checks**

Create `tests/integration/fake-picker.sh`:

```bash
#!/usr/bin/env bash
# A stand-in file picker: prints the first line of $BLOOM_FAKE_PICK and
# exits with the second (0 chosen, 1 cancelled).
set -euo pipefail
sed -n 1p "$BLOOM_FAKE_PICK"
exit "$(sed -n 2p "$BLOOM_FAKE_PICK")"
```

In `tests/integration/test_dock.sh`, before `start_shell` add:

```bash
cp "$ROOT/tests/integration/fake-picker.sh" "$TEST_TMP/bin/fake-picker"
chmod +x "$TEST_TMP/bin/fake-picker"
export BLOOM_PICKER="$TEST_TMP/bin/fake-picker" BLOOM_FAKE_PICK="$TEST_TMP/pick"
printf '\x89PNG\r\n\x1a\n' >"$TEST_TMP/icon.png"   # a header is enough for the copy; Qt loading is tested in QML
```

Before the final warnings check, add:

```bash
assert_eq "$(ipc dock setIcon bloom-test-app "$TEST_TMP/icon.png")" "ok" "setIcon"
wait_for "the copy" test -f "$XDG_STATE_HOME/bloom/dock-icons/bloom-test-app.png"
wait_for "the icon in state" bash -c "ipc dock state | jq -e '.[0].icons[\"bloom-test-app\"] | endswith(\"dock-icons/bloom-test-app.png\")'"
assert_eq "$(ipc dock setIcon bloom-test-app /etc/hostname)" "unsupported type" "non-image"
assert_eq "$(ipc dock setIcon bloom-test-term "$TEST_TMP/icon.png")" "not pinned" "only pinned apps get icons"
assert_eq "$(ipc dock resetIcon bloom-test-app)" "ok" "resetIcon"
wait_for "the copy to go" bash -c "! test -f '$XDG_STATE_HOME/bloom/dock-icons/bloom-test-app.png'"
pass "custom icons are copied, kept in dock.json and reset"

ipc dock pin bloom-test-term >/dev/null
assert_eq "$(ipc dock reorder '["bloom-test-term","bloom-test-app"]')" "ok" "reorder"
wait_for "the new order" state_is "keys" '{"keys":["bloom-test-term","bloom-test-app"]}'
assert_eq "$(ipc dock reorder '["nope"]')" "order must list the pinned apps" "reorder refuses a different set"
ipc dock unpin bloom-test-term >/dev/null
pass "reorder persists and refuses a different set"

ipc settings set bloom-dock-workspaces-enabled false >/dev/null
assert_eq "$(ipc settings get bloom-dock-workspaces-enabled)" "false" "workspaces setting"
pass "the workspaces setting applies without warnings (no Hyprland here, so no segment either way)"
```

(`bin/bloom ipc` already quotes a JSON array as one argument; see the 2A note in `test_notch.sh`.)

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/integration/test_dock.sh 2>&1 | grep -E "^ok|FAIL"`
Expected: FAIL at `setIcon` ("No such function" or similar).

- [ ] **Step 3: Implement**

In `shell/services/Apps.qml` add:

```qml
	function all() {
		Apps.revision;
		return DesktopEntries.applications.values
			.map(e => ({ id: e.id, name: e.name, icon: Quickshell.iconPath(e.icon, true) }))
			.sort((a, b) => a.name.localeCompare(b.name));
	}

	function actions(id) {
		const e = id.startsWith("class:") ? null : DesktopEntries.byId(id);
		return e ? e.actions.map(a => a.name) : [];
	}

	// A desktop action (Firefox "New Private Window") in its own scope.
	function runAction(id, n) {
		const e = DesktopEntries.byId(id);
		const a = e ? e.actions[n] : null;
		if (a && a.command.length > 0)
			root.run(a.command, id, e.runInTerminal, e.workingDirectory);
	}
```

In `shell/services/Dock.qml`:

1. The state keeps pins and icons together:

```qml
	readonly property var icons: Logic.iconsOf(pins.value)
	property string toast: ""
	property int toastSerial: 0

	function _save(pinned, icons) {
		pins.save({ pinned: pinned, icons: icons });
	}

	function _toast(message) {
		root.toast = message;
		root.toastSerial++;
	}
```

Change `pin` and `unpin` to call `root._save(next, root.icons)`. `unpin` also drops that app's icon: `const icons = Object.assign({}, root.icons); delete icons[id]; root._save(…, icons)`, and deletes the copied file with `iconRm`.

2. The items show custom icons: in the `items` binding, wrap `Apps.info(id)` as `id => Object.assign(Apps.info(id), root.icons[id] ? { icon: "file://" + root.icons[id] } : {})`.

3. Add:

```qml
	readonly property string _iconDir: Paths.stateDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME")) + "/dock-icons"

	function reorder(ids) {
		const same = ids.length === root.pinned.length && ids.every(id => root.pinned.indexOf(id) >= 0);
		if (!same)
			return "order must list the pinned apps";
		root._save(ids, root.icons);
		return "ok";
	}

	function setIcon(id, path) {
		if (root.pinned.indexOf(id) < 0)
			return "not pinned";
		const file = Logic.iconFile(id, path);
		if (!file)
			return "unsupported type";
		iconCopy.target = { id: id, dest: root._iconDir + "/" + file };
		iconCopy.command = ["sh", "-c", 'mkdir -p "$1" && cp -f -- "$2" "$3"', "sh", root._iconDir, path, iconCopy.target.dest];
		iconCopy.running = true;
		return "ok";
	}

	function resetIcon(id) {
		const path = root.icons[id];
		if (!path)
			return "no custom icon";
		const icons = Object.assign({}, root.icons);
		delete icons[id];
		root._save(root.pinned, icons);
		iconRm.command = ["rm", "-f", "--", path];
		iconRm.running = true;
		return "ok";
	}

	function pickIcon(id) {
		if (picker.running)
			return;
		picker.forId = id;
		picker.running = true;
	}

	function closeWindows(id) {
		const item = root._item(id);
		for (const w of item ? item.windows : [])
			root._dispatch('hl.dsp.window.close({ window = "address:' + w.address + '" })', w.address);
	}

	function switchWorkspace(wsId) {
		if (wsId > 0)
			root._dispatch("hl.dsp.focus({ workspace = " + Math.floor(wsId) + " })", "0x0");
	}

	function switchWorkspaceNamed(name) {
		if (/^[A-Za-z0-9 _.-]+$/.test(name))
			root._dispatch('hl.dsp.focus({ workspace = "name:' + name + '" })', "0x0");
	}

	// The scroll wheel over the segment: the next or previous existing workspace.
	function stepWorkspace(dir, cells) {
		const i = cells.findIndex(c => c.active);
		const next = cells[Math.max(0, Math.min(cells.length - 1, i + dir))];
		if (next && !next.active)
			next.id > 0 ? root.switchWorkspace(next.id) : root.switchWorkspaceNamed(next.tip);
	}

	function restartShell() {
		Apps.run(["systemctl", "--user", "restart", "bloom-shell"], "bloom-restart");
	}

	function quitShell() {
		Apps.run(["systemctl", "--user", "stop", "bloom-shell"], "bloom-quit");
	}

	function menuTarget(id) {
		const item = root._item(id);
		return {
			kind: "app", id: id, pinned: root.pinned.indexOf(id) >= 0, pinnable: Apps.exists(id),
			running: !!item && item.windows.length > 0, windows: item ? item.windows.length : 0,
			hasCustomIcon: !!root.icons[id], actions: Apps.actions(id)
		};
	}

	// One menu entry's action (DockMenu reports keys; see Logic.menuFor).
	function runMenu(id, key) {
		if (key === "pin") root.pin(id);
		else if (key === "unpin") root.unpin(id);
		else if (key === "change-icon") root.pickIcon(id);
		else if (key === "reset-icon") root.resetIcon(id);
		else if (key === "new-window") root.newInstance(id);
		else if (key === "close") root.closeWindows(id);
		else if (key === "restart") root.restartShell();
		else if (key === "quit") root.quitShell();
		else if (key.startsWith("action:")) Apps.runAction(id, parseInt(key.slice(7)));
	}

	// hyprctl dispatch for addresses and workspace ids (validated by the callers).
	property var _queue: []
	function _dispatch(arg, address) {
		if (!/^0x[0-9a-f]+$/.test(address))
			return;
		root._queue = root._queue.concat([arg]);
		if (!dispatcher.running)
			root._next();
	}
	function _next() {
		if (root._queue.length === 0)
			return;
		dispatcher.command = ["hyprctl", "dispatch", root._queue[0]];
		root._queue = root._queue.slice(1);
		dispatcher.running = true;
	}

	Process { id: dispatcher; onExited: root._next() }

	Process {
		id: iconCopy
		property var target: null
		onExited: code => {
			if (code !== 0 || !root.pinned.includes(iconCopy.target.id)) {
				root._toast("Couldn't use that image");
				return;
			}
			const icons = Object.assign({}, root.icons);
			icons[iconCopy.target.id] = iconCopy.target.dest;
			root._save(root.pinned, icons);
		}
	}

	Process { id: iconRm }

	Process {
		id: picker
		property string forId: ""
		command: ["sh", "-c", Logic.pickerScript]
		stdout: StdioCollector { id: picked }
		onExited: code => {
			if (code === 127)
				root._toast("Install kdialog or zenity to choose icons");
			else if (code === 0 && picked.text.trim() !== "") {
				const r = root.setIcon(picker.forId, picked.text.trim());
				if (r === "unsupported type")
					root._toast("Couldn't use that image");
			}
		}
	}
```

Add `import "../common/paths.js" as Paths` (check its exported name with `grep -n "^function" shell/common/paths.js`; `stateFile` exists. If there is no `stateDir`, add `stateDir(xdgState, home)`, returning the folder `stateFile` uses, with a unit test in `tst_paths.qml`).

4. Replace `_focus` with `root._dispatch(Logic.focusArg(address), address)`, so focus, close and workspace switches share one queue: two quick clicks no longer drop the second (3A deferred minor).

In `shell/shell.qml`'s `dock` IpcHandler add:

```qml
		function setIcon(id: string, path: string): string {
			return Dock.setIcon(id, path);
		}

		function resetIcon(id: string): string {
			return Dock.resetIcon(id);
		}

		// `ids` is a JSON array of every pinned id in the new order.
		function reorder(ids: string): string {
			let list;
			try {
				list = JSON.parse(ids);
			} catch (e) {
				return "ids must be a JSON array";
			}
			return Array.isArray(list) ? Dock.reorder(list) : "ids must be a JSON array";
		}
```

In `state()`, add `icons: Dock.icons` beside `pinned`.

- [ ] **Step 4: Run it**

Run: `bash tests/integration/test_dock.sh 2>&1 | grep -E "^ok|FAIL"`
Expected: every `ok -` line, including the new three.

Also check the picker paths by hand in a scratch copy of the test:
- with `BLOOM_FAKE_PICK` holding `"$TEST_TMP/icon.png"` then `0`: after a `Dock.pickIcon` (call it via a temporary IPC function or the QML test in Task 7), the icon is set;
- with `1`: nothing happens;
- with `BLOOM_PICKER=/nonexistent` and no kdialog/zenity on `PATH`: the toast message is set.

Ledger the results. Task 7's `test_toast` covers the display.

- [ ] **Step 5: Commit**

```bash
git add shell/services/Dock.qml shell/services/Apps.qml shell/shell.qml tests/integration/test_dock.sh tests/integration/fake-picker.sh
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add dock actions: reorder, custom icons, close, workspaces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The context menu

**Files:**
- Create: `shell/modules/dock/DockMenu.qml`
- Test: `tests/qml/tst_dockmenu.qml`

**Interfaces:**
- Consumes: `Dock.menuFor` entries, `Dock.menuPosition`, `Tokens.dock.menu`.
- Produces `DockMenu`:
  - **Inputs:** `entries: Entry[]`, `light`, `bg` (bgExpanded), `border`, `textColor`, `groupBg`, `viewWidth`.
  - **Methods:** `openAt(x, y)`, `close()`.
  - **Readonly:** `opened`.
  - **Signal:** `chosen(string key)`.
  - **objectNames:** `"menu-item-<key>"`, `"menu-submenu-<key>"`.

- [ ] **Step 1: Write the failing test**

Create `tests/qml/tst_dockmenu.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/dock"
import "../../shell/modules/dock/dock.js" as Dock

Item {
	id: host
	width: 800
	height: 500

	Component {
		id: menuComponent
		DockMenu {
			anchors.fill: parent
			viewWidth: 800
			entries: Dock.menuFor({ kind: "app", id: "firefox", pinned: true, pinnable: true, running: true, windows: 1, hasCustomIcon: false, actions: ["New Private Window"] })
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "DockMenu"
		when: windowShown

		function make() {
			mouseMove(host, 0, 0);
			const m = createTemporaryObject(menuComponent, host);
			verify(m !== null);
			return m;
		}

		function test_opensAbovePointerAndChooses() {
			const m = make();
			const chosen = createTemporaryObject(spyComponent, host, { target: m, signalName: "chosen" });
			m.openAt(300, 480);
			verify(m.opened);
			const unpin = findChild(m, "menu-item-unpin");
			verify(unpin.mapToItem(host, 0, 0).y < 480, "above the pointer");
			mouseClick(unpin, 10, 10);
			compare(chosen.count, 1);
			compare(chosen.signalArguments[0][0], "unpin");
			verify(!m.opened, "closes after a choice");
		}

		function test_submenuOnHover() {
			const m = make();
			m.openAt(300, 480);
			const sub = findChild(m, "menu-submenu-bloom");
			const quit = findChild(m, "menu-item-quit");
			verify(!quit.visible);
			mouseMove(sub, 10, 10);
			tryCompare(quit, "visible", true, 500);
			verify(quit.mapToItem(host, 0, 0).x > sub.mapToItem(host, 0, 0).x + sub.width - 10, "to the right");
		}

		function test_hoverColours() {
			const m = make();
			m.openAt(300, 480);
			const close = findChild(m, "menu-item-close");
			const unpin = findChild(m, "menu-item-unpin");
			mouseMove(unpin, 10, 10);
			tryCompare(unpin, "hoverColor", Qt.color("#3b82f6"), 500);
			mouseMove(close, 10, 10);
			tryCompare(close, "hoverColor", Qt.color("#ef4444"), 500, "destructive items turn red");
		}

		function test_escapeCloses() {
			const m = make();
			m.openAt(300, 480);
			m.forceActiveFocus();
			keyClick(Qt.Key_Escape);
			verify(!m.opened);
		}

		function test_staysInside() {
			const m = make();
			m.openAt(790, 480);
			const box = findChild(m, "menu-box");
			verify(box.x + box.width <= 800 - 8 + 0.5);
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dockmenu.qml 2>&1 | tail -2`
Expected: fails to load.

- [ ] **Step 3: Write `DockMenu.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// Bloom's dock context menu (Dock.css .context-menu): items, dividers and one
// level of submenu to the right, opened just above the pointer.
Item {
	id: root

	property var entries: []
	property bool light: false
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property color border: Qt.rgba(1, 1, 1, 0.1)
	property color textColor: "white"
	property color groupBg: Qt.rgba(1, 1, 1, 0.04)
	property real viewWidth: width
	readonly property bool opened: box.visible

	signal chosen(string key)

	property real _x: 0
	property real _y: 0
	property string _submenu: ""

	function openAt(x, y) {
		root._x = x;
		root._y = y;
		root._submenu = "";
		box.visible = true;
		root.forceActiveFocus();
	}

	function close() {
		box.visible = false;
		root._submenu = "";
	}

	Keys.onEscapePressed: root.close()

	component MenuItem: Rectangle {
		id: item
		required property var entry
		readonly property color hoverColor: item.entry.danger ? Tokens.dock.menu.dangerHover : (root.light ? root.groupBg : Tokens.dock.menu.hover)
		objectName: (item.entry.kind === "submenu" ? "menu-submenu-" : "menu-item-") + item.entry.key
		width: parent ? parent.width : implicitWidth
		implicitWidth: label.implicitWidth + 2 * Tokens.dock.menu.item.paddingH + (item.entry.kind === "submenu" ? Tokens.dock.menu.arrow.gap + arrow.implicitWidth : 0)
		implicitHeight: label.implicitHeight + 2 * Tokens.dock.menu.item.paddingV
		radius: Tokens.dock.menu.item.radius
		color: hover.hovered || (item.entry.kind === "submenu" && root._submenu === item.entry.key) ? item.hoverColor : "transparent"
		Behavior on color {
			ColorAnimation { duration: Tokens.dock.menu.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
		}

		HoverHandler {
			id: hover
			onHoveredChanged: if (hover.hovered) root._submenu = item.entry.kind === "submenu" ? item.entry.key : (item.parent === column ? "" : root._submenu)
		}
		TapHandler {
			enabled: item.entry.kind === "item"
			onTapped: {
				root.close();
				root.chosen(item.entry.key);
			}
		}

		Text {
			id: label
			x: Tokens.dock.menu.item.paddingH
			anchors.verticalCenter: parent.verticalCenter
			text: item.entry.label
			color: root.textColor
			font.family: Tokens.type.family
			font.pixelSize: Tokens.dock.menu.item.size
			font.weight: Font.Medium
		}
		Text {
			id: arrow
			visible: item.entry.kind === "submenu"
			anchors.right: parent.right
			anchors.rightMargin: Tokens.dock.menu.item.paddingH
			anchors.verticalCenter: parent.verticalCenter
			text: "▶"
			opacity: Tokens.dock.menu.arrow.opacity
			color: root.textColor
			font.pixelSize: Tokens.dock.menu.arrow.size
		}
	}

	component Divider: Item {
		width: parent ? parent.width : 0
		height: 1 + 2 * Tokens.dock.menu.divider.marginV
		Rectangle {
			x: Tokens.dock.menu.divider.marginH
			y: Tokens.dock.menu.divider.marginV
			width: parent.width - 2 * Tokens.dock.menu.divider.marginH
			height: 1
			color: root.border
		}
	}

	component Box: Rectangle {
		radius: Tokens.dock.menu.radius
		color: root.bg
		border.width: 1
		border.color: root.border
		RectangularShadow {
			anchors.fill: parent
			z: -1
			radius: parent.radius
			offset.y: root.light ? Tokens.dock.menu.shadowLight.y : Tokens.dock.menu.shadow.y
			blur: root.light ? Tokens.dock.menu.shadowLight.blur : Tokens.dock.menu.shadow.blur
			color: Qt.rgba(0, 0, 0, root.light ? Tokens.dock.menu.shadowLight.alpha : Tokens.dock.menu.shadow.alpha)
		}
	}

	Box {
		id: box
		objectName: "menu-box"
		visible: false
		readonly property var pos: Dock.menuPosition(root._x, root._y, width, height, root.viewWidth)
		x: box.pos.left
		y: box.pos.top
		width: Math.max(Tokens.dock.menu.minWidth, column.implicitWidth) + 2 * Tokens.dock.menu.padding
		height: column.implicitHeight + 2 * Tokens.dock.menu.padding

		Column {
			id: column
			x: Tokens.dock.menu.padding
			y: Tokens.dock.menu.padding
			width: box.width - 2 * Tokens.dock.menu.padding

			Repeater {
				model: root.entries
				delegate: Loader {
					required property var modelData
					width: column.width
					sourceComponent: modelData.kind === "divider" ? dividerComponent : itemComponent
					property var entry: modelData
				}
			}
		}

		// One level of submenu, beside its item, bottoms aligned (Bloom bottom: -6px).
		Repeater {
			model: root.entries.filter(e => e.kind === "submenu")
			delegate: Box {
				required property var modelData
				readonly property Item anchorItem: root._findItem(modelData.key)
				visible: root._submenu === modelData.key && anchorItem !== null
				x: box.width - Tokens.dock.menu.padding
				y: anchorItem ? anchorItem.mapToItem(box, 0, 0).y + anchorItem.height + Tokens.dock.menu.padding - height : 0
				width: Math.max(Tokens.dock.menu.submenuMinWidth, sub.implicitWidth) + 2 * Tokens.dock.menu.padding
				height: sub.implicitHeight + 2 * Tokens.dock.menu.padding

				Column {
					id: sub
					x: Tokens.dock.menu.padding
					y: Tokens.dock.menu.padding
					width: parent.width - 2 * Tokens.dock.menu.padding
					Repeater {
						model: modelData.children
						delegate: Loader {
							required property var modelData
							width: sub.width
							sourceComponent: modelData.kind === "divider" ? dividerComponent : itemComponent
							property var entry: modelData
						}
					}
				}
			}
		}
	}

	Component { id: itemComponent; MenuItem { entry: parent.entry } }
	Component { id: dividerComponent; Divider {} }

	function _findItem(key) {
		for (let i = 0; i < column.children.length; i++) {
			const l = column.children[i];
			if (l.item && l.entry && l.entry.key === key)
				return l.item;
		}
		return null;
	}
}
```

Notes:
- The submenu's items keep `root._submenu` while hovered: `item.parent === column` is false for them.
- If `required property var entry` through `Loader` gives a "Required property … not initialized" warning, give `MenuItem` a plain `property var entry` and set it from the `Loader`'s `onLoaded: item.entry = entry`. Ledger whichever is used.

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dockmenu.qml 2>&1 | grep -E "^FAIL|Totals|warning"`
Expected: `Totals: 7 passed, 0 failed`, no warnings.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/dock/DockMenu.qml tests/qml/tst_dockmenu.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock context menu

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The Add App card

**Files:**
- Create: `shell/modules/dock/AddAppPopup.qml`
- Test: `tests/qml/tst_addapp.qml`

**Interfaces:**
- Consumes: `Dock.addAppSections`, `Tokens.dock.popup`, `Tokens.springs.popupScale`, `SvgIcon` (`search`).
- Produces `AddAppPopup`:
  - **Inputs:** `apps` (all), `running`, `pinned: string[]`, `loading: bool`, colours (`bg`, `border`, `textColor`, `textMuted`, `groupBg`, `accent`).
  - **Methods:** `open()`, `close()`.
  - **Readonly:** `opened`, `selectedIndex`, `flat` (the selectable rows).
  - **Signals:** `pinRequested(string id)`, `closed()`.
  - **objectNames:** `"addapp-search"`, `"addapp-row-<id>"`, `"addapp-empty"`, `"addapp-skeleton"`.

- [ ] **Step 1: Write the failing test**

Create `tests/qml/tst_addapp.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/dock"

Item {
	id: host
	width: 600
	height: 520

	function a(id, name) {
		return { id: id, name: name, icon: "" };
	}

	Component {
		id: popupComponent
		AddAppPopup {
			x: 120
			y: 40
			apps: [host.a("kitty", "kitty"), host.a("firefox", "Firefox"), host.a("gimp", "GIMP"), host.a("chrome", "Google Chrome")]
			running: [host.a("chrome", "Google Chrome")]
			pinned: ["firefox"]
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "AddAppPopup"
		when: windowShown

		function make(props) {
			const p = createTemporaryObject(popupComponent, host, props || {});
			verify(p !== null);
			p.open();
			return p;
		}

		function test_browseSections() {
			const p = make();
			compare(p.flat.map(x => x.id), ["chrome", "gimp", "kitty"], "Running, then All apps without pinned or running");
			verify(findChild(p, "addapp-row-chrome") !== null);
		}

		function test_searchDebounced() {
			const p = make();
			const field = findChild(p, "addapp-search");
			field.text = "fi";
			compare(p.flat.map(x => x.id), ["chrome", "gimp", "kitty"], "not before 150 ms");
			tryVerify(() => p.flat.length === 1 && p.flat[0].id === "firefox", 600);
		}

		// Review focus 4.
		function test_keyboard() {
			const p = make();
			const pin = createTemporaryObject(spyComponent, host, { target: p, signalName: "pinRequested" });
			const closed = createTemporaryObject(spyComponent, host, { target: p, signalName: "closed" });
			compare(p.selectedIndex, 0);
			keyClick(Qt.Key_Up);
			compare(p.selectedIndex, 0, "clamped at the top");
			keyClick(Qt.Key_Down);
			keyClick(Qt.Key_Down);
			keyClick(Qt.Key_Down);
			compare(p.selectedIndex, 2, "clamped at the bottom");
			keyClick(Qt.Key_Return);
			compare(pin.count, 1);
			compare(pin.signalArguments[0][0], "kitty");
			findChild(p, "addapp-search").text = "firefox";
			tryVerify(() => p.flat.length === 1, 600);
			keyClick(Qt.Key_Return);
			compare(pin.count, 1, "already pinned: Enter only closes");
			verify(closed.count >= 1);
		}

		function test_escapeCloses() {
			const p = make();
			keyClick(Qt.Key_Escape);
			verify(!p.opened);
		}

		function test_loadingSkeleton() {
			const p = make({ apps: [], running: [], loading: true });
			verify(findChild(p, "addapp-skeleton").visible);
			compare(findChild(p, "addapp-empty").visible, false, "not 'No results' while loading");
			p.loading = false;
			compare(findChild(p, "addapp-skeleton").visible, false);
			verify(findChild(p, "addapp-empty").visible);
			compare(findChild(p, "addapp-empty").text, "Running apps show up here — search to pin anything else");
		}

		function test_clickPins() {
			const p = make();
			const pin = createTemporaryObject(spyComponent, host, { target: p, signalName: "pinRequested" });
			wait(400);
			mouseClick(findChild(p, "addapp-row-gimp"), 20, 20);
			compare(pin.signalArguments[0][0], "gimp");
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_addapp.qml 2>&1 | tail -2`
Expected: fails to load.

- [ ] **Step 3: Write `AddAppPopup.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// Bloom's Add App card (Dock.tsx AddAppPopup): a search field over Running
// and All apps, fused into the top of the dock. It rises with a scaleY
// spring from its bottom edge; keys move the selection.
Item {
	id: root

	property var apps: []
	property var running: []
	property var pinned: []
	property bool loading: false
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property color border: Qt.rgba(1, 1, 1, 0.12)
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	property color accent: "#007aff"

	readonly property bool opened: root._open
	readonly property var sections: Dock.addAppSections(root.apps, root.running, root.pinned, root._query)
	readonly property var flat: root.sections.reduce((all, s) => all.concat(s.items), [])
	property int selectedIndex: 0

	signal pinRequested(string id)
	signal closed()

	property bool _open: false
	property string _query: ""

	width: Tokens.dock.popup.width
	height: Tokens.dock.popup.height
	visible: card.opacity > 0
	transformOrigin: Item.Bottom

	function open() {
		field.text = "";
		root._query = "";
		root.selectedIndex = 0;
		root._open = true;
		scaleSpring.jump(0);
		field.forceActiveFocus();
	}

	function close() {
		if (!root._open)
			return;
		root._open = false;
		root.closed();
	}

	function _choose(item) {
		if (!item)
			return;
		if (root.pinned.indexOf(item.id) >= 0)
			root.close();
		else {
			root.pinRequested(item.id);
			root.close();
		}
	}

	onFlatChanged: root.selectedIndex = Math.min(root.selectedIndex, Math.max(0, root.flat.length - 1))

	Timer {
		id: debounce
		interval: Tokens.dock.popup.debounceMs
		onTriggered: {
			root._query = field.text;
			root.selectedIndex = 0;
		}
	}

	// Enter: scaleY spring 300/28/0.9 from 0, opacity 0.15 s. Exit: both to 0
	// over 0.16 s easeIn.
	Spring {
		id: scaleSpring
		stiffness: Tokens.springs.popupScale.stiffness
		damping: Tokens.springs.popupScale.damping
		mass: Tokens.springs.popupScale.mass
		initial: 0
		target: root._open ? 1 : 0
		autoRun: root._open
	}
	property real _exitScale: 1
	NumberAnimation {
		id: exitAnim
		target: root
		property: "_exitScale"
		from: 1
		to: 0
		duration: Tokens.dock.popup.exitMs
		easing.type: Easing.BezierSpline
		easing.bezierCurve: [0.42, 0, 1, 1, 1, 1]
	}
	on_OpenChanged: if (!root._open) exitAnim.restart(); else root._exitScale = 1

	Rectangle {
		id: card
		anchors.fill: parent
		radius: Tokens.dock.popup.radius
		color: root.bg
		border.width: 1
		border.color: root.border
		clip: true
		opacity: root._open ? 1 : 0
		Behavior on opacity {
			NumberAnimation {
				duration: root._open ? Tokens.dock.popup.fadeMs : Tokens.dock.popup.exitMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: root._open ? [0, 0, 0.58, 1, 1, 1] : [0.42, 0, 1, 1, 1, 1]
			}
		}
		transform: Scale {
			origin.y: card.height
			yScale: root._open ? scaleSpring.value : scaleSpring.value * root._exitScale
		}

		Keys.forwardTo: [keys]

		Rectangle {
			id: searchRow
			x: Tokens.dock.popup.search.margin
			y: Tokens.dock.popup.search.margin
			width: parent.width - 2 * Tokens.dock.popup.search.margin
			height: field.implicitHeight + 2 * Tokens.dock.popup.search.paddingV
			radius: Tokens.dock.popup.search.radius
			color: root.groupBg

			SvgIcon {
				id: glass
				name: "search"
				size: Tokens.dock.popup.search.icon
				color: root.textMuted
				x: Tokens.dock.popup.search.paddingH
				anchors.verticalCenter: parent.verticalCenter
			}

			TextInput {
				id: field
				objectName: "addapp-search"
				x: glass.x + glass.width + Tokens.dock.popup.search.gap
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - x - Tokens.dock.popup.search.paddingH
				color: root.textColor
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.popup.search.size
				clip: true
				onTextChanged: debounce.restart()
				Keys.forwardTo: [keys]

				Text {
					visible: field.text === ""
					text: "Search apps..."
					color: root.textMuted
					font: field.font
				}
			}
		}

		Item {
			id: keys
			Keys.onPressed: event => {
				if (event.key === Qt.Key_Escape) {
					root.close();
					event.accepted = true;
				} else if (event.key === Qt.Key_Down) {
					root.selectedIndex = Math.min(root.selectedIndex + 1, Math.max(0, root.flat.length - 1));
					event.accepted = true;
				} else if (event.key === Qt.Key_Up) {
					root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
					event.accepted = true;
				} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
					root._choose(root.flat[root.selectedIndex]);
					event.accepted = true;
				}
			}
		}

		Flickable {
			id: list
			x: Tokens.dock.popup.list.side
			y: searchRow.y + searchRow.height + Tokens.dock.popup.search.marginBottom + Tokens.dock.popup.list.top
			width: parent.width - 2 * Tokens.dock.popup.list.side
			height: parent.height - y - Tokens.dock.popup.list.bottom
			contentHeight: rows.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: rows
				width: list.width
				visible: !root.loading

				Repeater {
					model: root.sections
					delegate: Column {
						required property var modelData
						width: rows.width

						Text {
							visible: modelData.title !== null
							text: (modelData.title || "").toUpperCase()
							leftPadding: Tokens.dock.popup.label.side
							topPadding: Tokens.dock.popup.label.top
							bottomPadding: Tokens.dock.popup.label.bottom
							color: root.textMuted
							font.family: Tokens.type.family
							font.pixelSize: Tokens.dock.popup.label.size
							font.weight: Font.DemiBold
							font.letterSpacing: Tokens.dock.popup.label.tracking
						}

						Repeater {
							model: modelData.items
							delegate: Rectangle {
								id: row
								required property var modelData
								readonly property int index: root.flat.indexOf(row.modelData)
								readonly property bool selected: row.index === root.selectedIndex
								readonly property bool isPinned: root.pinned.indexOf(row.modelData.id) >= 0
								objectName: "addapp-row-" + row.modelData.id
								width: rows.width
								height: Tokens.dock.popup.row.height
								radius: Tokens.dock.popup.row.radius
								color: row.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedAlpha)
									: rowHover.hovered ? root.groupBg : "transparent"
								border.width: row.selected ? 1 : 0
								border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedEdgeAlpha)
								Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }

								HoverHandler {
									id: rowHover
									onHoveredChanged: if (rowHover.hovered) root.selectedIndex = row.index
								}
								TapHandler { onTapped: root._choose(row.modelData) }

								Rectangle {
									id: iconBox
									x: Tokens.dock.popup.row.paddingH
									anchors.verticalCenter: parent.verticalCenter
									width: Tokens.dock.popup.row.icon
									height: width
									radius: Tokens.dock.popup.row.iconRadius
									color: root.groupBg
									clip: true
									Image {
										id: rowImage
										anchors.fill: parent
										source: row.modelData.icon
										sourceSize: Qt.size(64, 64)
										asynchronous: true
										fillMode: Image.PreserveAspectFit
										opacity: status === Image.Ready ? 1 : 0
										Behavior on opacity { NumberAnimation { duration: 150 } }
									}
									Text {
										anchors.centerIn: parent
										visible: rowImage.status !== Image.Ready
										text: row.modelData.name.slice(0, 1)
										color: root.textMuted
										font.family: Tokens.type.family
										font.pixelSize: Tokens.dock.popup.row.initial
										font.weight: Font.DemiBold
									}
								}

								Text {
									x: iconBox.x + iconBox.width + Tokens.dock.popup.row.gap
									anchors.verticalCenter: parent.verticalCenter
									width: pinGlyph.x - x - Tokens.dock.popup.row.gap
									text: row.modelData.name
									elide: Text.ElideRight
									color: root.textColor
									font.family: Tokens.type.family
									font.pixelSize: Tokens.dock.popup.row.name
									font.weight: Font.Medium
								}

								Text {
									id: pinGlyph
									anchors.right: parent.right
									anchors.rightMargin: Tokens.dock.popup.row.paddingH
									anchors.verticalCenter: parent.verticalCenter
									width: Tokens.dock.popup.row.pin
									horizontalAlignment: Text.AlignHCenter
									text: row.isPinned ? "✓" : "+"
									color: row.isPinned ? root.accent : root.textMuted
									opacity: row.isPinned || row.selected || rowHover.hovered ? 1 : 0
									Behavior on opacity { NumberAnimation { duration: 150 } }
									font.pixelSize: Tokens.dock.popup.row.pinSize
									font.weight: Font.Medium
								}
							}
						}
					}
				}
			}

			Text {
				objectName: "addapp-empty"
				visible: !root.loading && root.flat.length === 0
				width: list.width
				padding: Tokens.dock.popup.empty.padding
				horizontalAlignment: Text.AlignHCenter
				wrapMode: Text.WordWrap
				text: root._query.trim() ? "No results" : "Running apps show up here — search to pin anything else"
				color: root.textMuted
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.popup.empty.size
				font.weight: Font.Medium
			}

			// Skeleton rows, pulsing only while the card is open and loading.
			Column {
				objectName: "addapp-skeleton"
				visible: root.loading
				width: list.width
				opacity: pulse.value
				QtObject {
					id: pulse
					property real value: 0.5
				}
				SequentialAnimation {
					running: root.loading && root._open
					loops: Animation.Infinite
					NumberAnimation { target: pulse; property: "value"; from: 0.5; to: 1; duration: Tokens.dock.popup.skeleton.pulseMs / 2; easing.type: Easing.InOutQuad }
					NumberAnimation { target: pulse; property: "value"; from: 1; to: 0.5; duration: Tokens.dock.popup.skeleton.pulseMs / 2; easing.type: Easing.InOutQuad }
				}
				Repeater {
					model: Tokens.dock.popup.skeleton.rows
					Item {
						width: list.width
						height: Tokens.dock.popup.row.height
						Rectangle { x: Tokens.dock.popup.row.paddingH; anchors.verticalCenter: parent.verticalCenter; width: Tokens.dock.popup.row.icon; height: width; radius: Tokens.dock.popup.row.iconRadius; color: root.groupBg }
						Rectangle { x: Tokens.dock.popup.row.paddingH + Tokens.dock.popup.row.icon + Tokens.dock.popup.row.gap; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - Tokens.dock.popup.row.paddingH; height: Tokens.dock.popup.skeleton.line; radius: height / 2; color: root.groupBg }
					}
				}
			}
		}
	}

	RectangularShadow {
		anchors.fill: card
		z: -1
		visible: card.opacity > 0
		offset.y: Tokens.dock.popup.shadow.y
		blur: Tokens.dock.popup.shadow.blur
		radius: card.radius
		color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
	}
}
```

Notes:
- `search` must be in the Lucide icon table: `grep -n '"search"' shell/common/icons.js`. If it's missing, add it to `tools/gen-icons.mjs`'s list and regenerate (`node tools/gen-icons.mjs`), as 2A did.
- Bloom's `ease-in-out` keyframe pulse maps to `Easing.InOutQuad` (a close CSS-ease-in-out stand-in); ledger it.

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_addapp.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 8 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/dock/AddAppPopup.qml tests/qml/tst_addapp.qml shell/common/icons.js tools/gen-icons.mjs
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock's Add App card

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The workspace segment

**Files:**
- Create: `shell/modules/dock/WorkspaceSegment.qml`
- Modify: `shell/modules/notch/WorkspaceData.qml` (+ `workspaces`)
- Test: `tests/qml/tst_wsegment.qml`

**Interfaces:**
- Consumes: `Dock.workspaceCells`, `Dock.segmentWidth`, `Tokens.dock.workspaces`, `Tokens.springs.dockLayout`.
- Produces:
  - **`WorkspaceSegment`:**
    - Inputs: `cells`, `iconOnly`, `light`, `textColor`, `tooltipBg`, `tooltipText`.
    - Signals: `switchTo(var cell)`, `step(int dir)`, `menuRequested(real x, real y)`.
    - objectNames: `"ws-cell-<id>"`, `"ws-highlight"`.
  - **`WorkspaceData.workspaces`:** `[{ id, name }]` for this monitor.

- [ ] **Step 1: Write the failing test**

Create `tests/qml/tst_wsegment.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/dock"
import "../../shell/modules/dock/dock.js" as Dock

Item {
	id: host
	width: 400
	height: 200

	Component {
		id: segComponent
		WorkspaceSegment {
			x: 50
			y: 100
			cells: Dock.workspaceCells([{ id: 1, name: "1" }, { id: 2, name: "2" }, { id: 3, name: "3" }], 2)
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "WorkspaceSegment"
		when: windowShown

		function make() {
			mouseMove(host, 0, 0);
			const s = createTemporaryObject(segComponent, host);
			verify(s !== null);
			return s;
		}

		function test_size() {
			const s = make();
			compare(s.width, Dock.segmentWidth(3));
			compare(s.height, 36);
		}

		function test_highlightSprings() {
			const s = make();
			const hl = findChild(s, "ws-highlight");
			const cell = id => findChild(s, "ws-cell-" + id);
			compare(hl.x, cell(2).x, "starts on the active cell");
			s.cells = Dock.workspaceCells([{ id: 1, name: "1" }, { id: 2, name: "2" }, { id: 3, name: "3" }], 3);
			verify(Math.abs(hl.x - cell(2).x) < 1, "springs, not jumps");
			tryVerify(() => Math.abs(hl.x - cell(3).x) < 0.5, 1500);
		}

		function test_clickSwitches() {
			const s = make();
			const sw = createTemporaryObject(spyComponent, host, { target: s, signalName: "switchTo" });
			mouseClick(findChild(s, "ws-cell-3"), 12, 12);
			compare(sw.count, 1);
			compare(sw.signalArguments[0][0].id, 3);
		}

		function test_wheelSteps() {
			const s = make();
			const step = createTemporaryObject(spyComponent, host, { target: s, signalName: "step" });
			mouseWheel(s, 20, 18, 0, -120);
			compare(step.signalArguments[0][0], 1, "wheel down: next workspace");
			mouseWheel(s, 20, 18, 0, 120);
			compare(step.signalArguments[1][0], -1);
		}

		function test_rightClickAsksForTheMenu() {
			const s = make();
			const menu = createTemporaryObject(spyComponent, host, { target: s, signalName: "menuRequested" });
			mouseClick(s, 20, 18, Qt.RightButton);
			compare(menu.count, 1);
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wsegment.qml 2>&1 | tail -2`
Expected: fails to load.

- [ ] **Step 3: Implement**

Add to `shell/modules/notch/WorkspaceData.qml`:

```qml
	// This monitor's workspaces as { id, name }, for the dock's segment.
	readonly property var workspaces: Hyprland.workspaces.values
		.filter(w => w.monitor === root.monitor)
		.map(w => ({ id: w.id, name: w.name }))
```

Create `shell/modules/dock/WorkspaceSegment.qml`:

```qml
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// The workspace switcher (spec D7) at the start of the dock: one cell per
// workspace on this monitor in the icon tile's look; the active highlight
// springs between cells. Click switches, the wheel steps, right-click asks
// for its menu (Hide Workspaces).
Item {
	id: root

	property var cells: []
	property bool iconOnly: false
	property bool light: false
	property color textColor: "white"
	property color tooltipBg: Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
	property color tooltipText: "white"

	signal switchTo(var cell)
	signal step(int dir)
	signal menuRequested(real x, real y)

	readonly property int _active: root.cells.findIndex(c => c.active)
	readonly property real _cellX: Tokens.dock.workspaces.cell + Tokens.dock.workspaces.gap

	width: Dock.segmentWidth(root.cells.length)
	height: Tokens.dock.iconBox

	RectangularShadow {
		anchors.fill: tile
		visible: tile.visible
		offset.y: 4
		blur: 12
		radius: tile.radius
		color: Qt.rgba(0, 0, 0, 0.1)
	}
	Rectangle {
		id: tile
		anchors.fill: parent
		visible: !root.iconOnly
		radius: Tokens.dock.iconRadius
		gradient: Gradient {
			GradientStop { position: 0; color: root.light ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.2) }
			GradientStop { position: 1; color: root.light ? Qt.rgba(0, 0, 0, 0.01) : Qt.rgba(1, 1, 1, 0.05) }
		}
	}

	Rectangle {
		id: highlight
		objectName: "ws-highlight"
		visible: root._active >= 0
		x: hx.value
		y: (root.height - height) / 2
		width: Tokens.dock.workspaces.cell
		height: width
		radius: Tokens.dock.workspaces.cellRadius
		color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, Tokens.dock.workspaces.highlightAlpha)
		Spring {
			id: hx
			stiffness: Tokens.springs.dockLayout.stiffness
			damping: Tokens.springs.dockLayout.damping
			initial: Tokens.dock.workspaces.padding + Math.max(0, root._active) * root._cellX
			target: Tokens.dock.workspaces.padding + Math.max(0, root._active) * root._cellX
		}
	}

	Repeater {
		model: root.cells
		delegate: Item {
			id: cell
			required property var modelData
			required property int index
			objectName: "ws-cell-" + cell.modelData.id
			x: Tokens.dock.workspaces.padding + cell.index * root._cellX
			y: (root.height - height) / 2
			width: Tokens.dock.workspaces.cell
			height: width

			Text {
				anchors.centerIn: parent
				text: cell.modelData.label
				color: root.textColor
				opacity: cell.modelData.active ? 1 : Tokens.dock.workspaces.idleOpacity
				Behavior on opacity { NumberAnimation { duration: 200 } }
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.workspaces.size
				font.weight: Font.DemiBold
			}

			HoverHandler { id: cellHover }
			TapHandler {
				acceptedButtons: Qt.LeftButton
				onTapped: root.switchTo(cell.modelData)
			}

			// Bloom's dock tooltip, 36 px above the segment.
			Rectangle {
				x: (parent.width - width) / 2
				y: -Tokens.dock.tooltip.offset - (root.height - parent.height) / 2
				z: 1
				width: tipLabel.implicitWidth + 2 * Tokens.dock.tooltip.paddingH
				height: tipLabel.implicitHeight + 2 * Tokens.dock.tooltip.paddingV
				radius: Tokens.dock.tooltip.radius
				color: root.tooltipBg
				opacity: cellHover.hovered ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
				Text {
					id: tipLabel
					anchors.centerIn: parent
					text: cell.modelData.tip
					color: root.tooltipText
					font.family: Tokens.type.family
					font.pixelSize: Tokens.dock.tooltip.size
				}
			}
		}
	}

	WheelHandler {
		onWheel: event => root.step(event.angleDelta.y < 0 ? 1 : -1)
	}
	TapHandler {
		acceptedButtons: Qt.RightButton
		onTapped: eventPoint => {
			const p = root.mapToItem(null, eventPoint.position.x, eventPoint.position.y);
			root.menuRequested(p.x, p.y);
		}
	}
}
```

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_wsegment.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 7 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/dock/WorkspaceSegment.qml shell/modules/notch/WorkspaceData.qml tests/qml/tst_wsegment.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock's workspace segment

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Interaction in the dock view

**Files:**
- Create: `shell/modules/dock/DockToast.qml`
- Modify: `shell/modules/dock/DockIcon.qml` (drag state), `shell/modules/dock/DockView.qml`, `shell/modules/dock/dock.js` (`slots` gains the segment)
- Test: `tests/qml/tst_dockview.qml`, `tests/qml/tst_dock.qml`

**Interfaces:**
- Consumes: Tasks 2 and 4–6.
- Produces (`DockView`):
  - **New inputs:**
    - `workspaceCells: var` (`[]` hides the segment);
    - `menuTarget: var` (a function `id → menuFor argument`), `apps`, `pinnedIds`;
    - `bgExpanded`, `border`, `groupBg`, `textMuted`, `accent`;
    - `appsLoading`, `toastMessage`, `toastSerial`.
  - **New signals:** `reordered(var ids)`, `menuChosen(string id, string key)` (id `""` for background/segment), `pinRequested(string id)`, `switchWorkspace(var cell)`, `stepWorkspace(int dir)`, `hideWorkspaces()`.
  - **Readonly:** `keyboardWanted` (Add App card open), `grabWanted` (a menu or the card open), `menuItem`, `popupItem` (for the window's mask).
  - **`slots(items, separator, segmentCells)`:** puts a `{ key: "|workspaces|", kind: "workspaces" }` row first, plus a divider after it when anything follows.
  - **`layout`:** the segment's width is `segmentWidth(cells)`.

- [ ] **Step 1: Write the failing tests**

In `tests/qml/tst_dock.qml`, add:

```qml
	function test_slotsWithSegment() {
		const items = { pinned: [{ id: "a", name: "A", icon: "", windows: [] }], unpinned: [] };
		const s = Dock.slots(items, true, [{ id: 1 }, { id: 2 }]);
		compare(s.map(x => x.key), [Dock.workspacesKey, Dock.dividerKey + "ws", "a"]);
		compare(Dock.slots({ pinned: [], unpinned: [] }, true, [{ id: 1 }]).map(x => x.key), [Dock.workspacesKey], "no divider with nothing after it");
		compare(Dock.slots(items, true, []).map(x => x.key), ["a"], "no cells, no segment");
		compare(Dock.layout([Dock.workspacesKey, Dock.dividerKey + "ws", "a"], 2), { xs: [0, 74, 91], width: 127 }, "62 + 12 + 5 + 12 + 36");
	}
```

In `tests/qml/tst_dockview.qml`, add:

```qml
		// Review focus 2.
		function test_dragReorders() {
			const v = make();
			settle(v);
			settleFrames();
			const spy = createTemporaryObject(spyComponent, host, { target: v, signalName: "reordered" });
			const a = findChild(v, "dock-slot-a");
			const start = a.mapToItem(v, 18, 18);
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 64; dx += 4)
				mouseMove(v, start.x + dx, start.y);
			mouseRelease(v, start.x + 64, start.y);
			compare(spy.count, 1);
			compare(spy.signalArguments[0][0], ["b", "a"]);
		}

		function test_dragIsNotAClick() {
			const v = make();
			settle(v);
			settleFrames();
			const activated = createTemporaryObject(spyComponent, host, { target: v, signalName: "activated" });
			const a = findChild(v, "dock-slot-a");
			const start = a.mapToItem(v, 18, 18);
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 40; dx += 4)
				mouseMove(v, start.x + dx, start.y);
			mouseRelease(v, start.x + 40, start.y);
			compare(activated.count, 0);
		}

		function test_runningAppsDoNotDrag() {
			const v = make();
			settle(v);
			settleFrames();
			const spy = createTemporaryObject(spyComponent, host, { target: v, signalName: "reordered" });
			const c = findChild(v, "dock-slot-c");
			const start = c.mapToItem(v, 18, 18);
			mousePress(v, start.x, start.y);
			for (let dx = 4; dx <= 64; dx += 4)
				mouseMove(v, start.x - dx, start.y);
			mouseRelease(v, start.x - 64, start.y);
			compare(spy.count, 0);
		}

		function test_rightClickOpensTheMenu() {
			const v = make({ menuTarget: id => ({ kind: "app", id: id, pinned: true, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] }) });
			settle(v);
			settleFrames();
			const chosen = createTemporaryObject(spyComponent, host, { target: v, signalName: "menuChosen" });
			const a = findChild(v, "dock-slot-a");
			const p = a.mapToItem(v, 18, 18);
			mouseClick(v, p.x, p.y, Qt.RightButton);
			verify(v.grabWanted);
			mouseClick(findChild(v, "menu-item-unpin"), 10, 10);
			compare(chosen.signalArguments[0][0], "a");
			compare(chosen.signalArguments[0][1], "unpin");
			verify(!v.grabWanted);
		}

		// Review focus 1 (the part a test can reach).
		function test_outsideClickInsideTheSurfaceCloses() {
			const v = make({ menuTarget: id => ({ kind: "app", id: id, pinned: true, pinnable: true, running: false, windows: 0, hasCustomIcon: false, actions: [] }) });
			settle(v);
			const p = findChild(v, "dock-slot-a").mapToItem(v, 18, 18);
			mouseClick(v, p.x, p.y, Qt.RightButton);
			verify(v.grabWanted);
			mouseClick(v, 20, 20);
			verify(!v.grabWanted);
		}

		function test_addAppTakesTheKeyboard() {
			const v = make({ menuTarget: id => ({ kind: "background" }) });
			settle(v);
			v.openAddApp();
			verify(v.keyboardWanted);
			keyClick(Qt.Key_Escape);
			verify(!v.keyboardWanted);
		}

		function test_toast() {
			const v = make();
			settle(v);
			const toast = findChild(v, "dock-toast");
			compare(toast.opacity, 0);
			v.toastMessage = "Couldn't use that image";
			v.toastSerial++;
			tryCompare(toast, "opacity", 1, 500);
			compare(findChild(v, "dock-toast-text").text, "Couldn't use that image");
		}

		function test_segment() {
			const v = make({ workspaceCells: [{ id: 1, label: "1", tip: "Workspace 1", active: true }, { id: 2, label: "2", tip: "Workspace 2", active: false }] });
			settle(v);
			compare(v.stateObject().keys.slice(0, 2), ["|workspaces|", "|divider|ws"]);
			const sw = createTemporaryObject(spyComponent, host, { target: v, signalName: "switchWorkspace" });
			mouseClick(findChild(v, "ws-cell-2"), 12, 12);
			compare(sw.signalArguments[0][0].id, 2);
		}

		function test_closedMenusDrawNoFrames() {
			const v = make({ menuTarget: id => ({ kind: "background" }) });
			settle(v);
			v.openAddApp();
			wait(300);
			keyClick(Qt.Key_Escape);
			settleFrames();
			compare(framesIn(1000), 0, "nothing runs once the card has gone");
		}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dock.qml 2>&1 | grep -E "^FAIL|Totals"; /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dockview.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: the new tests FAIL; the earlier ones pass.

- [ ] **Step 3: Implement**

**`dock.js`.** Replace `slots` and `layout`:

```js
var workspacesKey = "|workspaces|";

// What the row shows: the workspace segment (D7) and its divider, pinned
// apps, Bloom's divider when both app groups have something, then the other
// running apps.
function slots(items, separator, segmentCells) {
	const app = pinned => i => ({ key: i.id, kind: "app", pinned: pinned, name: i.name, icon: i.icon, windows: i.windows.length });
	const out = [];
	const cells = segmentCells || [];
	if (cells.length > 0) {
		out.push({ key: workspacesKey, kind: "workspaces", pinned: false, name: "", icon: "", windows: cells.length });
		if (items.pinned.length + items.unpinned.length > 0)
			out.push({ key: dividerKey + "ws", kind: "divider", pinned: false, name: "", icon: "", windows: 0 });
	}
	out.push.apply(out, items.pinned.map(app(true)));
	if (separator && items.pinned.length > 0 && items.unpinned.length > 0)
		out.push({ key: dividerKey, kind: "divider", pinned: false, name: "", icon: "", windows: 0 });
	return out.concat(items.unpinned.map(app(false)));
}

function _width(key, cells) {
	if (key === workspacesKey)
		return segmentWidth(cells);
	return key.startsWith(dividerKey) ? DIVIDER_SPAN : ICON;
}

// Left edges of each row in the flex row (gap 12), and its total width.
function layout(keys, cells) {
	const xs = [];
	let x = 0;
	keys.forEach((k, i) => {
		if (i > 0)
			x += GAP;
		xs.push(x);
		x += _width(k, cells || 0);
	});
	return { xs: xs, width: x };
}
```

Update the existing `test_layout`, which still passes because a missing `cells` makes the segment 0 wide and that key never appears there. Update the 3A `test_slots` expectations by adding `pinned`; they already compare keys only, so this is a no-op.

**`DockView.qml`:**

1. **New inputs and outputs** (copy from Interfaces). Add `function openAddApp() { popup.open(); }`, and:

```qml
	readonly property bool keyboardWanted: popup.opened
	readonly property bool grabWanted: menu.opened || popup.opened
	readonly property Item menuItem: menu
	readonly property Item popupItem: popup
```

2. **`_sync` and the segment:** call `Dock.slots(root.items, root.separatorEnabled, root.workspaceCells)`, and use `Dock.layout(keys, root.workspaceCells.length)`. The divider check becomes `r.key.startsWith(Dock.dividerKey)`. A slot of kind `"workspaces"` renders a `WorkspaceSegment` instead of a `DockIcon`:

```qml
						WorkspaceSegment {
							visible: slot.kind === "workspaces"
							cells: root.workspaceCells
							iconOnly: root.iconOnly
							light: root.light
							textColor: root.textColor
							tooltipBg: root.tooltipBg
							tooltipText: root.tooltipText
							onSwitchTo: cell => root.switchWorkspace(cell)
							onStep: dir => root.stepWorkspace(dir)
							onMenuRequested: (x, y) => root._openMenu("", { kind: "workspaces" }, x, y)
						}
```

   Make the slot width `Dock._width(slot.key, root.workspaceCells.length)`. Running onWorkspaceCellsChanged → `root._sync()` keeps the segment's width current.

3. **Drag (pinned app slots only).** In the slot delegate:

```qml
						// Bloom Reorder: pinned apps only; the dragged icon follows the
						// pointer while the others slide (their layout springs).
						DragHandler {
							id: drag
							enabled: slot.kind === "app" && slot.pinned && root.expanded
							xAxis.enabled: true
							yAxis.enabled: false
							target: null
							onActiveChanged: {
								if (drag.active)
									root._dragStart(slot.key, slot.x);
								else
									root._dragEnd();
							}
							onTranslationChanged: if (drag.active) root._dragMove(drag.translation.x)
						}
```

   While dragging, the slot's `x` is `root._dragX` (not its spring) when `root._dragKey === slot.key`; write it as `x: root._dragKey === slot.key ? root._dragX : xSpring.value`. Positions are centre-relative (3A), so `_dragX` and the `slotX` centres share units, and the `DockIcon` gets `dragging: root._dragKey === slot.key`. Add to `DockView`:

```qml
	property string _dragKey: ""
	property real _dragOrigin: 0
	property real _dragX: 0
	property var _dragOrder: []

	function _pinnedKeys() {
		return root._rows.map(r => r.key).filter(k => (root.items.pinned || []).some(i => i.id === k));
	}

	function _dragStart(key, x) {
		root._dragKey = key;
		root._dragOrigin = x;
		root._dragX = x;
		root._dragOrder = root._pinnedKeys();
	}

	// Live reorder: the dragged icon passes a neighbour's centre and the row
	// re-lays out (neighbours spring), as framer's Reorder.Group.
	function _dragMove(dx) {
		root._dragX = root._dragOrigin + dx;
		const others = root._dragOrder.filter(k => k !== root._dragKey);
		const centre = k => {
			const row = root._rows.findIndex(r => r.key === k);
			return slotModel.get(row).slotX + Tokens.dock.iconBox / 2;
		};
		const index = Dock.reorderIndex(others.map(centre), root._dragX + Tokens.dock.iconBox / 2);
		const next = Dock.moveKey(root._dragOrder, root._dragKey, index);
		if (JSON.stringify(next) !== JSON.stringify(root._dragOrder)) {
			root._dragOrder = next;
			root._sync();
		}
	}

	function _dragEnd() {
		const order = root._dragOrder;
		const before = (root.items.pinned || []).map(i => i.id);
		root._dragKey = "";
		root._dragOrder = [];
		if (JSON.stringify(order) !== JSON.stringify(before))
			root.reordered(order);
		root._sync();
	}
```

   In `_sync`, when `root._dragOrder.length > 0`, order `root.items.pinned` by `root._dragOrder` before calling `Dock.slots`. The dragged key's slot keeps following `_dragX`.

4. **`DockIcon` drag state:** add `property bool dragging: false`. The lift targets become: y `dragging ? Tokens.dock.drag.y : (hovered && shown ? hover.y : 0)`; scale `pressed && !dragging ? tap : dragging ? Tokens.dock.drag.scale : hover…`. The `presence` opacity becomes `shown ? (dragging ? Tokens.dock.drag.opacity : 1) : 0`. The tooltip shows only while `!dragging`, and also hides while any drag runs: add `property bool anyDragging`, set from `root._dragKey !== ""`.

   A `TapHandler` loses its grab to an active `DragHandler`, so a drag never ends in a click. `test_dragIsNotAClick` proves it.

5. **Menus, the card, the toast.** Inside `stage`, above the pill:

```qml
		DockMenu {
			id: menu
			anchors.fill: parent
			z: 10
			viewWidth: stage.width
			light: root.light
			bg: root.bgExpanded
			border: root.border
			textColor: root.textColor
			groupBg: root.groupBg
			property string forId: ""
			onChosen: key => {
				if (key === "add-app")
					popup.open();
				else if (key === "hide-workspaces")
					root.hideWorkspaces();
				else
					root.menuChosen(menu.forId, key);
			}
		}

		AddAppPopup {
			id: popup
			z: 9
			x: (stage.width - width) / 2
			y: pillArea.y + Tokens.dock.popup.tuck - height
			apps: root.apps
			running: (root.items.unpinned || []).filter(i => !i.id.startsWith("class:")).map(i => ({ id: i.id, name: i.name, icon: i.icon }))
			pinned: (root.items.pinned || []).map(i => i.id)
			loading: root.appsLoading
			bg: root.bgExpanded
			border: root.border
			textColor: root.textColor
			textMuted: root.textMuted
			groupBg: root.groupBg
			accent: root.accent
			onPinRequested: id => root.pinRequested(id)
		}

		DockToast {
			id: toast
			objectName: "dock-toast"
			z: 11
			anchors.horizontalCenter: parent.horizontalCenter
			y: stage.height - Tokens.dock.toast.bottom - height
			message: root.toastMessage
			serial: root.toastSerial
		}
```

   The popup sits under the pill: the pill's `z` is above `popup`'s, so the 14 px tuck hides the seam, as Bloom.

   Right-click on an app slot (`TapHandler { acceptedButtons: Qt.RightButton }` in the delegate) calls `root._openMenu(slot.key, root.menuTarget(slot.key), p.x, p.y)`. Right-click on empty pill space calls `_openMenu("", { kind: "background" }, …)`. Add:

```qml
	function _openMenu(id, target, x, y) {
		menu.forId = id;
		menu.entries = Dock.menuFor(target);
		const p = stage.mapFromItem(null, x, y);
		menu.openAt(p.x, p.y);
	}
```

   A press anywhere on the surface outside the open menu or card closes it. The menu fills the stage when open, so an `Item { anchors.fill: parent; visible: root.grabWanted; TapHandler { onTapped: { menu.close(); popup.close(); } } }` sits under the menu and card (`z: 8`).

6. **The Escape and close paths** already exist in `DockMenu` and `AddAppPopup`.

Create `shell/modules/dock/DockToast.qml`:

```qml
import QtQuick
import "../../common/tokens.js" as Tokens

// Bloom's dock toast (Dock.css .dock-toast): a red message for 4 s that
// rises 10 px and fades in, shown again for each new serial.
Rectangle {
	id: root

	property string message: ""
	property int serial: 0

	property bool _showing: false
	onSerialChanged: if (root.message) { root._showing = true; hideTimer.restart(); }
	Timer { id: hideTimer; interval: Tokens.dock.toast.showMs; onTriggered: root._showing = false }

	width: text.implicitWidth + 2 * Tokens.dock.toast.paddingH
	height: text.implicitHeight + 2 * Tokens.dock.toast.paddingV
	radius: Tokens.dock.toast.radius
	color: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.95)
	border.width: 1
	border.color: Qt.rgba(1, 1, 1, 0.1)
	opacity: root._showing ? 1 : 0
	visible: opacity > 0
	transform: Translate {
		y: root._showing ? 0 : Tokens.dock.toast.slide
		Behavior on y { NumberAnimation { duration: Tokens.dock.toast.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }
	}
	Behavior on opacity { NumberAnimation { duration: Tokens.dock.toast.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }

	Text {
		id: text
		objectName: "dock-toast-text"
		anchors.centerIn: parent
		text: root.message
		color: Tokens.dock.toast.color
		font.family: Tokens.type.family
		font.pixelSize: Tokens.dock.toast.size
		font.weight: Font.Medium
	}
}
```

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `0 failed` across every file, including the 3A dock-view tests.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/dock/ tests/qml/tst_dock.qml tests/qml/tst_dockview.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: drag, menus, Add App and the workspace segment in the dock

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Wiring

**Files:**
- Create: `shell/modules/dock/DockFocusGrab.qml`
- Modify: `shell/modules/dock/DockWindow.qml`
- Test: `tests/integration/test_dock.sh`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `DockWindow` keyboard focus `OnDemand` while `view.keyboardWanted`;
  - a `HyprlandFocusGrab` (Hyprland only) active while `view.grabWanted`;
  - the mask includes the open menu or card;
  - the segment is fed from `WorkspaceData`.

- [ ] **Step 1: Write the failing check**

In `tests/integration/test_dock.sh`, after the modes checks, add:

```bash
# No Hyprland here: no workspace segment, and the dock still works.
wait_for "no segment without Hyprland" bash -c "ipc dock state | jq -e '.[0].keys | index(\"|workspaces|\") == null'"
pass "no workspace segment outside Hyprland"
```

Then run `bash tests/integration/test_dock.sh`. It passes already: the segment needs `WorkspaceData`, which the window doesn't load yet.

The failing step here is the load check: `qmllint shell/modules/dock/DockWindow.qml` after writing the next step's references, run before creating `DockFocusGrab.qml`. Expected: "DockFocusGrab is not a type" from the dynamic loader.

- [ ] **Step 2: Implement**

Create `shell/modules/dock/DockFocusGrab.qml`:

```qml
import QtQuick
import Quickshell.Hyprland

// Hyprland's focus grab over the dock while a menu or the Add App card is
// open: a click outside clears it, and the dock closes them (Bloom used a
// global mouse hook; Wayland has none). Hyprland-only, in its own file.
Item {
	id: root

	property var window: null
	property bool active: false
	signal cleared()

	HyprlandFocusGrab {
		active: root.active && root.window !== null
		windows: root.window ? [root.window] : []
		onCleared: root.cleared()
	}
}
```

In `shell/modules/dock/DockWindow.qml`:

```qml
	WlrLayershell.keyboardFocus: view.keyboardWanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	mask: Region {
		item: view.bandActive ? view.bandItem : (view.hidden ? null : view.hitItem)
		Region { item: view.grabWanted ? view.menuItem : null }
		Region { item: view.grabWanted ? view.popupItem : null }
	}

	Loader {
		id: workspaces
		active: HyprState.available && Settings.values["bloom-dock-workspaces-enabled"]
		source: "../notch/WorkspaceData.qml"
		onLoaded: workspaces.item.screen = win.modelData
	}

	Loader {
		id: grab
		active: HyprState.available
		source: "DockFocusGrab.qml"
		onLoaded: {
			grab.item.window = win;
			grab.item.active = Qt.binding(() => view.grabWanted);
		}
	}
	Connections {
		target: grab.item
		ignoreUnknownSignals: true
		function onCleared() { view.closeMenus(); }
	}
```

Add `function closeMenus() { menu.close(); popup.close(); }` to `DockView`.

Then add to the `DockView` block:

```qml
		workspaceCells: workspaces.item ? Logic.workspaceCells(workspaces.item.workspaces, workspaces.item.workspace?.id ?? 0) : []
		menuTarget: id => Dock.menuTarget(id)
		apps: Apps.all()
		appsLoading: Apps.revision === 0
		bgExpanded: Theme.bgExpanded
		border: Theme.border
		groupBg: Theme.groupBg
		textMuted: Theme.textMuted
		accent: Theme.accent
		toastMessage: Dock.toast
		toastSerial: Dock.toastSerial
		onReordered: ids => Dock.reorder(ids)
		onMenuChosen: (id, key) => Dock.runMenu(id, key)
		onPinRequested: id => Dock.pin(id)
		onSwitchWorkspace: cell => cell.id > 0 ? Dock.switchWorkspace(cell.id) : Dock.switchWorkspaceNamed(cell.tip)
		onStepWorkspace: dir => Dock.stepWorkspace(dir, view.workspaceCells)
		onHideWorkspaces: Settings.set("bloom-dock-workspaces-enabled", false)
```

Nested `Region` children: check Quickshell's `Region` supports child regions (`regions` default property) with `grep -n '"regions"' /usr/lib/qt6/qml/Quickshell/quickshell-core.qmltypes`. If it doesn't, compute one `item` that covers both the pill and the open menu or card. Ledger it.

- [ ] **Step 3: Run everything**

Run: `bash tests/integration/test_dock.sh && tests/run-all.sh 2>&1 | tail -3`
Expected: every `ok -` line; `all checks passed`.

- [ ] **Step 4: Commit**

```bash
git add shell/modules/dock/DockFocusGrab.qml shell/modules/dock/DockWindow.qml shell/modules/dock/DockView.qml tests/integration/test_dock.sh
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: wire dock menus, focus grab, keyboard and workspaces

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Owner verification on the real session

Run only after the owner approves. Restart `bloom-shell` on the branch, then check:

- [ ] **Step 1: Menus.** Right-click an app, empty dock space, and the segment. Expected:
  - items as in ruling 2;
  - hover blue, Close and Quit red;
  - Bloom Options opens to the right;
  - a click on another window or monitor closes the menu, and that click still lands (Review Focus 1).
- [ ] **Step 2: Add App.** "Add App to Dock..." opens the card fused above the dock. Typing searches; arrows move the selection; Enter pins; Escape and an outside click close it.
- [ ] **Step 3: Reorder.** Drag a pinned app past its neighbours: they slide. Drop: the order sticks after a shell restart. A click without movement still opens the app.
- [ ] **Step 4: Custom icon.** "Change Icon..." opens kdialog. Pick a PNG: the dock shows it, and it survives a restart. "Reset Icon" restores the theme icon. Cancelling changes nothing.
- [ ] **Step 5: Workspaces.**
  - The segment shows this monitor's workspaces with the active one highlighted; switching workspaces (Super+N) moves the highlight with a spring.
  - Click and wheel switch workspaces.
  - Named workspace (ruling 8): `hyprctl dispatch 'hl.dsp.focus({ workspace = "name:bloomtest" })'` in a terminal creates one. Its cell shows "B"; clicking another cell and then "B" switches back. Then close it.
  - "Hide Workspaces" removes the segment.
- [ ] **Step 6: Desktop actions.** Right-click Firefox (if pinned or running): "New Private Window" opens one.
- [ ] **Step 7:** Record the verdict in the ledger. A finding becomes a fix with a test, before the merge.
