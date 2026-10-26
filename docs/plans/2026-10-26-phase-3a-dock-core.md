# Phase 3A: Dock Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring Bloom's dock to the bottom edge of every screen:
- **Appearance:** a 34 px pill drops in, then expands into the app row.
- **Apps:** pinned apps followed by other running apps, with a divider between them, window dots, hover lift and tooltips.
- **Clicking:** click to launch, focus or cycle windows; middle-click opens a new window.
- **Modes:** fixed (reserves its strip), smart (hides while a window covers it) and peek (hidden until the pointer rests on the bottom edge), plus an adaptive full width while the focused window is maximised.
- **Shortcuts:** Super+Alt+1–9 activate pinned app N.

**Architecture:**
- **Dock rules** (app identity, item lists, slot order with leaving items, layout, click actions, geometry, hiding, overlap) are plain JS in `dock.js`, unit-tested.
- **`Apps` service:** desktop entries (names, icons) and app launching. Every app gets its own systemd scope, so restarting the shell never takes apps down with it.
- **`Dock` service:** pins (in `$XDG_STATE_HOME/bloom/dock.json`) and running windows (from `HyprState`); it builds the items and performs activation.
- **`DockView`:** pure UI, like `NotchView`. `DockWindow` puts one on each screen.
- **Shortcuts:** Super+Alt+N uses Quickshell `GlobalShortcut`, loaded only under Hyprland.

**Tech Stack:** Quickshell 0.3.2 (`DesktopEntries`, `Quickshell.execDetached`, `Quickshell.Hyprland` `GlobalShortcut`, `Quickshell.Io`), Qt 6.12 Quick/Effects/QtTest, systemd-run (user scopes), hyprctl (Lua dispatch), headless sway (tests).

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md`:
- §4.1 Dock ("Pinned and running apps; multiple windows per app", "Modes fixed/smart/peek; adaptive width; overlap detection", "Super+Alt+1–9", D12);
- §3.3 (fixed-size surfaces);
- §5.1–5.2 (State and Settings);
- §8 phase 3 (plan 3A of three: 3A core, 3B interaction, 3C previews/extras/tray).

It builds on 2C as merged at `1e14e5e`.

## Global Constraints

- **Platform:** Arch Linux; Hyprland ≥ 0.56 (Lua config); Quickshell ≥ 0.3.
- **Layer surfaces never resize while animating:** the dock surface spans the screen width at a fixed 420 px height, and only its input mask follows the pill (spec §3.3).
- **Settings:** `bloom-*` keys in native JSON types, plus Bloom for Windows' string forms. An invalid value uses its default and logs a warning.
- **State** (pins) lives in `$XDG_STATE_HOME/bloom/dock.json`, never in settings (spec §5.2).
- **Polling** happens only while something visible needs it: smart mode polls Hyprland once a second (`HyprState` `"poll"`), and other modes follow Hyprland events.
- **Motion:** framer-motion parity through `Spring`.
  - Duration-only transitions use framer `easeOut` `[0, 0, 0.58, 1]` (motion-dom `interfaces/motion-value.mjs:27`).
  - Values with no transition: opacity uses `[0.25, 0.1, 0.35, 1]` over 300 ms; scale uses a 550/30 spring (restSpeed 10); `x`/`y` use a 500/25 spring (restSpeed 10).
- **Perf:** any running `Spring`/`FrameAnimation` redraws the whole window every frame. Springs run only while their value moves, and the frame-count tests guard 0 frames at rest, including while `HyprState` re-sends identical windows every second.
- **Apps are never children of the shell:** each launch runs in its own `app-bloom-<id>-<n>.scope`. `bloom-shell.service` uses `KillMode=control-group`, so a child would die with every shell restart.
- **Tests** never touch the real session: `bloom_env` sets `BLOOM_LAUNCH_SCOPE=0` (no `systemd-run`), `test_dock.sh` points `XDG_DATA_DIRS` at a fixture, and no test runs `hyprctl` against the live Hyprland.
- **Files:** nothing under `~/.config` or `~/dots-hyprland` changes, except Task 7, run by the owner after approving each step.
- **Commits:** conventional commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit …`.
- **Style:** QML and JS use tabs. Comments explain why, not what.

## Review Focus

1. **A running app with no desktop entry** (VS Code's `code` class has none here). It shows as its own item named after its window class, with the icon theme's icon for that class or the letter fallback. It can't be pinned (`dock pin` refuses ids that aren't desktop entries).
   - Tests: Task 2 `test_identityAndGroups`, Task 6 `test_dock.sh` (`dock pin nope`).
2. **Windows that come and go quickly.** An app closing (its item shrinks out) and reopening before the exit ends reuses the same slot instead of duplicating it. Neighbours slide with the layout spring and never jump.
   - Tests: Task 2 `test_reconcile`, Task 5 `test_reopenDuringExitReusesTheSlot`.
3. **Identical window data every second in smart mode.** `HyprState` re-sends equal client arrays, so the dock must not redraw.
   - Test: Task 5 `test_identicalItemsDrawNoFrames`.
4. **No Hyprland** (sway in tests, or before Hyprland answers). Pins still show and launch, no errors are logged, and no `GlobalShortcut` is created.
   - Test: Task 6 `test_dock.sh`.
5. **Cycling a multi-window app.** Repeated clicks visit every window in a stable order, and the first click from another app goes to the most recently used window. Focus history alone would bounce between two windows.
   - Test: Task 2 `test_clickAction`.

## Rulings made while planning (the owner sees these at review)

1. **Pins** are desktop-entry ids in `$XDG_STATE_HOME/bloom/dock.json` (`{ "pinned": ["firefox", …] }`). The list starts empty.
   - 3A pins and unpins through `bloom ipc dock pin <id>` / `dock unpin <id>`. Menus come in 3B.
   - Bloom kept `pinned_apps.json` in its app-data folder.
2. **App identity** is the desktop entry Quickshell's `DesktopEntries.heuristicLookup(class)` finds for a window's class, else `class:<class>`. This replaces Bloom's Windows paths/AUMID/PWA matching. All of an app's windows, on any workspace or monitor, are one item.
3. **Clicks:**
   - not running → launch;
   - running but not focused → focus its most recent window;
   - focused with several windows → the next window in a stable order;
   - focused with one window → nothing.

   Hyprland has no minimise, so Bloom's minimise-on-click doesn't carry over.
4. **Launching:**
   - `systemd-run --user --scope --collect --unit=app-bloom-<id>-<n>`, falling back to a plain detached exec where no user systemd answers (CI containers);
   - entries with `Terminal=true` run through `xdg-terminal-exec`;
   - the notch's mixer button (2B) moves to the same launcher, because today it dies with the shell.
5. **No Start button and no Task View.** Spec D7 gives the Start button's place to the workspace segment (3B), and Task View is a Windows feature (the overview comes in Phase 6).
6. **Edge reveal:** a 2 px band across the dock's resting width plus the `bloom-dock-edge-delay` dwell, like the notch's top band.
   - Bloom used an 8 px full-width hook. On Wayland the band is part of our input region and would swallow clicks on maximised apps' bottom rows.
7. **Layer:** the dock sits on the Top layer, which Hyprland keeps under fullscreen windows. Fixed mode reserves `56 × bloom-scale` px at the bottom, as Bloom's AppBar did.
8. **Super+Alt+1–9 (D12)** are `GlobalShortcut`s `bloom:dock-1`…`bloom:dock-9`.
   - **Conflict:** your current Hyprland config binds Super+Alt+1–0 to "send window to workspace N" (`keybinds.lua:199-203`).
   - Task 7 asks you to choose: take the keys for the dock (D12) and move "send to workspace", or keep them and leave the dock on IPC only.
9. **Visual translations** (as in 2B):
   - the icon tile's 135° gradient becomes vertical;
   - CSS `box-shadow`s become `RectangularShadow`;
   - the dock font is Inter (D10) instead of Segoe UI;
   - leaving items are removed 450 ms after they start leaving: 150 ms delay plus the 400/25 scale spring settling, as framer's `AnimatePresence`.

---

## File map

| File | Responsibility |
|---|---|
| `shell/services/settings.js`, `docs/SETTINGS.md` | Dock settings |
| `shell/common/tokens.js`, `tests/parity/spring-parity.mjs` | `dock` tokens, dock springs and their parity |
| `shell/modules/dock/dock.js` | Dock rules |
| `shell/services/launch.js`, `shell/services/Apps.qml` | Launch argv; desktop entries, icons, launching |
| `shell/services/Audio.qml` | Mixer launches through `Apps.run` |
| `shell/services/Dock.qml` | Pins (StateFile), running windows, items, activation |
| `shell/modules/dock/DockIcon.qml` | One app: tile, image, hover/tap springs, tooltip, dots |
| `shell/modules/dock/DockView.qml` | The pill, modes, edge band, slots with presence |
| `shell/modules/dock/DockWindow.qml`, `DockShortcuts.qml`, `shell/shell.qml` | Per-screen surface; Super+Alt+N; `dock` IPC |
| `tests/qml/tst_settings.qml`, `tst_dock.qml`, `tst_launch.qml`, `tst_dockicon.qml`, `tst_dockview.qml` | Unit and component tests |
| `tests/integration/lib.sh`, `test_dock.sh`, `fixtures/applications/bloom-test-app.desktop` | End-to-end dock on sway |

## Verified facts this plan relies on (checked on the owner's machine, 2026-10-26)

- **Bloom dock** (Dock.tsx, Dock.css, dockGeometry.ts, services.rs, commands.rs @ b5fb962):
  - **The pill** (`motion.div.dock`):
    - **Initial and startup:** initial `{ y: -800, width 34, height 34, radii 17 }`. After the window is visible: ready; impacted at 280 ms; expanded at 350 ms; startup over at 1500 ms.
    - **`y`:** `!ready ? -800 : visible ? (hidden ? 100 : 0) : 150`.
    - **Size:** width `expanded && !hidden && visible ? (adaptive ? adaptiveWidth : auto) : 34`; height `… ? auto : 34`.
    - **Radii:** top 18 and bottom 0 when `(impacted || expanded) && !hidden && visible`; otherwise all 17.
    - **Opacity:** `visible ? 1 : 0`.
    - **Transitions:** `y` spring 400/35/0.8; width/height spring 250/22/0.8; layout spring 300/25; radii spring 500/30; opacity tween 0.2 s.
    - **Background:** `EdgeSurface edge="bottom"`, flares while `expanded && !hidden`.
  - **CSS:**
    - `.dock`: padding 8, gap 12.
    - `.dock-icon`: 36×36, radius 12, `linear-gradient(135deg, rgba(255,255,255,.2), rgba(255,255,255,.05))`, `box-shadow 0 4px 12px rgba(0,0,0,.1)`; image 28; icon-only: no tile, image 32.
    - Light mode: tile `rgba(0,0,0,.04)` → `rgba(0,0,0,.01)`.
    - `.dock-app-divider`: 1×26, margin 0 2, text colour at 24 %.
    - Dots (`.window-dots`): 4 px, gap 3, `bottom: -4px`, white with `0 0 4px rgba(255,255,255,.8)`; light: text colour, glow 3 px; one per window, at most 3.
    - `.tooltip`: `top: -36px`, `rgba(0,0,0,.7)`, padding 4×10, radius 6, 12 px; hidden state `translate(-50%, 4px) scale(.95)` opacity 0; `transition: all .2s ease`; light: `bloom-bg-expanded` and text colour.
    - `.fallback-icon`: first letter, 16/600, white 0.7, uppercase.
  - **Items:**
    - entry `{ opacity 0, scale 0 } → 1`: opacity 0.15 s, scale spring 400/25, both delayed 0.15 s; exit back to 0 with the same transition;
    - hover variant `{ y: -5, scale: 1.1 }`, tap `{ scale: .95 }` (framer defaults: `y` 500/25, scale 550/30);
    - content fades in over 0.15 s when expanded;
    - divider shown when `separator && unpinned.length > 0 && pinned.length > 0`.
  - **Behaviour:**
    - Grace 800 ms after the last interaction.
    - Hidden: smart = overlapped and no interaction; peek = no interaction; never during startup.
    - Adaptive = `bloom-dock-adaptive && mode === "fixed" && maximised && expanded && !hidden && visible`, with width `(viewport − 48 × scale) / scale`.
  - **Overlap** (services.rs `window_reaches_dock`): a maximised or fullscreen focused window overlaps. Otherwise the window must overlap the dock's natural span horizontally (±4 px) and reach below `screenBottom − 56 × scale` (+4).
  - **Fixed mode:** reserves `56 × bloom-scale` (`register_dock_appbar`). Edge dwell default 200 ms (`bloom-dock-edge-delay`, 0–2000).
  - **Settings:** `bloom-dock-mode` default `"smart"` (`"auto-hide"` → smart), `-icon-only` false, `-separator-enabled` true, `-adaptive` false, `-win-number-enabled` true.
- **Quickshell 0.3.2:**
  - **Desktop entries:**
    - `DesktopEntries.heuristicLookup(class)` resolves: `Chatgpt` → `chatgpt`, `com.anthropic.Claude`, `google-chrome`, `firefox`, `kitty`, `org.kde.dolphin`, `brave-browser`. `code` → null.
    - `DesktopEntry.command` is already argv with field codes removed (`["claude-desktop"]` for `claude-desktop %U`).
    - `Quickshell.iconPath(name, true)` returns `image://icon/<name>`.
    - `DesktopEntries.applications` fills in gradually after load (counted 1→59), so lookups must re-run as it grows.
  - **Other APIs:** `Quickshell.execDetached(context)` takes `{ command, workingDirectory }`. `GlobalShortcut` (`Quickshell.Hyprland`) has `appid`, `name`, `description` and a `pressed` signal.
- **Hyprland 0.56 (Lua):**
  - `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x…" })'` answers `ok` and focuses; an unknown address answers `hl.focus: window not found`.
  - The owner's config binds `SUPER + ALT + 1..0` to send-to-workspace.
- **systemd:** `bloom-shell.service` has `KillMode=control-group` (`systemctl --user show bloom-shell`). The shell's environment carries `WAYLAND_DISPLAY`, `DISPLAY`, `XDG_CURRENT_DESKTOP=Hyprland`, `DBUS_SESSION_BUS_ADDRESS` and `HYPRLAND_INSTANCE_SIGNATURE`, so launched apps get a full session environment.

---

### Task 1: Dock settings

**Files:**
- Modify: `shell/services/settings.js` (after `"bloom-workspace-peek-enabled"`), `docs/SETTINGS.md` (regenerated)
- Test: `tests/qml/tst_settings.qml`

**Interfaces:**
- Produces settings:
  - `bloom-dock-mode` (`fixed`/`smart`/`peek`, default `smart`, alias `auto-hide`);
  - `bloom-dock-edge-delay` (0–2000, default 200);
  - `bloom-dock-icon-only` (false);
  - `bloom-dock-separator-enabled` (true);
  - `bloom-dock-adaptive` (false);
  - `bloom-dock-win-number-enabled` (true).

- [ ] **Step 1: Write the failing test**

Add to `tests/qml/tst_settings.qml` after `test_pulseDefaults`:

```qml
	function test_dockDefaults() {
		const d = Settings.defaults();
		compare(d["bloom-dock-mode"], "smart");
		compare(d["bloom-dock-edge-delay"], 200);
		compare(d["bloom-dock-icon-only"], false);
		compare(d["bloom-dock-separator-enabled"], true);
		compare(d["bloom-dock-adaptive"], false);
		compare(d["bloom-dock-win-number-enabled"], true);
		compare(Settings.validateOne("bloom-dock-mode", "auto-hide"), { ok: true, value: "smart" });
		verify(!Settings.validateOne("bloom-dock-edge-delay", 2500).ok);
		const s = Settings.validate({ "bloom-dock-icon-only": "true", "bloom-dock-edge-delay": "0" });
		compare(s.values["bloom-dock-icon-only"], true, "Bloom's string form");
		compare(s.values["bloom-dock-edge-delay"], 0);
		compare(s.warnings, []);
	}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "FAIL|Totals"`
Expected: FAIL in `test_dockDefaults`.

- [ ] **Step 3: Add the keys**

After the `"bloom-workspace-peek-enabled"` entry in `shell/services/settings.js`:

```js
	"bloom-dock-mode": {
		type: "enum",
		values: ["fixed", "smart", "peek"],
		aliases: { "auto-hide": "smart" },
		default: "smart",
		doc: "Dock visibility. fixed = always shown, with its strip reserved; smart = hides while a window covers it; peek = hidden until the pointer rests on the bottom edge."
	},
	"bloom-dock-edge-delay": {
		type: "number",
		min: 0,
		max: 2000,
		default: 200,
		doc: "In smart and peek mode, how long (ms) the pointer must rest on the bottom edge before a hidden dock appears. 0 reveals it at once."
	},
	"bloom-dock-icon-only": {
		type: "bool",
		default: false,
		doc: "Show dock icons without their tile background."
	},
	"bloom-dock-separator-enabled": {
		type: "bool",
		default: true,
		doc: "A divider between pinned apps and other running apps."
	},
	"bloom-dock-adaptive": {
		type: "bool",
		default: false,
		doc: "Fixed dock only: stretch to the full screen width while the focused window is maximised."
	},
	"bloom-dock-win-number-enabled": {
		type: "bool",
		default: true,
		doc: "Super+Alt+1–9 activate the matching pinned dock app: launch it, focus it, or cycle its windows."
	},
```

- [ ] **Step 4: Regenerate the reference and run the tests**

Run: `node tools/gen-settings-doc.mjs && /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "FAIL|Totals" && node tools/gen-settings-doc.mjs --check`
Expected: `Totals: N passed, 0 failed`; the doc check passes.

- [ ] **Step 5: Commit**

```bash
git add shell/services/settings.js docs/SETTINGS.md tests/qml/tst_settings.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Dock rules and tokens

**Files:**
- Create: `shell/modules/dock/dock.js`
- Modify: `shell/common/tokens.js` (springs + `dock`), `tests/parity/spring-parity.mjs`
- Test: `tests/qml/tst_dock.qml` (new)

**Interfaces:**
- Consumes: `notch.js` `focusedWindow(clients, monitor)`, which returns `{ x, y, width, height, fullscreen }` or null.
- Produces (`dock.js`, imported as `Dock`):
  - `dividerKey` (string `"|divider|"`)
  - `identity(cls, entryId)` → string
  - `groupWindows(clients, idOf)` → `[{ id, cls, windows: [{ address, focus, title }] }]`, in client order. `idOf(cls)` returns the identity.
  - `nextOrder(prev, runningIds)` → string[]
  - `buildItems(pinned, groups, order, info)` → `{ pinned: Item[], unpinned: Item[] }`, where `Item = { id, name, icon, windows: Window[] }` and `info(id)` → `{ name, icon }`.
  - `slots(items, separator)` → `[{ key, kind: "app"|"divider", name, icon, windows: int }]`
  - `reconcile(prev, nextKeys, expired)` → `[{ key, leaving }]`
  - `layout(keys)` → `{ xs: number[], width: number }`
  - `clickAction(item, activeAddress)` → `{ kind: "launch" }`, `{ kind: "focus", address }` or `{ kind: "none" }`
  - `dotCount(windows)` → 0–3
  - `isHidden(mode, overlapped, interaction, startupAnimating)` → bool
  - `geometry(s)` → `{ y, width, height, edgeRadius, farRadius, opacity }`
  - `adaptiveWidth(viewport, scale)` → number
  - `dockRect(monitor, naturalWidth, uiScale)` → `{ left, right, bottom }`
  - `overlaps(win, rect, uiScale)` → bool
  - `maximized(win)` → bool
  - `focusArg(address)` → string, or `""` for an invalid address
- Produces (tokens):
  - `Tokens.springs.dockY` {400, 35, 0.8}, `dockSize` {250, 22, 0.8}, `dockLayout` {300, 25, 1}, `dockRadius` {500, 30, 1}, `itemEntry` {400, 25, 1}, `hoverY` {500, 25, 1, restSpeed 10}, `hoverScale` {550, 30, 1, restSpeed 10};
  - `Tokens.dock` (values in Step 5).

- [ ] **Step 1: Write the failing tests**

Create `tests/qml/tst_dock.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/dock/dock.js" as Dock

TestCase {
	name: "DockRules"

	function client(cls, address, focus, extra) {
		const c = { class: cls, address: address, focusHistoryID: focus, title: cls + " " + address, mapped: true, hidden: false };
		for (const k in extra || {}) c[k] = extra[k];
		return c;
	}

	function idOf(cls) {
		return Dock.identity(cls, { firefox: "firefox", kitty: "kitty" }[cls] || "");
	}

	function test_identityAndGroups() {
		compare(Dock.identity("firefox", "firefox"), "firefox");
		compare(Dock.identity("code", ""), "class:code", "no desktop entry");
		const groups = Dock.groupWindows([
			client("kitty", "0xa", 2), client("firefox", "0xb", 0), client("kitty", "0xc", 1),
			client("code", "0xd", 3), client("", "0xe", 4), client("ghost", "0xf", 5, { mapped: false }), client("hid", "0x10", 6, { hidden: true })
		], idOf);
		compare(groups.map(g => g.id), ["kitty", "firefox", "class:code"], "first-seen order; unnamed, unmapped and hidden windows skipped");
		compare(groups[0].windows.map(w => w.address), ["0xa", "0xc"]);
		compare(groups[0].windows[1].focus, 1);
	}

	// Bloom's activeOrder: running apps keep their place, new ones join the end.
	function test_nextOrder() {
		compare(Dock.nextOrder([], ["a", "b"]), ["a", "b"]);
		compare(Dock.nextOrder(["a", "b"], ["b", "c", "a"]), ["a", "b", "c"]);
		compare(Dock.nextOrder(["a", "b", "c"], ["c", "a"]), ["a", "c"]);
	}

	function info(id) {
		return { name: id.toUpperCase(), icon: "icon:" + id };
	}

	function test_buildItems() {
		const groups = [{ id: "kitty", windows: [{ address: "0xa", focus: 0 }] }, { id: "class:code", windows: [{ address: "0xd", focus: 1 }] }];
		const items = Dock.buildItems(["firefox", "kitty"], groups, ["kitty", "class:code"], info);
		compare(items.pinned.map(i => i.id), ["firefox", "kitty"]);
		compare(items.pinned[0].windows, [], "pinned and not running");
		compare(items.pinned[1].windows.length, 1, "a pinned app picks up its windows");
		compare(items.unpinned.map(i => i.id), ["class:code"], "running pins are not repeated");
		compare(items.unpinned[0].name, "CLASS:CODE");
	}

	function test_slots() {
		const items = { pinned: [{ id: "a", name: "A", icon: "", windows: [] }], unpinned: [{ id: "b", name: "B", icon: "x", windows: [1, 2, 3, 4] }] };
		const s = Dock.slots(items, true);
		compare(s.map(x => x.key), ["a", Dock.dividerKey, "b"]);
		compare(s[2].windows, 4);
		compare(Dock.slots(items, false).map(x => x.key), ["a", "b"], "separator off");
		compare(Dock.slots({ pinned: [], unpinned: items.unpinned }, true).map(x => x.key), ["b"], "no pinned, no divider");
		compare(Dock.slots({ pinned: items.pinned, unpinned: [] }, true).map(x => x.key), ["a"], "nothing unpinned, no divider");
	}

	// framer AnimatePresence: a leaving item keeps its place until its exit ends.
	function test_reconcile() {
		const rows = keys => keys.map(k => ({ key: k, leaving: false }));
		compare(Dock.reconcile([], ["a", "b"], []), rows(["a", "b"]));
		compare(Dock.reconcile(rows(["a", "b", "c"]), ["a", "c"], []), [{ key: "a", leaving: false }, { key: "b", leaving: true }, { key: "c", leaving: false }]);
		compare(Dock.reconcile(rows(["a", "b", "c"]), ["a", "c"], ["b"]), rows(["a", "c"]), "expired exits are dropped");
		compare(Dock.reconcile([{ key: "a", leaving: false }, { key: "b", leaving: true }], ["a", "b"], []), rows(["a", "b"]), "a returning item reuses its slot");
		compare(Dock.reconcile(rows(["x", "a"]), ["a"], []), [{ key: "x", leaving: true }, { key: "a", leaving: false }], "a leaving first item stays first");
		compare(Dock.reconcile(rows(["a", "b"]), ["c"], []), [{ key: "a", leaving: true }, { key: "b", leaving: true }, { key: "c", leaving: false }], "leaving items keep their place; the new one follows");
	}

	function test_layout() {
		compare(Dock.layout([]), { xs: [], width: 0 });
		compare(Dock.layout(["a"]), { xs: [0], width: 36 });
		compare(Dock.layout(["a", Dock.dividerKey, "b"]), { xs: [0, 48, 65], width: 101 }, "36 + 12 + 5 + 12 + 36");
	}

	function app(windows) {
		return { id: "x", windows: windows };
	}

	function test_clickAction() {
		compare(Dock.clickAction(app([]), "0x1"), { kind: "launch" });
		const ws = [{ address: "0xb", focus: 3 }, { address: "0xa", focus: 1 }, { address: "0xc", focus: 2 }];
		compare(Dock.clickAction(app(ws), "0xff"), { kind: "focus", address: "0xa" }, "from another app: the most recent window");
		compare(Dock.clickAction(app(ws), "0xa"), { kind: "focus", address: "0xb" }, "focused: the next in a stable order");
		compare(Dock.clickAction(app(ws), "0xb"), { kind: "focus", address: "0xc" });
		compare(Dock.clickAction(app(ws), "0xc"), { kind: "focus", address: "0xa" }, "wraps around");
		compare(Dock.clickAction(app([{ address: "0xa", focus: 0 }]), "0xa"), { kind: "none" }, "no minimise on Hyprland");
	}

	function test_dotCount() {
		compare(Dock.dotCount(0), 0);
		compare(Dock.dotCount(1), 1);
		compare(Dock.dotCount(7), 3);
	}

	function test_isHidden() {
		verify(!Dock.isHidden("fixed", true, "none", false));
		verify(Dock.isHidden("smart", true, "none", false));
		verify(!Dock.isHidden("smart", true, "grace", false));
		verify(!Dock.isHidden("smart", false, "none", false));
		verify(Dock.isHidden("peek", false, "none", false));
		verify(!Dock.isHidden("peek", false, "active", false));
		verify(!Dock.isHidden("peek", false, "none", true), "never during startup");
	}

	function geo(props) {
		const s = { ready: true, visible: true, hidden: false, expanded: true, impacted: true, contentWidth: 200, adaptive: false, adaptiveWidth: 1872 };
		for (const k in props) s[k] = props[k];
		return Dock.geometry(s);
	}

	function test_geometry() {
		compare(geo({ ready: false, expanded: false, impacted: false }), { y: -800, width: 34, height: 34, edgeRadius: 17, farRadius: 17, opacity: 1 });
		compare(geo({}), { y: 0, width: 200, height: 52, edgeRadius: 0, farRadius: 18, opacity: 1 });
		compare(geo({ expanded: false }), { y: 0, width: 34, height: 34, edgeRadius: 0, farRadius: 18, opacity: 1 }, "impacted, not yet expanded");
		compare(geo({ hidden: true }), { y: 100, width: 34, height: 34, edgeRadius: 17, farRadius: 17, opacity: 1 });
		compare(geo({ visible: false }), { y: 150, width: 34, height: 34, edgeRadius: 17, farRadius: 17, opacity: 0 });
		compare(geo({ adaptive: true }).width, 1872);
		compare(Dock.adaptiveWidth(1920, 1), 1872);
		compare(Dock.adaptiveWidth(1920, 1.2), 1552);
	}

	// Bloom window_reaches_dock, plus maximised/fullscreen always counting.
	function test_overlaps() {
		const monitor = { x: 0, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 0, 0, 0] };
		const rect = Dock.dockRect(monitor, 200, 1);
		compare(rect, { left: 860, right: 1060, bottom: 1080 });
		verify(Dock.overlaps({ x: 800, y: 600, width: 400, height: 440, fullscreen: 0 }, rect, 1), "reaches below 1080 - 56");
		verify(!Dock.overlaps({ x: 800, y: 600, width: 400, height: 420, fullscreen: 0 }, rect, 1), "stops above the trigger");
		verify(!Dock.overlaps({ x: 0, y: 600, width: 860, height: 480, fullscreen: 0 }, rect, 1), "beside the dock");
		verify(Dock.overlaps({ x: 0, y: 0, width: 10, height: 10, fullscreen: 1 }, rect, 1), "maximised");
		verify(!Dock.overlaps(null, rect, 1));
		verify(Dock.maximized({ fullscreen: 1 }));
		verify(!Dock.maximized({ fullscreen: 2 }), "fullscreen is not maximised");
		verify(!Dock.maximized(null));
		const scaled = Dock.dockRect({ x: 1920, y: 0, width: 2880, height: 1620, scale: 1.5, reserved: [0, 0, 0, 0] }, 200, 1);
		compare(scaled, { left: 1920 + 860, right: 1920 + 1060, bottom: 1080 }, "logical pixels on a scaled second monitor");
	}

	function test_focusArg() {
		compare(Dock.focusArg("0x55f359ed2430"), 'hl.dsp.focus({ window = "address:0x55f359ed2430" })');
		compare(Dock.focusArg("0x1\" })os.execute(\"x"), "", "only hex addresses reach the dispatcher");
		compare(Dock.focusArg(""), "");
	}
}
```

Add the dock springs to `tests/parity/spring-parity.mjs`'s `SPRINGS` list:

```js
	{ name: "dock y", stiffness: 400, damping: 35, mass: 0.8 },
	{ name: "dock size", stiffness: 250, damping: 22, mass: 0.8 },
	{ name: "dock layout", stiffness: 300, damping: 25, mass: 1 },
	{ name: "hover y", stiffness: 500, damping: 25, mass: 1 },
	{ name: "hover scale", stiffness: 550, damping: 30, mass: 1 }
```

(400/25 and 500/30 are already listed.)

- [ ] **Step 2: Run them to verify they fail**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dock.qml 2>&1 | tail -2`
Expected: fails to load (`dock.js` missing).

- [ ] **Step 3: Write `dock.js`**

Create `shell/modules/dock/dock.js`:

```js
.import "../notch/notch.js" as Notch

// Dock rules ported from Bloom (Dock.tsx, dockGeometry.ts, services.rs @
// b5fb962), with Hyprland window classes and desktop entries in place of
// Windows paths. Plain JS, shared with the unit tests.

var dividerKey = "|divider|";
var ICON = 36;
var GAP = 12;
var DIVIDER_SPAN = 5; // 1 px line + 2 px margin each side

// The desktop entry a window class resolves to, else the class itself.
function identity(cls, entryId) {
	return entryId ? entryId : "class:" + cls;
}

// Windows grouped by app in the order Hyprland lists them. Unmapped, hidden
// and classless windows (popups, helpers) never become dock items.
function groupWindows(clients, idOf) {
	const groups = [];
	const index = {};
	for (const c of clients) {
		if (!c.mapped || c.hidden || !c.class)
			continue;
		const id = idOf(c.class);
		if (index[id] === undefined) {
			index[id] = groups.length;
			groups.push({ id: id, cls: c.class, windows: [] });
		}
		groups[index[id]].windows.push({ address: c.address, focus: c.focusHistoryID, title: c.title });
	}
	return groups;
}

// Bloom's activeOrder: a running app keeps its place; new ones join the end.
function nextOrder(prev, runningIds) {
	const kept = prev.filter(id => runningIds.indexOf(id) >= 0);
	return kept.concat(runningIds.filter(id => kept.indexOf(id) < 0));
}

function buildItems(pinned, groups, order, info) {
	const byId = {};
	for (const g of groups)
		byId[g.id] = g;
	const item = id => {
		const i = info(id);
		return { id: id, name: i.name, icon: i.icon, windows: byId[id] ? byId[id].windows : [] };
	};
	return {
		pinned: pinned.map(item),
		unpinned: order.filter(id => byId[id] && pinned.indexOf(id) < 0).map(item)
	};
}

// What the row shows: pinned apps, Bloom's divider when both groups have
// something, then the other running apps.
function slots(items, separator) {
	const app = i => ({ key: i.id, kind: "app", name: i.name, icon: i.icon, windows: i.windows.length });
	const out = items.pinned.map(app);
	if (separator && items.pinned.length > 0 && items.unpinned.length > 0)
		out.push({ key: dividerKey, kind: "divider", name: "", icon: "", windows: 0 });
	return out.concat(items.unpinned.map(app));
}

// framer AnimatePresence: a row that left `next` stays where it was, marked
// leaving, until its exit ends (`expired`); one that comes back reuses it.
function reconcile(prev, nextKeys, expired) {
	const out = nextKeys.map(k => ({ key: k, leaving: false }));
	let anchor = null;
	for (const p of prev) {
		if (nextKeys.indexOf(p.key) >= 0) {
			anchor = p.key;
			continue;
		}
		if (expired.indexOf(p.key) >= 0)
			continue;
		const at = anchor === null ? 0 : out.findIndex(o => o.key === anchor) + 1;
		out.splice(at, 0, { key: p.key, leaving: true });
		anchor = p.key;
	}
	return out;
}

// Left edges of each row in the flex row (gap 12), and its total width.
function layout(keys) {
	const xs = [];
	let x = 0;
	keys.forEach((k, i) => {
		if (i > 0)
			x += GAP;
		xs.push(x);
		x += k === dividerKey ? DIVIDER_SPAN : ICON;
	});
	return { xs: xs, width: x };
}

// Bloom handleAppClick on Hyprland. Cycling uses a stable order: focus
// history would only bounce between the two latest windows.
function clickAction(item, activeAddress) {
	const ws = item.windows;
	if (ws.length === 0)
		return { kind: "launch" };
	const stable = ws.slice().sort((a, b) => a.address < b.address ? -1 : a.address > b.address ? 1 : 0);
	const i = stable.findIndex(w => w.address === activeAddress);
	if (i < 0) {
		const recent = ws.slice().sort((a, b) => a.focus - b.focus);
		return { kind: "focus", address: recent[0].address };
	}
	if (stable.length === 1)
		return { kind: "none" };
	return { kind: "focus", address: stable[(i + 1) % stable.length].address };
}

function dotCount(windows) {
	return Math.min(windows, 3);
}

function isHidden(mode, overlapped, interaction, startupAnimating) {
	if (startupAnimating)
		return false;
	if (mode === "smart")
		return overlapped && interaction === "none";
	if (mode === "peek")
		return interaction === "none";
	return false;
}

// Bloom's motion.div.dock targets (Dock.tsx).
function geometry(s) {
	const shown = s.expanded && !s.hidden && s.visible;
	const attached = (s.impacted || s.expanded) && !s.hidden && s.visible;
	return {
		y: !s.ready ? -800 : s.visible ? (s.hidden ? 100 : 0) : 150,
		width: shown ? (s.adaptive ? s.adaptiveWidth : s.contentWidth) : 34,
		height: shown ? 52 : 34,
		edgeRadius: attached ? 0 : 17,
		farRadius: attached ? 18 : 17,
		opacity: s.visible ? 1 : 0
	};
}

// Nearly full width: 24 px margin per side at the visual (scaled) size.
function adaptiveWidth(viewport, scale) {
	return (viewport - 48 * scale) / scale;
}

// The resting dock in global layout coordinates (logical pixels).
function dockRect(monitor, naturalWidth, uiScale) {
	const logicalWidth = monitor.width / monitor.scale;
	const w = naturalWidth * uiScale;
	const left = monitor.x + (logicalWidth - w) / 2;
	return { left: left, right: left + w, bottom: monitor.y + monitor.height / monitor.scale - monitor.reserved[3] };
}

// Bloom: a maximised or fullscreen window always counts; otherwise the window
// must overlap the dock's span and reach into its 56 px strip (4 px slack).
function overlaps(win, rect, uiScale) {
	if (!win)
		return false;
	if (win.fullscreen > 0)
		return true;
	const triggerY = rect.bottom - 56 * uiScale;
	return win.x < rect.right - 4 && win.x + win.width > rect.left + 4 && win.y + win.height > triggerY + 4;
}

// Hyprland fullscreen state 1 = maximised (2 = fullscreen, 3 = both).
function maximized(win) {
	return !!win && win.fullscreen === 1;
}

function focusedWindow(clients, monitor) {
	return Notch.focusedWindow(clients, monitor);
}

// The Lua dispatch that focuses a window; only Hyprland's hex addresses pass.
function focusArg(address) {
	if (!/^0x[0-9a-f]+$/.test(address || ""))
		return "";
	return 'hl.dsp.focus({ window = "address:' + address + '" })';
}
```

- [ ] **Step 4: Add the tokens**

Add to `Tokens.springs` in `shell/common/tokens.js`:

```js
	// Dock (Bloom Dock.tsx).
	dockY: { stiffness: 400, damping: 35, mass: 0.8 },
	dockSize: { stiffness: 250, damping: 22, mass: 0.8 },
	dockLayout: { stiffness: 300, damping: 25, mass: 1 },
	dockRadius: { stiffness: 500, damping: 30, mass: 1 },
	itemEntry: { stiffness: 400, damping: 25, mass: 1 },
	// framer's defaults for a hover variant: y underdamped, scale critically damped.
	hoverY: { stiffness: 500, damping: 25, mass: 1, restSpeed: 10 },
	hoverScale: { stiffness: 550, damping: 30, mass: 1, restSpeed: 10 }
```

Append:

```js
// Dock (Bloom Dock.tsx/Dock.css @ b5fb962).
var dock = {
	// Fixed surface: full screen width, room for the dock, tooltips and 3C previews.
	surfaceHeight: 420,
	collapsed: 34,
	height: 52,
	padding: 8,
	iconBox: 36,
	iconImage: 28,
	iconOnlyImage: 32,
	iconRadius: 12,
	divider: { width: 1, height: 26, margin: 2, alpha: 0.24 },
	startup: { impactMs: 280, expandMs: 350, animatingMs: 1500 },
	reserve: 56,
	graceMs: 800,
	edgeBand: { height: 2 },
	edgeHandoffMs: 1000,
	opacityMs: 200,
	contentFadeMs: 150,
	entry: { delayMs: 150, fadeMs: 150 },
	exitMs: 450,
	hover: { y: -5, scale: 1.1 },
	tapScale: 0.95,
	dot: { size: 4, gap: 3, offset: 4, glow: 4, glowLight: 3 },
	tooltip: { offset: 36, paddingV: 4, paddingH: 10, radius: 6, size: 12, alpha: 0.7, slide: 4, from: 0.95, fadeMs: 200 },
	fallback: { size: 16, opacity: 0.7 }
};
```

- [ ] **Step 5: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dock.qml 2>&1 | grep -E "FAIL|Totals"; node tests/parity/spring-parity.mjs | tail -6`
Expected: `Totals: 14 passed, 0 failed`; every parity line `ok`.

- [ ] **Step 6: Commit**

```bash
git add shell/modules/dock/dock.js shell/common/tokens.js tests/parity/spring-parity.mjs tests/qml/tst_dock.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Apps service and launching

**Files:**
- Create: `shell/services/launch.js`, `shell/services/Apps.qml`
- Modify: `shell/services/Audio.qml` (`openMixer`), `tests/integration/lib.sh` (`BLOOM_LAUNCH_SCOPE=0`)
- Test: `tests/qml/tst_launch.qml` (new)

**Interfaces:**
- Produces (`launch.js`):
  - `unitName(id, n)` → string such as `app-bloom-org.kde.dolphin-k3x9`;
  - `argv(command, unit, terminal)` → string[] for `Quickshell.execDetached`.
- Produces (`Apps` singleton):
  - `revision: int`, which grows as entries load; bind to it to re-resolve;
  - `idForClass(cls)` → string (an entry id, or `""`);
  - `info(id)` → `{ name, icon }`;
  - `exists(id)` → bool;
  - `launch(id)` → bool;
  - `run(command: string[], name: string)`.

- [ ] **Step 1: Write the failing test**

Create `tests/qml/tst_launch.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/services/launch.js" as Launch

TestCase {
	name: "Launch"

	function test_unitName() {
		verify(/^app-bloom-org\.kde\.dolphin-[0-9a-z]+$/.test(Launch.unitName("org.kde.dolphin", 1792911167)));
		verify(/^app-bloom-weird_name_-[0-9a-z]+$/.test(Launch.unitName("weird name!", 7)), "unit names allow [A-Za-z0-9_.-] only");
	}

	function test_argv() {
		const a = Launch.argv(["firefox", "--new-window"], "app-bloom-firefox-1", false);
		compare(a.slice(0, 2), ["sh", "-c"]);
		compare(a.slice(3), ["sh", "app-bloom-firefox-1", "firefox", "--new-window"], "the command stays argv: no shell quoting of its words");
		verify(a[2].indexOf("systemd-run --user --scope --collect --quiet") >= 0);
		verify(a[2].indexOf('"$BLOOM_LAUNCH_SCOPE" != 0') >= 0, "tests opt out of systemd");
		compare(Launch.argv(["htop"], "u", true).slice(5), ["xdg-terminal-exec", "htop"]);
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launch.qml 2>&1 | tail -2`
Expected: fails to load.

- [ ] **Step 3: Write `launch.js`**

```js
// How Bloom starts apps. Plain JS, shared with the tests.
//
// Each app runs in its own systemd user scope, the way desktop launchers do.
// The shell's own unit kills its whole cgroup on restart (KillMode=
// control-group), so an app started as a child would die with it. Where no
// user systemd answers (containers) the app is simply exec'd.

var SCOPE_SCRIPT = 'u=$1; shift; '
	+ 'if [ "$BLOOM_LAUNCH_SCOPE" != 0 ] && command -v systemd-run >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then '
	+ 'exec systemd-run --user --scope --collect --quiet --unit="$u" -- "$@"; fi; exec "$@"';

function unitName(id, n) {
	return "app-bloom-" + id.replace(/[^A-Za-z0-9_.-]/g, "_") + "-" + Math.floor(n).toString(36);
}

// Terminal=true entries open in the user's terminal (xdg-terminal-exec).
function argv(command, unit, terminal) {
	const cmd = terminal ? ["xdg-terminal-exec"].concat(command) : command;
	return ["sh", "-c", SCOPE_SCRIPT, "sh", unit].concat(cmd);
}
```

- [ ] **Step 4: Run the unit test**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launch.qml 2>&1 | grep -E "FAIL|Totals"`
Expected: `Totals: 4 passed, 0 failed`.

- [ ] **Step 5: Write `Apps.qml`, move the mixer launch, opt tests out of systemd**

Create `shell/services/Apps.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell
import "launch.js" as Launch

// Installed apps (desktop entries) for the dock: names, icons and launching.
// Quickshell fills the entry list gradually after start, so `revision` grows
// as it loads; bind to it to re-resolve names and icons.
Singleton {
	id: root

	readonly property int revision: DesktopEntries.applications.values.length

	function idForClass(cls) {
		const e = DesktopEntries.heuristicLookup(cls);
		return e ? e.id : "";
	}

	function exists(id) {
		return !!DesktopEntries.byId(id);
	}

	function info(id) {
		if (id.startsWith("class:")) {
			const cls = id.slice(6);
			return { name: cls, icon: Quickshell.iconPath(cls, true) };
		}
		const e = DesktopEntries.byId(id);
		return e ? { name: e.name, icon: Quickshell.iconPath(e.icon, true) } : { name: id, icon: "" };
	}

	function launch(id) {
		const e = DesktopEntries.byId(id);
		if (!e || e.command.length === 0)
			return false;
		root.run(e.command, id, e.runInTerminal, e.workingDirectory);
		return true;
	}

	function run(command, name, terminal, workingDirectory) {
		const context = { command: Launch.argv(command, Launch.unitName(name, Date.now()), !!terminal) };
		if (workingDirectory)
			context.workingDirectory = workingDirectory;
		Quickshell.execDetached(context);
	}
}
```

In `shell/services/Audio.qml`, replace the body of `openMixer`:

```qml
	function openMixer() {
		// Its own scope, so the mixer outlives a shell restart.
		if (root.mixer)
			Apps.run([root.mixer], root.mixer);
	}
```

In `tests/integration/lib.sh` `bloom_env`, after the `BLOOM_CHECKUPDATES` line:

```bash
	# Apps launched by the shell in tests stay out of the real user systemd.
	export BLOOM_LAUNCH_SCOPE=0
```

- [ ] **Step 6: Run the suite parts this touches**

Run: `/usr/lib/qt6/bin/qmllint shell/services/Apps.qml shell/services/Audio.qml 2>&1 | grep -iE "error" ; bash tests/integration/test_notch_music.sh 2>&1 | tail -3`
Expected: no lint errors; the music integration test (which loads Audio) ends `ok`.

- [ ] **Step 7: Commit**

```bash
git add shell/services/launch.js shell/services/Apps.qml shell/services/Audio.qml tests/integration/lib.sh tests/qml/tst_launch.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: launch apps in their own systemd scopes

The shell's unit kills its whole cgroup on restart, so an app started as
its child (the notch's mixer button) died with every shell restart.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The dock icon

**Files:**
- Create: `shell/modules/dock/DockIcon.qml`
- Test: `tests/qml/tst_dockicon.qml` (new)

**Interfaces:**
- Consumes: `Tokens.dock`, `Tokens.springs.itemEntry/hoverY/hoverScale`, `Spring`.
- Produces `DockIcon`:
  - Inputs: `name: string`, `iconSource: string`, `windows: int`, `present: bool`, `iconOnly: bool`, `light: bool`, `textColor`, `tooltipBg`, `tooltipText`, `tooltipBorder: color`.
  - Signals: `clicked()`, `middleClicked()`.
  - Readonly: `hovered`, `pressed`, `shown` (entered and present).
  - Child objectNames: `"dock-tile"`, `"dock-image"`, `"dock-fallback"`, `"dock-dots"`, `"dock-tooltip"`, `"dock-lift"` (the moving icon).

- [ ] **Step 1: Write the failing test**

Create `tests/qml/tst_dockicon.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/dock"

Item {
	id: host
	width: 300
	height: 200

	Component {
		id: iconComponent
		DockIcon {
			x: 100
			y: 100
			name: "Firefox"
			present: true
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "DockIcon"
		when: windowShown

		function make(props) {
			mouseMove(host, 0, 0);
			const v = createTemporaryObject(iconComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		// Bloom: items pop in after 150 ms (scale 0 → 1, spring 400/25).
		function test_entryWaitsThenPops() {
			const v = make();
			const lift = findChild(v, "dock-lift");
			wait(60);
			compare(v.shown, false, "still in the entry delay");
			tryCompare(v, "shown", true, 400);
			tryVerify(() => Math.abs(lift.scale - 1) < 0.01, 1500);
		}

		function test_leavingShrinksAway() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			v.present = false;
			tryCompare(v, "shown", false, 400, "after the same 150 ms delay");
			tryVerify(() => findChild(v, "dock-lift").scale < 0.01, 1500);
		}

		function test_hoverLiftsAndPressSinks() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			const lift = findChild(v, "dock-lift");
			wait(600);
			mouseMove(v, 18, 18);
			tryCompare(v, "hovered", true, 500);
			tryVerify(() => Math.abs(lift.y - -5) < 0.05 && Math.abs(lift.scale - 1.1) < 0.005, 1500, "hover: y -5, scale 1.1");
			mousePress(v, 18, 18);
			tryVerify(() => Math.abs(lift.scale - 0.95) < 0.005, 1500, "tap: scale 0.95");
			verify(Math.abs(lift.y - -5) < 0.05, "tap keeps the hover lift (its variant sets only scale)");
			mouseRelease(v, 18, 18);
		}

		function test_tooltipOnHover() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			const tip = findChild(v, "dock-tooltip");
			compare(tip.opacity, 0);
			mouseMove(v, 18, 18);
			tryCompare(tip, "opacity", 1, 600);
			compare(tip.y, -36 + 0, "Bloom: top -36px");
			mouseMove(host, 0, 0);
			tryCompare(tip, "opacity", 0, 600);
		}

		function test_dots() {
			const v = make({ windows: 0 });
			compare(findChild(v, "dock-dots").count, 0);
			v.windows = 2;
			compare(findChild(v, "dock-dots").count, 2);
			v.windows = 9;
			compare(findChild(v, "dock-dots").count, 3, "at most three");
		}

		function test_fallbackLetter() {
			const v = make({ iconSource: "" });
			verify(findChild(v, "dock-fallback").visible);
			compare(findChild(v, "dock-fallback").text, "F");
			compare(findChild(v, "dock-image").visible, false);
		}

		function test_iconOnly() {
			const v = make({ iconOnly: true });
			compare(findChild(v, "dock-tile").visible, false);
			compare(findChild(v, "dock-image").width, 32);
			v.iconOnly = false;
			compare(findChild(v, "dock-image").width, 28);
		}

		function test_clicks() {
			const v = make();
			tryCompare(v, "shown", true, 400);
			const left = createTemporaryObject(spyComponent, host, { target: v, signalName: "clicked" });
			const middle = createTemporaryObject(spyComponent, host, { target: v, signalName: "middleClicked" });
			mouseClick(v, 18, 18);
			compare(left.count, 1);
			mouseClick(v, 18, 18, Qt.MiddleButton);
			compare(middle.count, 1);
			compare(left.count, 1);
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dockicon.qml 2>&1 | tail -2`
Expected: fails to load (`DockIcon` is not a type).

- [ ] **Step 3: Write `DockIcon.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// One dock app (Bloom Dock.tsx .dock-icon-wrapper): the tile and image that
// lift on hover and sink on press, a text tooltip, and one dot per window.
// `present` false plays framer's exit; the dock drops the slot afterwards.
Item {
	id: root

	property string name: ""
	property string iconSource: ""
	property int windows: 0
	property bool present: true
	property bool iconOnly: false
	property bool light: false
	property color textColor: "white"
	property color tooltipBg: Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
	property color tooltipText: "white"
	property color tooltipBorder: "transparent"

	signal clicked()
	signal middleClicked()

	readonly property bool hovered: hover.hovered
	readonly property bool pressed: tap.pressed
	property bool shown: false

	implicitWidth: Tokens.dock.iconBox
	implicitHeight: Tokens.dock.iconBox

	// Entry and exit both wait 150 ms (Bloom's transition delay), then the
	// scale springs 400/25 and the opacity fades over 150 ms.
	Component.onCompleted: if (root.present) delay.restart()
	onPresentChanged: delay.restart()
	Timer {
		id: delay
		interval: Tokens.dock.entry.delayMs
		onTriggered: root.shown = root.present
	}

	HoverHandler { id: hover }
	TapHandler {
		id: tap
		acceptedButtons: Qt.LeftButton
		onTapped: root.clicked()
	}
	TapHandler {
		acceptedButtons: Qt.MiddleButton
		onTapped: root.middleClicked()
	}

	Item {
		id: presence
		anchors.fill: parent
		opacity: root.shown ? 1 : 0
		Behavior on opacity {
			NumberAnimation { duration: Tokens.dock.entry.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
		}
		scale: entrySpring.value

		Spring {
			id: entrySpring
			stiffness: Tokens.springs.itemEntry.stiffness
			damping: Tokens.springs.itemEntry.damping
			initial: 0
			target: root.shown ? 1 : 0
		}

		Item {
			id: lift
			objectName: "dock-lift"
			width: parent.width
			height: parent.height
			y: liftY.value
			scale: liftScale.value

			Spring {
				id: liftY
				stiffness: Tokens.springs.hoverY.stiffness
				damping: Tokens.springs.hoverY.damping
				restSpeed: Tokens.springs.hoverY.restSpeed
				initial: 0
				target: root.hovered && root.shown ? Tokens.dock.hover.y : 0
			}
			Spring {
				id: liftScale
				stiffness: Tokens.springs.hoverScale.stiffness
				damping: Tokens.springs.hoverScale.damping
				restSpeed: Tokens.springs.hoverScale.restSpeed
				initial: 1
				target: root.pressed ? Tokens.dock.tapScale : root.hovered && root.shown ? Tokens.dock.hover.scale : 1
			}

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
				objectName: "dock-tile"
				anchors.fill: parent
				visible: !root.iconOnly
				radius: Tokens.dock.iconRadius
				// Bloom's 135° gradient, vertical (a QML Gradient is not angled).
				gradient: Gradient {
					GradientStop { position: 0; color: root.light ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.2) }
					GradientStop { position: 1; color: root.light ? Qt.rgba(0, 0, 0, 0.01) : Qt.rgba(1, 1, 1, 0.05) }
				}
			}

			Image {
				id: image
				objectName: "dock-image"
				anchors.centerIn: parent
				width: root.iconOnly ? Tokens.dock.iconOnlyImage : Tokens.dock.iconImage
				height: width
				sourceSize: Qt.size(width * 2, height * 2)
				source: root.iconSource
				visible: root.iconSource !== "" && image.status !== Image.Error
				fillMode: Image.PreserveAspectFit
				smooth: true
				asynchronous: true
			}

			Text {
				objectName: "dock-fallback"
				anchors.centerIn: parent
				visible: !image.visible
				text: root.name.slice(0, 1).toUpperCase()
				color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, Tokens.dock.fallback.opacity)
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.fallback.size
				font.weight: Font.DemiBold
			}
		}

		// Dots stay put while the icon lifts (Bloom: siblings of .dock-icon).
		Row {
			anchors.horizontalCenter: parent.horizontalCenter
			y: parent.height + Tokens.dock.dot.offset - Tokens.dock.dot.size
			spacing: Tokens.dock.dot.gap

			Repeater {
				objectName: "dock-dots"
				model: Dock.dotCount(root.windows)

				Item {
					width: Tokens.dock.dot.size
					height: Tokens.dock.dot.size

					RectangularShadow {
						anchors.fill: parent
						radius: width / 2
						blur: root.light ? Tokens.dock.dot.glowLight : Tokens.dock.dot.glow
						color: root.light ? root.textColor : Qt.rgba(1, 1, 1, 0.8)
					}
					Rectangle {
						anchors.fill: parent
						radius: width / 2
						color: root.light ? root.textColor : "white"
					}
				}
			}
		}
	}

	// Bloom .tooltip: 36 px above, fades and rises 4 px with CSS `ease`.
	Rectangle {
		id: tip
		objectName: "dock-tooltip"
		readonly property bool showing: root.hovered && root.shown
		x: (root.width - width) / 2
		y: -Tokens.dock.tooltip.offset
		z: 1
		width: label.implicitWidth + 2 * Tokens.dock.tooltip.paddingH
		height: label.implicitHeight + 2 * Tokens.dock.tooltip.paddingV
		radius: Tokens.dock.tooltip.radius
		color: root.tooltipBg
		border.width: root.light ? 1 : 0
		border.color: root.tooltipBorder
		opacity: tip.showing ? 1 : 0
		transform: [
			Scale {
				origin.x: tip.width / 2
				origin.y: tip.height / 2
				xScale: tip.showing ? 1 : Tokens.dock.tooltip.from
				yScale: xScale
				Behavior on xScale { NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
			},
			Translate {
				y: tip.showing ? 0 : Tokens.dock.tooltip.slide
				Behavior on y { NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
			}
		]
		Behavior on opacity {
			NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] }
		}

		Text {
			id: label
			anchors.centerIn: parent
			text: root.name
			color: root.tooltipText
			font.family: Tokens.type.family
			font.pixelSize: Tokens.dock.tooltip.size
		}
	}
}
```

The `Repeater` with objectName `dock-dots` exposes `count`, which the test reads.

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dockicon.qml 2>&1 | grep -E "FAIL|Totals"`
Expected: `Totals: 10 passed, 0 failed`.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/dock/DockIcon.qml tests/qml/tst_dockicon.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock icon

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The dock view

**Files:**
- Create: `shell/modules/dock/DockView.qml`
- Test: `tests/qml/tst_dockview.qml` (new)

**Interfaces:**
- Consumes: `dock.js` (Task 2), `DockIcon` (Task 4), `EdgeSurface`, `Spring`, tokens.
- Produces `DockView`:
  - **Inputs:**
    - `mode`, `edgeDelay`, `uiScale`;
    - `overlapped`, `maximized`, `adaptiveEnabled`, `userVisible`, `suppressed`;
    - `iconOnly`, `separatorEnabled`, `items: { pinned, unpinned }`;
    - `bg`, `textColor`, `tooltipBg`, `tooltipText`, `tooltipBorder`, `light`;
    - `ready` (set by the window).
  - **Signals:** `activated(string id)`, `newInstance(string id)`.
  - **Readonly:** `hidden`, `bandActive`, `hitItem`, `bandItem`, `naturalWidth` (content width incl. padding), `target`.
  - **Method:** `stateObject()` → `{ mode, hidden, interaction, overlapped, visible, expanded, adaptive, width, height, y, keys }`.

- [ ] **Step 1: Write the failing tests**

Create `tests/qml/tst_dockview.qml`:

```qml
import QtQuick
import QtTest
import "../../shell/modules/dock"

Item {
	id: host
	width: 1000
	height: 420

	function app(id, windows) {
		return { id: id, name: id, icon: "", windows: windows || [] };
	}

	Component {
		id: viewComponent
		DockView {
			width: 1000
			height: 420
			mode: "fixed"
			items: ({ pinned: [host.app("a"), host.app("b", [{ address: "0x1", focus: 0 }])], unpinned: [host.app("c", [{ address: "0x2", focus: 1 }])] })
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "DockView"
		when: windowShown

		function make(props) {
			mouseMove(host, 0, 0);
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		function settle(v) {
			v.ready = true;
			tryCompare(v, "expanded", true, 1000);
			tryCompare(v, "startupAnimating", false, 3000);
		}

		function test_startup() {
			const v = make();
			compare(v.target.y, -800, "parked above before ready");
			v.ready = true;
			compare(v.target.y, 0);
			compare(v.target.width, 34);
			tryCompare(v, "impacted", true, 1000);
			tryCompare(v, "expanded", true, 1000);
			compare(v.target.height, 52);
			compare(v.target.width, 36 * 3 + 12 * 3 + 5 + 16, "three icons, a divider, gaps and padding");
		}

		function test_separatorSetting() {
			const v = make({ separatorEnabled: false });
			settle(v);
			compare(v.target.width, 36 * 3 + 12 * 2 + 16);
			compare(v.stateObject().keys, ["a", "b", "c"]);
		}

		function test_peekHidesUntilTheEdgeDwell() {
			const v = make({ mode: "peek", edgeDelay: 100 });
			settle(v);
			tryCompare(v, "hidden", true, 3000);
			compare(v.target.y, 100);
			verify(v.bandActive);
			const band = v.bandItem;
			mouseMove(band, band.width / 2, 1);
			tryCompare(v, "hidden", false, 1000, "revealed after the dwell");
		}

		function test_smartFollowsOverlapWithGrace() {
			const v = make({ mode: "smart" });
			settle(v);
			v.overlapped = true;
			tryCompare(v, "hidden", true, 1000);
			v.overlapped = false;
			compare(v.hidden, false);
		}

		function test_adaptive() {
			const v = make({ adaptiveEnabled: true, maximized: true });
			settle(v);
			compare(v.target.width, 1000 - 48, "nearly full width");
			v.mode = "smart";
			v.maximized = false;
			compare(v.target.width, v.naturalWidth, "fixed mode only");
		}

		function test_userVisibility() {
			const v = make();
			settle(v);
			v.userVisible = false;
			compare(v.target.y, 150);
			compare(v.target.opacity, 0);
		}

		function test_addAndRemoveItems() {
			const v = make();
			settle(v);
			v.items = { pinned: [host.app("a"), host.app("b")], unpinned: [host.app("c"), host.app("d", [{ address: "0x3", focus: 2 }])] };
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c", "d"]);
			v.items = { pinned: [host.app("a"), host.app("b")], unpinned: [host.app("d", [{ address: "0x3", focus: 2 }])] };
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c", "d"], "c is still leaving");
			tryVerify(() => v.stateObject().keys.length === 4, 1500, "removed once its exit has played");
			compare(v.stateObject().keys, ["a", "b", "|divider|", "d"]);
		}

		// Review focus 2.
		function test_reopenDuringExitReusesTheSlot() {
			const v = make();
			settle(v);
			const withC = v.items;
			v.items = { pinned: withC.pinned, unpinned: [] };
			wait(100);
			v.items = withC;
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c"], "one c, back in its place");
			wait(800);
			compare(v.stateObject().keys, ["a", "b", "|divider|", "c"]);
		}

		function test_clicksReachTheDock() {
			const v = make();
			settle(v);
			wait(500);
			const activated = createTemporaryObject(spyComponent, host, { target: v, signalName: "activated" });
			const newInstance = createTemporaryObject(spyComponent, host, { target: v, signalName: "newInstance" });
			const hit = v.hitItem;
			const first = hit.mapToItem(v, 8 + 18, 8 + 18);
			mouseClick(v, first.x, first.y);
			compare(activated.count, 1);
			compare(activated.signalArguments[0][0], "a");
			mouseClick(v, first.x, first.y, Qt.MiddleButton);
			compare(newInstance.signalArguments[0][0], "a");
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function settleFrames() {
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
		}

		function test_idleDockDrawsNoFrames() {
			const v = make();
			settle(v);
			settleFrames();
			compare(framesIn(1000), 0);
		}

		// Review focus 3: smart mode's poll re-sends equal window data every second.
		function test_identicalItemsDrawNoFrames() {
			const v = make();
			settle(v);
			settleFrames();
			const same = JSON.stringify(v.items);
			let n = 0;
			const churn = () => { v.items = JSON.parse(same); };
			for (let i = 0; i < 5; i++) {
				churn();
				n += framesIn(200);
			}
			compare(n, 0);
		}

		function test_hiddenDockDrawsNoFrames() {
			const v = make({ mode: "peek" });
			settle(v);
			tryCompare(v, "hidden", true, 3000);
			settleFrames();
			compare(framesIn(1000), 0);
		}
	}
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dockview.qml 2>&1 | tail -2`
Expected: fails to load (`DockView` is not a type).

- [ ] **Step 3: Write `DockView.qml`**

```qml
import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// Bloom's dock (Dock.tsx @ b5fb962): a bottom-edge pill that drops in, then
// expands into the app row; fixed/smart/peek modes with an edge reveal and
// an adaptive full width. Pure UI: DockWindow feeds it items and overlap.
Item {
	id: root

	property string mode: "smart"
	property int edgeDelay: 200
	property real uiScale: 1
	property bool overlapped: false
	property bool maximized: false
	property bool adaptiveEnabled: false
	property bool userVisible: true
	property bool suppressed: false
	property bool iconOnly: false
	property bool separatorEnabled: true
	property var items: ({ pinned: [], unpinned: [] })
	property color bg: Qt.rgba(0, 0, 0, 0.8)
	property color textColor: "white"
	property color tooltipBg: Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
	property color tooltipText: "white"
	property color tooltipBorder: "transparent"
	property bool light: false

	signal activated(string id)
	signal newInstance(string id)

	property bool ready: false
	property bool impacted: false
	property bool expanded: false
	property bool startupAnimating: false
	property bool edgeArmed: false
	property string interaction: "none"

	readonly property bool pillHovered: pillHover.hovered
	readonly property bool hidden: Dock.isHidden(root.mode, root.overlapped, root.interaction, root.startupAnimating)
	readonly property real naturalWidth: root._layout.width + 2 * Tokens.dock.padding
	readonly property bool adaptive: root.adaptiveEnabled && root.mode === "fixed" && root.maximized
		&& root.expanded && !root.hidden && root.userVisible
	readonly property var target: Dock.geometry({
		ready: root.ready, visible: root.userVisible, hidden: root.hidden, expanded: root.expanded,
		impacted: root.impacted, contentWidth: root.naturalWidth, adaptive: root.adaptive,
		adaptiveWidth: Dock.adaptiveWidth(root.width, root.uiScale)
	})
	readonly property bool bandActive: root.hidden && root.mode !== "fixed" && root.userVisible && !root.suppressed
	readonly property Item hitItem: pillArea
	readonly property Item bandItem: band

	function stateObject() {
		return {
			mode: root.mode, hidden: root.hidden, interaction: root.interaction, overlapped: root.overlapped,
			visible: root.userVisible, expanded: root.expanded, adaptive: root.adaptive,
			width: root.target.width, height: root.target.height, y: root.target.y,
			keys: root._rows.map(r => r.key)
		};
	}

	// Startup (Bloom: impacted at 280 ms, expanded at 350 ms, done at 1500 ms).
	onReadyChanged: {
		if (!root.ready)
			return;
		root.startupAnimating = true;
		impactTimer.restart();
		expandTimer.restart();
		startupTimer.restart();
	}
	Timer { id: impactTimer; interval: Tokens.dock.startup.impactMs; onTriggered: root.impacted = true }
	Timer { id: expandTimer; interval: Tokens.dock.startup.expandMs; onTriggered: root.expanded = true }
	Timer { id: startupTimer; interval: Tokens.dock.startup.animatingMs; onTriggered: root.startupAnimating = false }

	// Interaction and its 800 ms grace (Bloom interactionState).
	readonly property bool _anyInteraction: root.pillHovered || root.edgeArmed
	on_AnyInteractionChanged: {
		if (root._anyInteraction) {
			graceTimer.stop();
			root.interaction = "active";
		} else if (root.interaction !== "none") {
			root.interaction = "grace";
			graceTimer.restart();
		}
	}
	Timer { id: graceTimer; interval: Tokens.dock.graceMs; onTriggered: root.interaction = "none" }

	// An edge reveal lets go once the pointer reaches the pill, or after the
	// hand-off time if it never does (Wayland reports hover only on movement).
	onBandActiveChanged: if (!root.bandActive && root.edgeArmed) handoff.restart()
	onPillHoveredChanged: if (root.pillHovered) { handoff.stop(); root.edgeArmed = false; }
	Timer { id: handoff; interval: Tokens.dock.edgeHandoffMs; onTriggered: root.edgeArmed = false }

	// Slots: the row's items with framer AnimatePresence. A leaving slot keeps
	// its place until its exit has played (exitMs), then the row closes up.
	ListModel { id: slotModel }
	property var _rows: []
	property var _leftAt: ({})
	property var _layout: ({ xs: [], width: 0 })

	function _sync() {
		const next = Dock.slots(root.items, root.separatorEnabled);
		const byKey = {};
		for (const s of next)
			byKey[s.key] = s;
		const now = Date.now();
		const expired = root._rows
			.filter(r => r.key === Dock.dividerKey || (r.leaving && now - (root._leftAt[r.key] ?? now) >= Tokens.dock.exitMs))
			.map(r => r.key);
		const rows = Dock.reconcile(root._rows, next.map(s => s.key), expired);
		const leftAt = {};
		for (const r of rows)
			if (r.leaving)
				leftAt[r.key] = root._leftAt[r.key] ?? now;
		const lay = Dock.layout(rows.map(r => r.key));

		for (let i = slotModel.count - 1; i >= 0; i--)
			if (!rows.some(r => r.key === slotModel.get(i).key))
				slotModel.remove(i);
		rows.forEach((r, i) => {
			let j = -1;
			for (let k = 0; k < slotModel.count; k++)
				if (slotModel.get(k).key === r.key) { j = k; break; }
			const s = byKey[r.key];
			if (j < 0) {
				slotModel.insert(i, { key: r.key, kind: s.kind, name: s.name, icon: s.icon, windows: s.windows, present: true, slotX: lay.xs[i] });
				return;
			}
			if (j !== i)
				slotModel.move(j, i, 1);
			if (s) {
				if (slotModel.get(i).name !== s.name) slotModel.setProperty(i, "name", s.name);
				if (slotModel.get(i).icon !== s.icon) slotModel.setProperty(i, "icon", s.icon);
				if (slotModel.get(i).windows !== s.windows) slotModel.setProperty(i, "windows", s.windows);
			}
			if (slotModel.get(i).present !== !r.leaving) slotModel.setProperty(i, "present", !r.leaving);
			if (slotModel.get(i).slotX !== lay.xs[i]) slotModel.setProperty(i, "slotX", lay.xs[i]);
		});

		root._rows = rows;
		root._leftAt = leftAt;
		if (JSON.stringify(lay) !== JSON.stringify(root._layout))
			root._layout = lay;
		if (rows.some(r => r.leaving))
			exitTimer.restart();
	}
	onItemsChanged: root._sync()
	onSeparatorEnabledChanged: root._sync()
	Component.onCompleted: root._sync()
	Timer { id: exitTimer; interval: Tokens.dock.exitMs; onTriggered: root._sync() }

	Spring {
		id: wS
		stiffness: Tokens.springs.dockSize.stiffness
		damping: Tokens.springs.dockSize.damping
		mass: Tokens.springs.dockSize.mass
		initial: Tokens.dock.collapsed
		target: root.target.width
	}
	Spring {
		id: hS
		stiffness: Tokens.springs.dockSize.stiffness
		damping: Tokens.springs.dockSize.damping
		mass: Tokens.springs.dockSize.mass
		initial: Tokens.dock.collapsed
		target: root.target.height
	}
	Spring {
		id: yS
		stiffness: Tokens.springs.dockY.stiffness
		damping: Tokens.springs.dockY.damping
		mass: Tokens.springs.dockY.mass
		initial: -800
		target: root.target.y
	}
	Spring {
		id: edgeR
		stiffness: Tokens.springs.dockRadius.stiffness
		damping: Tokens.springs.dockRadius.damping
		initial: 17
		target: root.target.edgeRadius
	}
	Spring {
		id: farR
		stiffness: Tokens.springs.dockRadius.stiffness
		damping: Tokens.springs.dockRadius.damping
		initial: 17
		target: root.target.farRadius
	}

	Item {
		id: stage
		anchors.fill: parent
		scale: root.uiScale
		transformOrigin: Item.Bottom

		Item {
			id: pillLayer
			anchors.fill: parent
			opacity: root.target.opacity
			Behavior on opacity {
				NumberAnimation { duration: Tokens.dock.opacityMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
			}

			EdgeSurface {
				x: (stage.width - width) / 2
				y: stage.height - height + yS.value
				edge: "bottom"
				pillWidth: Math.max(0, wS.value)
				pillHeight: Math.max(0, hS.value)
				edgeRadius: edgeR.value
				farRadius: farR.value
				flares: root.expanded && !root.hidden
				color: root.bg
			}
		}

		// The pill's box: hover, input mask and the app row.
		Item {
			id: pillArea
			x: (stage.width - width) / 2
			y: stage.height - height + yS.value
			width: Math.max(0, wS.value)
			height: Math.max(0, hS.value)
			opacity: pillLayer.opacity

			HoverHandler { id: pillHover }

			Item {
				id: row
				x: (pillArea.width - width) / 2
				y: Tokens.dock.padding
				width: root._layout.width
				height: Tokens.dock.iconBox
				opacity: root.expanded ? 1 : 0
				Behavior on opacity {
					NumberAnimation { duration: Tokens.dock.contentFadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
				}

				Repeater {
					model: slotModel

					delegate: Item {
						id: slot
						required property string key
						required property string kind
						required property string name
						required property string icon
						required property int windows
						required property bool present
						required property real slotX

						x: xSpring.value
						width: slot.kind === "divider" ? 5 : Tokens.dock.iconBox
						height: Tokens.dock.iconBox
						z: icon.hovered ? 1 : 0

						Spring {
							id: xSpring
							stiffness: Tokens.springs.dockLayout.stiffness
							damping: Tokens.springs.dockLayout.damping
							initial: slot.slotX
							target: slot.slotX
						}

						Rectangle {
							visible: slot.kind === "divider"
							x: Tokens.dock.divider.margin
							anchors.verticalCenter: parent.verticalCenter
							width: Tokens.dock.divider.width
							height: Tokens.dock.divider.height
							radius: 1
							color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, Tokens.dock.divider.alpha)
						}

						DockIcon {
							id: icon
							anchors.fill: parent
							visible: slot.kind === "app"
							name: slot.name
							iconSource: slot.icon
							windows: slot.windows
							present: slot.present && root.expanded
							iconOnly: root.iconOnly
							light: root.light
							textColor: root.textColor
							tooltipBg: root.tooltipBg
							tooltipText: root.tooltipText
							tooltipBorder: root.tooltipBorder
							onClicked: root.activated(slot.key)
							onMiddleClicked: root.newInstance(slot.key)
						}
					}
				}
			}
		}

		// Reveal band: a 2 px strip across the resting dock (Wayland only
		// senses the pointer inside our input region).
		Item {
			id: band
			x: (stage.width - width) / 2
			y: stage.height - height
			width: root.naturalWidth
			height: Tokens.dock.edgeBand.height
			HoverHandler { id: bandHover }
			Timer {
				interval: root.edgeDelay
				running: root.bandActive && bandHover.hovered
				onTriggered: root.edgeArmed = true
			}
		}
	}
}
```

- [ ] **Step 4: Run the tests**

Run: `/usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_dockview.qml 2>&1 | grep -E "FAIL|Totals|Actual|Expected"`
Expected: `Totals: 14 passed, 0 failed`.

- [ ] **Step 5: Mutation-check the frame tests**

Temporarily change the slot `Spring`'s `target` to `slot.slotX + Math.random()`, and re-run `test_identicalItemsDrawNoFrames` and `test_idleDockDrawsNoFrames`. Expected: both FAIL with frames counted. Revert, and ledger the result.

- [ ] **Step 6: Commit**

```bash
git add shell/modules/dock/DockView.qml tests/qml/tst_dockview.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock view

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Dock service, windows, shortcuts and IPC

**Files:**
- Create: `shell/services/Dock.qml`, `shell/modules/dock/DockWindow.qml`, `shell/modules/dock/DockShortcuts.qml`, `tests/integration/fixtures/applications/bloom-test-app.desktop`, `tests/integration/test_dock.sh`
- Modify: `shell/shell.qml` (a LazyLoader of dock windows; the `dock` IpcHandler)
- Test: `tests/integration/test_dock.sh`

**Interfaces:**
- Consumes: `Apps` (Task 3), `dock.js` (Task 2), `DockView` (Task 5), `HyprState`, `StateFile`, `Settings`, `Theme`.
- Produces:
  - **`Dock` singleton:**
    - `pinned: string[]`, `items: { pinned, unpinned }`;
    - `pin(id)` → string (`"ok"` / `"unknown app"` / `"already pinned"`); `unpin(id)` → string;
    - `activate(id)`, `newInstance(id)`, `activateSlot(n)` (1-based among pinned) → string: `"ok"`, `"cannot launch"` (no entry loaded yet), `"no such app"` or `"no app in slot n"`.
  - **IPC `dock`:**
    - `state()` → JSON array per screen of `DockView.stateObject()` plus `{ pinned }`;
    - `pin(id)`, `unpin(id)`, `activate(n: int)`, `setVisible(visible: bool)`.

- [ ] **Step 1: Write the failing integration test**

Create `tests/integration/fixtures/applications/bloom-test-app.desktop`:

```ini
[Desktop Entry]
Type=Application
Name=Bloom Test App
Exec=touch @LAUNCHED@ %U
Icon=bloom-test-app
```

Create `tests/integration/test_dock.sh`:

```bash
#!/usr/bin/env bash
# The dock on headless sway: it loads per screen, shows pins from the state
# file, pins and unpins over IPC, launches the pinned app (Super+Alt+N's
# action) and changes mode live, with no warnings. No Hyprland here, so no
# running windows and no global shortcuts.
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
if ! command -v sway >/dev/null; then
	[[ "${CI:-}" == true ]] && { echo "sway is required in CI" >&2; exit 1; }
	echo "skipped: sway not installed"
	exit 0
fi
bloom_env
start_sway

mkdir -p "$TEST_TMP/data/applications" "$XDG_CONFIG_HOME/bloom" "$XDG_STATE_HOME/bloom"
# Desktop-entry Exec has its own quoting rules, so the fixture takes a plain
# path (mktemp paths have no spaces).
sed "s|@LAUNCHED@|$TEST_TMP/launched|" "$ROOT/tests/integration/fixtures/applications/bloom-test-app.desktop" \
	>"$TEST_TMP/data/applications/bloom-test-app.desktop"
export XDG_DATA_HOME="$TEST_TMP/data" XDG_DATA_DIRS="$TEST_TMP/data"
printf '{ "bloom-enabled-modules": ["dock"], "bloom-weather-enabled": false, "bloom-dock-mode": "fixed" }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
printf '{ "pinned": ["bloom-test-app"] }\n' >"$XDG_STATE_HOME/bloom/dock.json"
start_shell

state() { ipc dock state | jq -c ".[0] | {$1}"; }
state_is() { [[ "$(state "$1")" == "$2" ]]; }

wait_for "the dock to settle with its pin" state_is "keys,height,y" '{"keys":["bloom-test-app"],"height":52,"y":0}'
pass "dock loads and shows the pinned app"

assert_eq "$(ipc dock pin nope)" "unknown app" "pin of a missing entry"
assert_eq "$(ipc dock pin bloom-test-app)" "already pinned" "double pin"
pass "pin refuses unknown and duplicate ids"

# Desktop entries load after start; activate answers "cannot launch" until then.
wait_for "activating slot 1 to launch the app" ipc_equals ok dock activate 1
wait_for "the app to run" test -f "$TEST_TMP/launched"
pass "activating a pinned app that isn't running launches it"
assert_eq "$(ipc dock activate 5)" "no app in slot 5" "empty slot"

assert_eq "$(ipc dock unpin bloom-test-app)" "ok" "unpin"
wait_for "the pin to leave" state_is "keys" '{"keys":[]}'
wait_for "the state file to drop it" grep -q '"pinned": \[\]' "$XDG_STATE_HOME/bloom/dock.json"
ipc dock pin bloom-test-app >/dev/null
wait_for "the pin to return" state_is "keys" '{"keys":["bloom-test-app"]}'
pass "pin and unpin persist to dock.json"

ipc settings set bloom-dock-mode peek >/dev/null
wait_for "peek mode to hide the dock" state_is "hidden,y" '{"hidden":true,"y":100}'
ipc settings set bloom-dock-mode smart >/dev/null
wait_for "smart mode without Hyprland to show it" state_is "hidden,overlapped" '{"hidden":false,"overlapped":false}'
pass "modes change live"

assert_eq "$(ipc dock setVisible false)" "ok" "setVisible"
wait_for "hiding by the user" state_is "visible,y" '{"visible":false,"y":150}'
ipc dock setVisible true >/dev/null

problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
if [[ ! -S /run/dbus/system_bus_socket ]]; then
	problems="$(grep -viE 'upower|powerprofiles|dbus' <<<"$problems" || true)"
fi
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no warnings or errors in the shell log"
```

Check the JSON form that `StateFile`'s serializer writes (`grep -n "stringify" shell/services/state.js`). If it writes `"pinned":[]` without spaces, adjust the `grep` pattern to match it, and ledger the change.

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/integration/test_dock.sh`
Expected: FAIL at "the dock to settle" (`dock state` → "Target not found.").

- [ ] **Step 3: Write `Dock.qml`**

Create `shell/services/Dock.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dock/dock.js" as Logic

// The dock's apps (Bloom Dock.tsx): pins from $XDG_STATE_HOME/bloom/dock.json
// and the running windows Hyprland reports, grouped by app. Every screen's
// dock shows the same items (spec D8).
Singleton {
	id: root

	readonly property var pinned: pins.value.pinned ?? []
	property var _order: []
	readonly property var groups: Logic.groupWindows(HyprState.clients, cls => Logic.identity(cls, root._idFor(cls)))
	readonly property var items: {
		Apps.revision; // re-resolve names and icons as desktop entries load
		return Logic.buildItems(root.pinned, root.groups, root._order, id => Apps.info(id));
	}

	function _idFor(cls) {
		Apps.revision;
		return Apps.idForClass(cls);
	}

	onGroupsChanged: {
		const next = Logic.nextOrder(root._order, root.groups.map(g => g.id));
		if (JSON.stringify(next) !== JSON.stringify(root._order))
			root._order = next;
	}

	function pin(id) {
		if (root.pinned.indexOf(id) >= 0)
			return "already pinned";
		if (!Apps.exists(id))
			return "unknown app";
		pins.save({ pinned: root.pinned.concat([id]) });
		return "ok";
	}

	function unpin(id) {
		if (root.pinned.indexOf(id) < 0)
			return "not pinned";
		pins.save({ pinned: root.pinned.filter(p => p !== id) });
		return "ok";
	}

	function _item(id) {
		return root.items.pinned.concat(root.items.unpinned).find(i => i.id === id) ?? null;
	}

	function activate(id) {
		const item = root._item(id);
		if (!item)
			return "no such app";
		const active = HyprState.clients.reduce((best, c) => best === null || c.focusHistoryID < best.focusHistoryID ? c : best, null);
		const action = Logic.clickAction(item, active ? active.address : "");
		if (action.kind === "launch")
			return Apps.launch(id) ? "ok" : "cannot launch";
		if (action.kind === "focus")
			root._focus(action.address);
		return "ok";
	}

	function newInstance(id) {
		return Apps.launch(id) ? "ok" : "cannot launch";
	}

	function activateSlot(n) {
		const item = root.items.pinned[n - 1];
		return item ? root.activate(item.id) : `no app in slot ${n}`;
	}

	function _focus(address) {
		const arg = Logic.focusArg(address);
		if (!arg || focusProc.running)
			return;
		focusProc.command = ["hyprctl", "dispatch", arg];
		focusProc.running = true;
	}

	Process { id: focusProc }

	StateFile {
		id: pins
		name: "dock"
		defaultValue: ({ pinned: [] })
	}
}
```

Notes:
- `HyprState.clients` is `[]` outside Hyprland, so pins still work there (Review Focus 4).
- `activate` finds the active window as the client with the lowest `focusHistoryID`. Hyprland's focus history is global.

- [ ] **Step 4: Write `DockShortcuts.qml` and `DockWindow.qml`**

Create `shell/modules/dock/DockShortcuts.qml`:

```qml
import QtQuick
import Quickshell.Hyprland
import qs.services

// Super+Alt+1–9 (D12) as Hyprland global shortcuts bloom:dock-1…9, bound in
// the Hyprland config. In its own file so the Hyprland module is only
// touched under Hyprland.
Item {
	Repeater {
		model: 9

		Item {
			required property int index

			GlobalShortcut {
				appid: "bloom"
				name: "dock-" + (index + 1)
				description: "Bloom dock: activate pinned app " + (index + 1)
				onPressed: Dock.activateSlot(index + 1)
			}
		}
	}
}
```

Create `shell/modules/dock/DockWindow.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/tokens.js" as Tokens
import "dock.js" as Logic

// One dock per screen: a full-width bottom layer surface of fixed height (it
// never resizes, spec §3.3) whose input mask is the pill, or the edge band
// while hidden. Fixed mode reserves Bloom's 56 px strip.
PanelWindow {
	id: win

	required property var modelData
	readonly property alias view: view
	readonly property string _key: "dock-" + win.modelData.name

	screen: win.modelData
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	implicitHeight: Tokens.dock.surfaceHeight
	color: "transparent"
	exclusiveZone: view.mode === "fixed" && view.userVisible ? Math.round(Tokens.dock.reserve * view.uiScale) : 0
	WlrLayershell.namespace: "bloom:dock"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	mask: Region {
		item: view.bandActive ? view.bandItem : (view.hidden ? null : view.hitItem)
	}

	readonly property var _monitor: HyprState.monitors.find(m => m.name === win.modelData.name) ?? null
	readonly property var _focused: win._monitor !== null ? Logic.focusedWindow(HyprState.clients, win._monitor) : null
	readonly property bool _overlapped: view.mode === "smart" && win._monitor !== null
		&& Logic.overlaps(win._focused, Logic.dockRect(win._monitor, view.naturalWidth, view.uiScale), view.uiScale)

	// Smart mode needs window positions every second; otherwise Hyprland's
	// events keep the window list current.
	readonly property string _hyprNeed: view.mode === "smart" ? "poll" : "events"
	on_HyprNeedChanged: HyprState.hold(win._key, win._hyprNeed)
	Component.onCompleted: {
		HyprState.hold(win._key, win._hyprNeed);
		readyTimer.start();
	}
	Component.onDestruction: HyprState.hold(win._key, "")

	Timer {
		id: readyTimer
		interval: 50
		onTriggered: view.ready = true
	}

	DockView {
		id: view
		anchors.fill: parent
		mode: Settings.values["bloom-dock-mode"]
		edgeDelay: Settings.values["bloom-dock-edge-delay"]
		uiScale: Settings.values["bloom-scale"]
		iconOnly: Settings.values["bloom-dock-icon-only"]
		separatorEnabled: Settings.values["bloom-dock-separator-enabled"]
		adaptiveEnabled: Settings.values["bloom-dock-adaptive"]
		overlapped: win._overlapped
		maximized: Logic.maximized(win._focused)
		items: Dock.items
		bg: Theme.bg
		textColor: Theme.text
		light: Theme.isLight
		tooltipBg: Theme.isLight ? Theme.bgExpanded : Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
		tooltipText: Theme.text
		tooltipBorder: Theme.border
		onActivated: id => Dock.activate(id)
		onNewInstance: id => Dock.newInstance(id)
	}
}
```

- [ ] **Step 5: Wire `shell.qml`**

After the notch `LazyLoader` in `shell/shell.qml`:

```qml
	LazyLoader {
		id: dockLoader
		active: _modules.indexOf("dock") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/dock/DockWindow.qml"), { modelData: modelData })
			}
		}
	}

	// Super+Alt+1–9, only under Hyprland, with the dock and the setting on.
	LazyLoader {
		active: _modules.indexOf("dock") >= 0 && HyprState.available && Settings.values["bloom-dock-win-number-enabled"]
		source: Qt.resolvedUrl("modules/dock/DockShortcuts.qml")
	}
```

(`LazyLoader` has `source`, checked in Quickshell's qmltypes.)

After the `notch` IpcHandler:

```qml
	IpcHandler {
		target: "dock"

		function _windows() {
			const variants = dockLoader.item;
			return variants ? variants.instances.map(loader => loader.item).filter(Boolean) : [];
		}

		// One state object per screen, in screen order.
		function state(): string {
			return JSON.stringify(_windows().map(w => Object.assign(w.view.stateObject(), { pinned: Dock.pinned })));
		}

		// `id` is a desktop entry id (as in its .desktop file name).
		function pin(id: string): string {
			return Dock.pin(id);
		}

		function unpin(id: string): string {
			return Dock.unpin(id);
		}

		// Pinned app `n` (1-based), as Super+Alt+n.
		function activate(n: int): string {
			return Dock.activateSlot(n);
		}

		function setVisible(visible: bool): string {
			_windows().forEach(w => w.view.userVisible = visible);
			return "ok";
		}
	}
```

- [ ] **Step 6: Run everything**

Run: `bash tests/integration/test_dock.sh && tests/run-all.sh 2>&1 | tail -3`
Expected: every `ok -` line in `test_dock.sh`; `all checks passed`.

- [ ] **Step 7: Commit**

```bash
git add shell/services/Dock.qml shell/modules/dock/DockWindow.qml shell/modules/dock/DockShortcuts.qml shell/shell.qml tests/integration/test_dock.sh tests/integration/fixtures/applications/bloom-test-app.desktop
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the dock to every screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Owner verification on the real session

Run only after the owner approves; ask before each step that changes config.

- [ ] **Step 1: Ask the owner about the dock coexisting with ii.**
  - Does ii show its own dock? (Check `~/.config/illogical-impulse/config.json` `"dock"`, read-only.) If it does, the owner turns it off or accepts two docks for testing.
  - On approval, enable the dock with `bloom ipc settings set bloom-enabled-modules '["notch","dock"]'`, then `systemctl --user restart bloom-shell`.
- [ ] **Step 2: Pins.** Pin a few apps the owner uses with `bloom ipc dock pin <id>`; ids come from `ls /usr/share/applications ~/.local/share/applications`, without `.desktop`. Expected:
  - icons with tiles and dots for running apps;
  - other running apps after a divider;
  - hover lifts with a tooltip;
  - click launches, focuses or cycles;
  - middle-click opens a new window.
- [ ] **Step 3: Launch survives a shell restart.** Launch an app from the dock, `systemctl --user restart bloom-shell`, and confirm the app is still running. `systemctl --user list-units 'app-bloom-*'` shows its scope.
- [ ] **Step 4: Modes.**
  - **smart (default):** maximise a window and the dock hides. Rest the pointer on the bottom edge and it appears after 200 ms.
  - **fixed:** windows tile above the dock's strip.
  - **adaptive:** `bloom ipc settings set bloom-dock-adaptive true` in fixed mode, then maximise a window; the dock stretches.
- [ ] **Step 5: Super+Alt+1–9 — the owner decides (ruling 8).**
  - **Option A (D12):** replace the "send to workspace" loop in `~/.config/hypr/hyprland/keybinds.lua:199-203` with `hl.bind("SUPER + ALT + " .. (i % 10), hl.dsp.global("bloom:dock-" .. i))` for i = 1–9, and move "send to workspace" to a key the owner picks.
  - **Option B:** leave the keys alone; the dock is reachable over IPC only for now.

  Edit the file only after the owner's explicit choice, and back it up first.
- [ ] **Step 6:** Record the owner's verdict in the ledger. A finding becomes a fix with a test, before the merge.
