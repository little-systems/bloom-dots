# Phase 2A: The Notch (surface, status strip, display modes) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put Bloom's notch on screen as a Quickshell layer surface per monitor. It has:
- Bloom's startup drop-in;
- the collapsed clock;
- the hovered status strip (weather, battery, CPU, RAM, disk, network) with Bloom's tooltips;
- Bloom's three display modes: fixed, smart (hide when the focused window sits under it) and peek (hidden until hovered or an event).

It runs alongside illogical-impulse and is switched on with `bloom-enabled-modules`.

**Architecture:**
- **Logic:** all rules (geometry, hide decision, overlap test, clock text, stats parsing, battery and weather text) live in plain JS files tested with `qmltestrunner`.
- **`NotchView.qml`:** the whole notch UI as a plain `Item`. Data comes in as properties, so it can be tested offscreen with simulated mouse hover.
- **`NotchWindow.qml`:** wraps it in a fixed-size `PanelWindow` and feeds it from the services: `Settings`, `Theme`, `Battery`, `Weather`, `SystemStats`, `HyprState`. Its input mask is the pill, or a thin edge band while the notch is hidden.
- **Tests:** a headless sway test loads the real surface. Hover is tested at the QML level, because headless sway has no pointer device.

**Tech Stack:**
- Quickshell 0.3.2, Qt 6.12 (Quick, Shapes, QtTest)
- UPower and power-profiles via Quickshell services
- `hyprctl -j` for windows and monitors
- Open-Meteo, ipapi.co and ip-api.com over `XMLHttpRequest`
- `lucide-static@1.47.0` icons (ISC)
- sway 1.12 (headless, tests only)

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md` (sections 3.2–3.4, 4.1 Notch, 5.1–5.3, 6, 8 phase 2, 9, Appendix A). This is plan 2A of three for Phase 2 (owner decision 2026-10-25): 2A notch and status, 2B music, 2C pulses and workspace peek.

## Global Constraints

- **Platform:** Arch Linux; Hyprland ≥ 0.56 with the Lua config; Quickshell ≥ 0.3.
- **Layer surfaces never resize while animating;** only the input mask follows the shape (spec §3.3 rule 1). The notch surface is a fixed 1000×480.
- **Namespaces:** `bloom:<panel>`, so the notch is `bloom:notch`.
- **Settings:** `~/.config/bloom/settings.json`, keys `bloom-*`, native JSON types, plus Bloom for Windows' string forms. An invalid value uses its default and logs a warning.
- **Polling:** nothing polls unless a visible surface needs it (spec §5.1). Stats poll every 3 s only while a stats widget is shown. Hyprland is queried only while some notch is in smart mode. Weather refreshes every 30 min only while the weather widget is configured.
- **Motion:** framer-motion parity:
  - springs from Appendix A, through `Spring`;
  - explicit durations use framer's `easeOut` `[0, 0, 0.58, 1]`;
  - values Bloom animates with no transition use framer's default `[0.25, 0.1, 0.35, 1]` over 300 ms;
  - CSS `ease` is `[0.25, 0.1, 0.25, 1]`.
- **Coexistence:** the notch runs only when `"notch"` is in `bloom-enabled-modules` (default `[]`). It respects other layer surfaces' exclusive zones, so it sits under ii's bar while that bar exists.
- **Owner's files:** nothing under `~/.config` or `~/dots-hyprland` changes, except Task 9, which the owner runs after approving it.
- **Commits:** conventional commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit …`.
- **Style:** QML and JS use tabs. Comments explain why, not what.

## Review Focus

1. **The pointer resting at the top edge while the notch is hidden.** The reveal band takes input only while the notch is hidden and the mode isn't `fixed`. A click there during the dwell is lost, which is the Wayland trade-off (see Rulings below). Test: Task 7 `test_bandOnlyWhileHidden`.
2. **Not running under Hyprland** (the sway test, or Hyprland restarting). Smart mode treats that as "not overlapped", and nothing spams the log. Test: Task 8 `test_notch.sh` (smart mode under sway: shown, no warnings).
3. **Offline at startup, or the weather API failing.** The cached value stays, a failure logs one warning per attempt and never repeats faster than the refresh, and Open-Meteo's `0` °C is a valid reading (Bloom treated it as missing). Test: Task 6 `test_parseForecastKeepsZero`, `test_failedFetchKeepsCache`.
4. **A configured widget with no data** (battery on a desktop, weather disabled or not fetched yet). The widget is not drawn, and the strip width still counts configured widgets, as Bloom does. Test: Task 7 `test_widgetWithoutDataIsHidden`.
5. **A monitor unplugged while its notch holds stats or Hyprland polling.** Its hold is released, so polling stops. Test: Task 7 `test_releasesHoldsOnDestruction` (NotchView emits `statsWanted(false)` when destroyed while holding).

## Rulings already made (owner sees these in the handoff)

- **Edge reveal band:**
  - Bloom watches an 8 px band along the whole top edge without taking input (a Windows mouse hook).
  - On Wayland, sensing the pointer means owning the input, so the band is **2 px tall and 400 px wide, centred** (the widest status strip plus margin). It exists only while the notch is hidden in smart or peek mode.
  - The dwell uses `bloom-notch-edge-delay` (default 200 ms), as Bloom does.
- **Edge reveal hand-off:** once the notch shows, the band switches off under the pointer. Wayland only reports hover on the pill after the pointer moves, so a reveal holds for 1 s (`notch.edgeHandoffMs`) if the pointer never reaches the pill, then the 800 ms grace runs. Without the hold, a resting pointer would make the notch flicker.
- **Pill hidden by the user (`notch setVisible false`, Bloom's ToggleVisibility):** fades and slides as Bloom does, without the 8 px blur, which would cost a GPU pass on the UHD 620 for a rare action.
- **Battery fill:** Bloom paints the normal fill literally `white`. Here it uses the theme text colour: identical in dark themes, and visible in light ones, where Bloom's white fill disappears. The bolt's 1.5 px drop shadow is dropped (no effect pass).
- **Disk widget:** reports free space on `/` in GiB (Bloom: the Windows system drive), labelled `GB` as Bloom does.
- **Smart mode window:** Bloom reacts to the foreground window. Here it is the most recently focused, mapped, visible window on that monitor's active workspace (Hyprland `focusHistoryID`). Hyprland `fullscreen > 0` (maximised or fullscreen) counts as overlapping, as Bloom treats maximised and fullscreen.

---

## File map

| File | Responsibility |
|---|---|
| `shell/services/settings.js` | + notch, status, weather, clock, battery, scale keys; types `string`, nullable `number`, `widgets`, enum aliases |
| `tools/gen-settings-doc.mjs`, `docs/SETTINGS.md` | Doc generator learns the new types; regenerated |
| `shell/common/tokens.js` | + `easing`, `notch`, `statusStrip` tokens |
| `tools/package.json`, `tools/package-lock.json`, `tools/gen-icons.mjs` | Builds `icons.js` from pinned `lucide-static` |
| `shell/common/icons.js` | Generated Lucide SVG strings |
| `licenses/lucide.txt` | Lucide ISC licence |
| `shell/common/SvgIcon.qml` | Lucide icon recoloured by rewriting the SVG |
| `shell/modules/notch/notch.js` | Notch rules: geometry, hide decision, overlap, focused window, widths, clock text |
| `shell/services/stats.js`, `shell/services/SystemStats.qml` | /proc + df parsing; polled while held |
| `shell/services/battery.js`, `shell/services/Battery.qml` | Bloom battery tooltip; UPower wrapper |
| `shell/modules/notch/BatteryIcon.qml` | Bloom battery glyph |
| `shell/services/weather.js`, `shell/services/Weather.qml` | Open-Meteo + IP geolocation, cached |
| `shell/services/HyprState.qml`, `shell/services/HyprEvents.qml` | Hyprland clients/monitors while held |
| `shell/modules/notch/StatusWidget.qml` | Icon + label of one status widget |
| `shell/modules/notch/StatusTooltip.qml` | Bloom tooltip card |
| `shell/modules/notch/NotchView.qml` | The notch UI and its state machine |
| `shell/modules/notch/NotchWindow.qml` | Per-screen layer surface, data wiring, mask |
| `shell/shell.qml` | Loads notches when enabled; `notch` IPC target |
| `tests/qml/tst_*.qml` | Unit and component tests |
| `tests/integration/lib.sh`, `tests/integration/sway.conf`, `tests/integration/test_notch.sh` | Headless sway helpers and the notch surface test |
| `tests/run-all.sh`, `.github/workflows/ci.yml`, `.gitignore` | Icons check, sway in CI, `tools/node_modules` ignored |

## Verified facts this plan relies on (checked on the owner's machine, 2026-10-25)

- **framer-motion defaults** (motion-dom 12.43 `getDefaultTransition` and the animation `ease` fallback):
  - transforms `x`/`y` spring 500/25 (restSpeed 10), `scale` spring 550/30;
  - other values with no transition: keyframes `[0.25, 0.1, 0.35, 1]`, 0.3 s;
  - a transition that gives only a duration: `easeOut` = `cubicBezier(0, 0, 0.58, 1)`.
- **`Hyprland.refreshToplevels()`** returns each window's `at`, `size`, `fullscreen`, `workspace`, `monitor` and `focusHistoryID`, but gives no reliable "data arrived" signal.
  - `hyprctl -j clients` / `hyprctl -j monitors` run through `Process` + `StdioCollector` (`onStreamFinished`) give the same data with a clear finish.
  - A direct `Socket` query logs `QLocalSocket::PeerClosedError` every time, so it is not used.
- **Monitor JSON:** `{name, x, y, width, height, scale, reserved: [l, t, r, b], activeWorkspace: {id}}`. ii's bar reserves `reserved[1] = 45`.
- **Importing `Quickshell.Hyprland`** logs `$HYPRLAND_INSTANCE_SIGNATURE is unset` only when the `Hyprland` singleton is used. Keep it in a file loaded by a `Loader` that is active only under Hyprland.
- **UPower** (`Quickshell.Services.UPower`):
  - `UPower.displayDevice` has `percentage` (0–1), `state`, `timeToEmpty`, `timeToFull`, `healthPercentage`, `healthSupported` and `isLaptopBattery`;
  - `UPower.onBattery` exists;
  - `PowerProfiles.profile` uses `PowerProfile.PowerSaver | Balanced | Performance`.
- **Icon tinting:**
  - `MultiEffect` colourisation does not render offscreen (the tests read black).
  - A recoloured SVG as a `data:image/svg+xml;utf8,` URL loads asynchronously and renders correctly offscreen: wait for `Image.Ready`, then sample.
- **`lucide-static@1.47.0`** (ISC) contains every icon Bloom's notch uses: sun, moon, cloud, cloud-fog, cloud-drizzle, cloud-rain, cloud-snow, cloud-lightning, thermometer, cpu, memory-stick, hard-drive, arrow-up-down.
- **Quickshell `Region`** has `regions` (child regions) and `item`. `item: null` gives an empty region.
- **Headless sway 1.12** (`WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1`) hosts a Quickshell `PanelWindow` with `Configuration Loaded` and no warnings. Details:
  - The config needs `xwayland disable` and `swaybg_command -`; without the latter sway kills its own process group when `swaybg` is missing.
  - `XDG_RUNTIME_DIR` must be a short path (Unix socket paths are limited to 108 bytes): use `mktemp -d "/run/user/$UID/bt.XXXX"` when that exists, else `mktemp -d`.
  - When launched as a plain background job from the Claude Code tool, sway is SIGKILLed. As a `systemd-run --user` transient unit it runs, so the helper uses `systemd-run --user` when a user manager is reachable, and direct launch otherwise (CI).
  - Headless sway has no pointer device, so `swaymsg seat … cursor set` produces no hover events. Hover is tested in QML instead.
- **`qmltestrunner`'s `mouseMove`** drives `HoverHandler`. `grabImage` works offscreen when the scene root is an `Item` that contains the `TestCase`.
- **Bloom references** (App.tsx, App.css, useWeather.ts, batteryTooltip.ts, services.rs @ b5fb962):
  - Widths: collapsed 140 (24 h −16); hover `max(min(200 + 50 × widgets, 380) − trim, fit)`, fit = `ceil(clock + 2 × (side + 10) + 24)`.
  - Hidden pill: 39.1 × 28.9 at y −100. Hidden by the user: y −150, opacity 0. Startup: 30.6 × 44.2 at y 250 → ready target 34 × 34 → impact after 240 ms → startup lock released after 1500 ms.
  - Interaction grace: 800 ms.
  - Overlap: maximised or fullscreen, or horizontal intersection with the notch (±4 px) and window top < notch top + 36 − 4.
  - Tooltip: shown after 400 ms, 8 px below the pill, centred on the widget, 0.15 s fade with a 4 px slide; padding 8 × 11, radius 11, 11 px/500, line height 1.5.
  - Status widgets: icon 12 px, label 11 px/500 at 0.85 opacity, 5 px gap; groups have 10 px gaps; widgets fade 0.2 s.
  - Stats polled every 3 s. Weather every 30 min; Open-Meteo `current=temperature_2m,weather_code,is_day&timezone=auto[&temperature_unit=fahrenheit]`.

---

### Task 1: Settings for the notch

**Files:**
- Modify: `shell/services/settings.js` (full replacement below), `tools/gen-settings-doc.mjs` (the `allowed` function), `tests/qml/tst_settings.qml` (full replacement below)
- Regenerate: `docs/SETTINGS.md`

**Interfaces:**
- Produces (in `settings.js`):
  - `WIDGETS` (string[]): `weather`, `battery`, `cpu`, `ram`, `disk`, `net`.
  - New keys, with defaults:
    - `bloom-notch-mode` (`"fixed"`, alias `"auto-hide"` → `"smart"`)
    - `bloom-notch-edge-delay` (`200`)
    - `bloom-status-widgets` (`{left: ["weather"], right: ["battery"]}`)
    - `bloom-weather-enabled` (`true`), `bloom-weather-city` (`""`)
    - `bloom-weather-lat`, `bloom-weather-lon` (`null`)
    - `bloom-temp-unit` (`"celsius"`)
    - `bloom-time-format-24h` (`false`)
    - `bloom-low-battery-threshold` (`20`)
    - `bloom-scale` (`1`)
  - `bloom-theme-opacity` now has min 0.1, as Bloom does.
  - `defaults()` returns deep copies.
- Consumes: nothing new.

- [ ] **Step 1: Replace `tests/qml/tst_settings.qml` with the extended test**

```qml
import QtQuick
import QtTest
import "../../shell/services/settings.js" as Settings

TestCase {
	name: "SettingsSchema"

	function test_defaults() {
		const d = Settings.defaults();
		compare(d["bloom-theme-mode"], "dark");
		compare(d["bloom-theme-color"], "#007aff");
		compare(d["bloom-theme-opacity"], 0.8);
		compare(d["bloom-theme-saturation"], 0.5);
		compare(d["bloom-theme-brightness"], 0.15);
		compare(d["bloom-enabled-modules"], []);
		compare(d["bloom-notch-mode"], "fixed");
		compare(d["bloom-notch-edge-delay"], 200);
		compare(d["bloom-status-widgets"], { left: ["weather"], right: ["battery"] });
		compare(d["bloom-weather-enabled"], true);
		compare(d["bloom-weather-city"], "");
		compare(d["bloom-weather-lat"], null);
		compare(d["bloom-weather-lon"], null);
		compare(d["bloom-temp-unit"], "celsius");
		compare(d["bloom-time-format-24h"], false);
		compare(d["bloom-low-battery-threshold"], 20);
		compare(d["bloom-scale"], 1);
		compare(Object.keys(d).sort(), Settings.keys().sort());
	}

	function test_defaultsAreFreshCopies() {
		Settings.defaults()["bloom-enabled-modules"].push("notch");
		Settings.defaults()["bloom-status-widgets"].left.push("cpu");
		compare(Settings.defaults()["bloom-enabled-modules"], []);
		compare(Settings.defaults()["bloom-status-widgets"].left, ["weather"]);
	}

	// Bloom for Windows stored every value as a string.
	function test_bloomStringForms() {
		compare(Settings.validateValue({ type: "bool" }, "true"), { ok: true, value: true });
		compare(Settings.validateValue({ type: "bool" }, "false"), { ok: true, value: false });
		compare(Settings.validateOne("bloom-theme-opacity", "0.8"), { ok: true, value: 0.8 });
		compare(Settings.validateOne("bloom-time-format-24h", "true"), { ok: true, value: true });
		compare(Settings.validateOne("bloom-status-widgets", "{\"left\":[\"cpu\",\"ram\"],\"right\":[\"battery\",\"net\"]}"),
			{ ok: true, value: { left: ["cpu", "ram"], right: ["battery", "net"] } });
		verify(!Settings.validateOne("bloom-theme-opacity", "").ok);
		verify(!Settings.validateValue({ type: "bool" }, "yes").ok);
	}

	function test_numberRange() {
		verify(!Settings.validateOne("bloom-theme-opacity", 0).ok, "Bloom's minimum opacity is 0.1");
		verify(Settings.validateOne("bloom-theme-opacity", 0.1).ok);
		verify(Settings.validateOne("bloom-theme-opacity", 1).ok);
		verify(!Settings.validateOne("bloom-theme-opacity", 1.5).ok);
		verify(!Settings.validateOne("bloom-theme-opacity", NaN).ok);
		verify(Settings.validateOne("bloom-scale", 1.3).ok);
		verify(!Settings.validateOne("bloom-scale", 1.4).ok);
		verify(!Settings.validateOne("bloom-notch-edge-delay", 2001).ok);
	}

	function test_nullableNumber() {
		compare(Settings.validateOne("bloom-weather-lat", null), { ok: true, value: null });
		compare(Settings.validateOne("bloom-weather-lat", "12.5"), { ok: true, value: 12.5 });
		verify(!Settings.validateOne("bloom-weather-lat", 91).ok);
		verify(!Settings.validateOne("bloom-theme-opacity", null).ok, "not nullable");
	}

	function test_enumAndAlias() {
		verify(Settings.validateOne("bloom-theme-mode", "light").ok);
		verify(!Settings.validateOne("bloom-theme-mode", "neon").ok);
		compare(Settings.validateOne("bloom-notch-mode", "auto-hide"), { ok: true, value: "smart" });
		compare(Settings.validateOne("bloom-notch-mode", "peek"), { ok: true, value: "peek" });
	}

	function test_string() {
		compare(Settings.validateOne("bloom-weather-city", "Chennai"), { ok: true, value: "Chennai" });
		verify(!Settings.validateOne("bloom-weather-city", 42).ok);
		verify(!Settings.validateOne("bloom-weather-city", "x".repeat(101)).ok);
	}

	function test_widgets() {
		compare(Settings.validateOne("bloom-status-widgets", { left: ["cpu", "cpu"], right: ["cpu", "battery"] }),
			{ ok: true, value: { left: ["cpu"], right: ["battery"] } });
		compare(Settings.validateOne("bloom-status-widgets", { left: [], right: [] }), { ok: true, value: { left: [], right: [] } });
		verify(!Settings.validateOne("bloom-status-widgets", { left: ["clock"], right: [] }).ok);
		verify(!Settings.validateOne("bloom-status-widgets", { left: ["cpu"] }).ok);
		verify(!Settings.validateOne("bloom-status-widgets", "{not json").ok);
		verify(!Settings.validateOne("bloom-status-widgets", ["cpu"]).ok);
	}

	function test_colorNormalised() {
		compare(Settings.validateOne("bloom-theme-color", "#0AF"), { ok: true, value: "#00aaff" });
		compare(Settings.validateOne("bloom-theme-color", "#FF9500"), { ok: true, value: "#ff9500" });
		verify(!Settings.validateOne("bloom-theme-color", "blue").ok);
	}

	function test_listEntriesMustBeKnownAndAreDeduplicated() {
		compare(Settings.validateOne("bloom-enabled-modules", ["notch", "dock", "notch"]), { ok: true, value: ["notch", "dock"] });
		verify(!Settings.validateOne("bloom-enabled-modules", ["notch", "taskbar"]).ok);
		verify(!Settings.validateOne("bloom-enabled-modules", "notch").ok);
	}

	function test_validateFallsBackAndWarns() {
		const r = Settings.validate({ "bloom-theme-opacity": 1.5, "bloom-theme-mode": "neon", "bloom-theme-color": "#123456", "x-future": 1 });
		compare(r.values["bloom-theme-opacity"], 0.8);
		compare(r.values["bloom-theme-mode"], "dark");
		compare(r.values["bloom-theme-color"], "#123456");
		compare(r.warnings.length, 3);
		verify(r.warnings.some(w => w.startsWith("x-future: unknown setting")));
	}

	function test_validateNonObject() {
		compare(Settings.validate([1, 2]).values, Settings.defaults());
		compare(Settings.validate(null).warnings.length, 1);
	}

	function test_parse() {
		compare(Settings.parse(""), { ok: true, value: {} });
		compare(Settings.parse("  \n"), { ok: true, value: {} });
		compare(Settings.parse('{"a": 1}'), { ok: true, value: { a: 1 } });
		verify(!Settings.parse('{"a": ').ok);
	}

	function test_serializeRoundTrips() {
		const obj = { "bloom-theme-mode": "light", "x-future": [1, 2] };
		const text = Settings.serialize(obj);
		verify(text.endsWith("\n"));
		compare(JSON.parse(text), obj);
	}

	function test_nonDefaultsAndChangedKeys() {
		const v = Settings.defaults();
		v["bloom-theme-mode"] = "light";
		v["bloom-status-widgets"] = { left: [], right: ["battery"] };
		compare(Settings.nonDefaults(v), { "bloom-theme-mode": "light", "bloom-status-widgets": { left: [], right: ["battery"] } });
		compare(Settings.changedKeys(Settings.defaults(), v).sort(), ["bloom-status-widgets", "bloom-theme-mode"]);
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: several `FAIL!` lines (e.g. `test_defaults`, `test_widgets`, `test_enumAndAlias`) and `Totals: … failed`.

- [ ] **Step 3: Replace `shell/services/settings.js`**

```js
// Settings schema and validation. Plain JS shared by Settings.qml, the QML
// unit tests and tools/gen-settings-doc.mjs (no .pragma, no exports).
// Each phase adds the keys its surfaces use; docs/SETTINGS.md is generated
// from SCHEMA.

var MODULES = ["notch", "dock", "osd", "notifications", "launcher", "overview", "session", "lock", "polkit", "tray", "regiontools", "wallpaper", "cheatsheet"];

// Status widgets the collapsed notch can show (Bloom StatusWidgetConfig).
var WIDGETS = ["weather", "battery", "cpu", "ram", "disk", "net"];

var SCHEMA = {
	"bloom-theme-mode": {
		type: "enum",
		values: ["dark", "light", "custom", "adaptive"],
		default: "dark",
		doc: "Theme mode. Adaptive follows the wallpaper; until wallpaper theming exists it falls back to dark."
	},
	"bloom-theme-color": {
		type: "color",
		default: "#007aff",
		doc: "Accent colour for the custom theme (#rgb or #rrggbb)."
	},
	"bloom-theme-opacity": {
		type: "number",
		min: 0.1,
		max: 1,
		default: 0.8,
		doc: "Surface opacity. Hovered and open surfaces add 0.12."
	},
	"bloom-theme-saturation": {
		type: "number",
		min: 0,
		max: 1,
		default: 0.5,
		doc: "Background saturation for the custom and adaptive themes."
	},
	"bloom-theme-brightness": {
		type: "number",
		min: 0,
		max: 1,
		default: 0.15,
		doc: "Background lightness for the custom and adaptive themes. Above 0.55 the text turns dark."
	},
	"bloom-enabled-modules": {
		type: "list",
		values: MODULES,
		default: [],
		doc: "Bloom surfaces to run. Anything not listed is left to another shell (e.g. illogical-impulse)."
	},
	"bloom-notch-mode": {
		type: "enum",
		values: ["fixed", "smart", "peek"],
		aliases: { "auto-hide": "smart" },
		default: "fixed",
		doc: "Notch visibility. fixed = always shown; smart = hides while the focused window sits under it; peek = hidden until hovered or an event shows it briefly."
	},
	"bloom-notch-edge-delay": {
		type: "number",
		min: 0,
		max: 2000,
		default: 200,
		doc: "In smart and peek mode, how long (ms) the pointer must rest on the top edge before a hidden notch appears. 0 reveals it at once."
	},
	"bloom-status-widgets": {
		type: "widgets",
		values: WIDGETS,
		default: { left: ["weather"], right: ["battery"] },
		doc: "Widgets in the hovered status strip, left and right of the clock."
	},
	"bloom-weather-enabled": {
		type: "bool",
		default: true,
		doc: "Show the weather widget (fetches from Open-Meteo; without coordinates the location comes from IP geolocation)."
	},
	"bloom-weather-city": {
		type: "string",
		maxLength: 100,
		default: "",
		doc: "City name shown with the weather. Empty means the IP-geolocated city."
	},
	"bloom-weather-lat": {
		type: "number",
		min: -90,
		max: 90,
		nullable: true,
		default: null,
		doc: "Latitude for the weather. null uses IP geolocation."
	},
	"bloom-weather-lon": {
		type: "number",
		min: -180,
		max: 180,
		nullable: true,
		default: null,
		doc: "Longitude for the weather. null uses IP geolocation."
	},
	"bloom-temp-unit": {
		type: "enum",
		values: ["celsius", "fahrenheit"],
		default: "celsius",
		doc: "Temperature unit for the weather widget."
	},
	"bloom-time-format-24h": {
		type: "bool",
		default: false,
		doc: "24-hour clock in the notch; otherwise 12-hour with AM/PM."
	},
	"bloom-low-battery-threshold": {
		type: "number",
		min: 5,
		max: 50,
		default: 20,
		doc: "Battery percentage at or below which the battery fill turns red."
	},
	"bloom-scale": {
		type: "number",
		min: 0.8,
		max: 1.3,
		default: 1,
		doc: "Size of Bloom's surfaces."
	}
};

function keys() {
	return Object.keys(SCHEMA);
}

function _copy(v) {
	return v !== null && typeof v === "object" ? JSON.parse(JSON.stringify(v)) : v;
}

function defaults() {
	const out = {};
	keys().forEach(k => out[k] = _copy(SCHEMA[k].default));
	return out;
}

function _ok(value) {
	return { ok: true, value: value };
}

function _fail(error) {
	return { ok: false, error: error };
}

function _unique(list) {
	return list.filter((v, i) => list.indexOf(v) === i);
}

// Validates and normalises one value against a schema entry. Accepts Bloom
// for Windows' string forms ("true", "0.8", JSON text), which stored every
// value as text.
function validateValue(spec, value) {
	switch (spec.type) {
	case "bool":
		if (value === true || value === false)
			return _ok(value);
		if (value === "true" || value === "false")
			return _ok(value === "true");
		return _fail("expected true or false");
	case "number": {
		if (value === null && spec.nullable)
			return _ok(null);
		const n = typeof value === "string" && value.trim() !== "" ? Number(value) : value;
		if (typeof n !== "number" || !isFinite(n))
			return _fail(spec.nullable ? "expected a number or null" : "expected a number");
		if ((spec.min !== undefined && n < spec.min) || (spec.max !== undefined && n > spec.max))
			return _fail(`expected a number from ${spec.min} to ${spec.max}`);
		return _ok(n);
	}
	case "enum": {
		const v = spec.aliases && Object.prototype.hasOwnProperty.call(spec.aliases, value) ? spec.aliases[value] : value;
		if (spec.values.indexOf(v) < 0)
			return _fail("expected one of " + spec.values.join(", "));
		return _ok(v);
	}
	case "string":
		if (typeof value !== "string")
			return _fail("expected text");
		if (spec.maxLength !== undefined && value.length > spec.maxLength)
			return _fail(`expected at most ${spec.maxLength} characters`);
		return _ok(value);
	case "color": {
		if (typeof value !== "string" || !/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(value))
			return _fail("expected a colour like #007aff");
		let h = value.slice(1).toLowerCase();
		if (h.length === 3)
			h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
		return _ok("#" + h);
	}
	case "list": {
		if (!Array.isArray(value))
			return _fail("expected a list");
		const unknown = value.filter(v => spec.values.indexOf(v) < 0);
		if (unknown.length)
			return _fail(`unknown ${JSON.stringify(unknown)}; expected entries from ${spec.values.join(", ")}`);
		return _ok(_unique(value));
	}
	case "widgets": {
		let v = value;
		if (typeof v === "string") {
			try {
				v = JSON.parse(v);
			} catch (e) {
				return _fail('expected {"left": [...], "right": [...]}');
			}
		}
		if (v === null || typeof v !== "object" || Array.isArray(v) || !Array.isArray(v.left) || !Array.isArray(v.right))
			return _fail('expected {"left": [...], "right": [...]}');
		const unknown = v.left.concat(v.right).filter(w => spec.values.indexOf(w) < 0);
		if (unknown.length)
			return _fail(`unknown ${JSON.stringify(unknown)}; expected widgets from ${spec.values.join(", ")}`);
		// A widget appears once: its first place wins.
		const left = _unique(v.left);
		const right = _unique(v.right).filter(w => left.indexOf(w) < 0);
		return _ok({ left: left, right: right });
	}
	}
	return _fail("unsupported type " + spec.type);
}

function validateOne(key, value) {
	return SCHEMA[key] ? validateValue(SCHEMA[key], value) : _fail("unknown setting");
}

// Every schema key is present in `values`; invalid or missing ones take their
// default. Unknown keys are reported and ignored (Settings keeps them in the file).
function validate(obj) {
	const values = defaults();
	const warnings = [];
	if (obj === null || typeof obj !== "object" || Array.isArray(obj))
		return { values: values, warnings: ["settings file is not a JSON object; using defaults"] };
	Object.keys(obj).forEach(k => {
		if (!SCHEMA[k]) {
			warnings.push(k + ": unknown setting, ignored");
			return;
		}
		const r = validateOne(k, obj[k]);
		if (r.ok)
			values[k] = r.value;
		else
			warnings.push(`${k}: ${r.error}; using default ${JSON.stringify(SCHEMA[k].default)}`);
	});
	return { values: values, warnings: warnings };
}

// Empty or whitespace-only text is an empty settings object.
function parse(text) {
	if (!text || !text.trim())
		return _ok({});
	try {
		return _ok(JSON.parse(text));
	} catch (e) {
		return _fail(String(e.message || e));
	}
}

function serialize(obj) {
	return JSON.stringify(obj, null, "\t") + "\n";
}

function nonDefaults(values) {
	const out = {};
	keys().forEach(k => {
		if (JSON.stringify(values[k]) !== JSON.stringify(SCHEMA[k].default))
			out[k] = values[k];
	});
	return out;
}

function changedKeys(a, b) {
	return keys().filter(k => JSON.stringify(a[k]) !== JSON.stringify(b[k]));
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_settings.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 17 passed, 0 failed` (15 tests plus init/cleanup).

- [ ] **Step 5: Teach the doc generator the new types**

In `tools/gen-settings-doc.mjs`, replace the `allowed` function with:

```js
const allowed = s => {
	if (s.type === "enum") {
		const aliases = s.aliases ? Object.keys(s.aliases).map(a => ` (\`${a}\` = \`${s.aliases[a]}\`)`).join("") : "";
		return s.values.map(v => `\`${v}\``).join(", ") + aliases;
	}
	if (s.type === "list") return s.values.map(v => `\`${v}\``).join(", ");
	if (s.type === "widgets") return `\`{"left": [...], "right": [...]}\` of ${s.values.map(v => `\`${v}\``).join(", ")}`;
	if (s.type === "number") return `${s.min} to ${s.max}${s.nullable ? ", or `null`" : ""}`;
	if (s.type === "color") return "`#rgb` or `#rrggbb`";
	if (s.type === "bool") return "`true`, `false`";
	if (s.type === "string") return `text, up to ${s.maxLength} characters`;
	return "";
};
```

- [ ] **Step 6: Regenerate the reference and run the whole suite**

Run: `node tools/gen-settings-doc.mjs && tests/run-all.sh 2>&1 | tail -3`
Expected: `wrote docs/SETTINGS.md` (now 17 rows), then `all checks passed`. The integration test still passes: it only uses opacity 0.4/0.5/0.6 and 1.5.

- [ ] **Step 7: Commit**

```bash
git add shell/services/settings.js tools/gen-settings-doc.mjs tests/qml/tst_settings.qml docs/SETTINGS.md
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add notch, status and weather settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Tokens and icons

**Files:**
- Modify: `shell/common/tokens.js` (append), `.gitignore`, `tests/run-all.sh`, `.github/workflows/ci.yml`
- Create: `tools/package.json`, `tools/package-lock.json` (generated), `tools/gen-icons.mjs`, `shell/common/icons.js` (generated), `licenses/lucide.txt`, `shell/common/SvgIcon.qml`, `tests/qml/tst_svgicon.qml`

**Interfaces:**
- Produces:
  - `tokens.js`: `easing.framerEaseOut`, `easing.framerDefault`, `easing.framerDefaultMs` (300), `easing.cssEase` (each 4-number bezier array); `notch.*`; `statusStrip.*` (exact fields in Step 5).
  - `icons.js`: `var svg = { "<name>": "<svg …>" }`.
  - QML type `SvgIcon` (an `Image`): `name: string` (required), `color: color`, `size: real` (default 12), `strokeWidth: real` (default 2).

- [ ] **Step 1: Write the failing test `tests/qml/tst_svgicon.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/common"

Item {
	id: host
	width: 80
	height: 30

	Rectangle { anchors.fill: parent; color: "black" }

	SvgIcon { id: red; name: "sun"; color: "#ff0000"; size: 24 }
	SvgIcon { id: thick; x: 30; name: "cpu"; color: "white"; size: 24; strokeWidth: 2.2 }
	SvgIcon { id: missing; x: 60; name: "no-such-icon" }

	TestCase {
		name: "SvgIcon"
		when: windowShown

		function test_recoloursTheStroke() {
			tryCompare(red, "status", Image.Ready, 3000);
			const img = grabImage(host);
			// The sun's top ray runs from (12, 2) to (12, 4) in the 24 px box.
			verify(Qt.colorEqual(img.pixel(12, 3), "#ff0000"), `got ${img.pixel(12, 3)}`);
		}

		function test_strokeWidthIsApplied() {
			verify(thick.source.toString().indexOf(encodeURIComponent('stroke-width="2.2"')) > 0);
		}

		function test_unknownIconIsEmpty() {
			ignoreWarning(/unknown icon "no-such-icon"/);
			compare(missing.source.toString(), "");
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_svgicon.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile() SvgIcon is not a type`.

- [ ] **Step 3: Create `tools/package.json` and install it**

```json
{
	"name": "bloom-tools",
	"private": true,
	"type": "module",
	"devDependencies": {
		"lucide-static": "1.47.0"
	}
}
```

Run: `cd tools && npm install --silent && cd .. && ls tools/node_modules/lucide-static/icons/sun.svg`
Expected: the path prints, and `tools/package-lock.json` now exists.

Append to `.gitignore`:

```
tools/node_modules/
```

- [ ] **Step 4: Create `tools/gen-icons.mjs`, generate `icons.js` and copy the licence**

```js
// Builds shell/common/icons.js from lucide-static, the icon set Bloom uses
// through lucide-react. Usage: node tools/gen-icons.mjs [--check]
import { readFileSync, writeFileSync } from "node:fs";

const ICONS = [
	"sun", "moon", "cloud", "cloud-fog", "cloud-drizzle", "cloud-rain", "cloud-snow", "cloud-lightning", "thermometer",
	"cpu", "memory-stick", "hard-drive", "arrow-up-down"
];

const root = new URL("../", import.meta.url);
const lucide = new URL("tools/node_modules/lucide-static/", root);
const version = JSON.parse(readFileSync(new URL("package.json", lucide), "utf8")).version;

const entries = ICONS.map(name => {
	const raw = readFileSync(new URL(`icons/${name}.svg`, lucide), "utf8");
	const svg = raw.replace(/<!--[\s\S]*?-->/g, "").replace(/\s*\n\s*/g, " ").replace(/>\s+</g, "><").trim();
	return `\t${JSON.stringify(name)}: ${JSON.stringify(svg)}`;
});

const out = `// Generated by tools/gen-icons.mjs from lucide-static ${version} (ISC licence,
// see licenses/lucide.txt). Do not edit by hand.

var svg = {
${entries.join(",\n")}
};
`;

const target = new URL("shell/common/icons.js", root);
if (process.argv.includes("--check")) {
	let current = "";
	try { current = readFileSync(target, "utf8"); } catch {}
	if (current !== out) {
		console.error("shell/common/icons.js is out of date; run: node tools/gen-icons.mjs");
		process.exit(1);
	}
	console.log("ok");
} else {
	writeFileSync(target, out);
	console.log(`wrote shell/common/icons.js (${ICONS.length} icons)`);
}
```

Run: `node tools/gen-icons.mjs && mkdir -p licenses && cp tools/node_modules/lucide-static/LICENSE licenses/lucide.txt && head -c 300 shell/common/icons.js`
Expected: `wrote shell/common/icons.js (13 icons)`, then the header and the start of `"sun": "<svg class=\"lucide lucide-sun\" …`.

- [ ] **Step 5: Append the tokens to `shell/common/tokens.js`**

```js

// framer-motion easings. A transition giving only a duration uses easeOut; a
// value Bloom animates with no transition gets framer's default 0.3 s curve.
var easing = {
	framerEaseOut: [0, 0, 0.58, 1],
	framerDefault: [0.25, 0.1, 0.35, 1],
	framerDefaultMs: 300,
	cssEase: [0.25, 0.1, 0.25, 1]
};

// Notch behaviour (Bloom App.tsx).
var notch = {
	// Fixed layer surface: room for the widest panel (480) at the largest scale
	// (1.3) with flares and tooltips. The surface never resizes (spec §3.3).
	surface: { width: 1000, height: 480 },
	hidden: { width: 39.1, height: 28.9, y: -100 },
	invisibleY: -150,
	startup: { width: 30.6, height: 44.2, y: 250, readySize: 34, impactDelayMs: 240, animatingMs: 1500 },
	opacityMs: 200,
	colorFadeMs: 300,
	graceMs: 800,
	// Wayland can only sense the pointer where the surface takes input, so the
	// reveal band is a thin strip over the notch rather than Bloom's full edge.
	edgeBand: { width: 400, height: 2 },
	// Wayland reports hover only after the pointer moves, so a reveal from the
	// band lets go this long after the band switches off if the pointer never
	// reaches the pill; the normal grace then runs.
	edgeHandoffMs: 1000,
	overlapInset: 4
};

var statusStrip = {
	itemGap: 5,
	groupGap: 10,
	iconSize: 12,
	labelSize: 11,
	labelOpacity: 0.85,
	fadeMs: 200,
	tooltip: { delayMs: 400, gap: 8, fadeMs: 150, slide: 4, paddingV: 8, paddingH: 11, radius: 11, size: 11, lineHeight: 1.5 }
};
```

- [ ] **Step 6: Create `shell/common/SvgIcon.qml`**

```qml
import QtQuick
import "icons.js" as Icons

// A Lucide icon recoloured by rewriting its SVG (stroke colour and width), so
// it follows the theme without a graphics effect pass.
Image {
	id: root

	required property string name
	property color color: "white"
	property real size: 12
	property real strokeWidth: 2

	width: size
	height: size
	sourceSize: Qt.size(Math.ceil(size * 2), Math.ceil(size * 2))
	fillMode: Image.PreserveAspectFit
	smooth: true

	source: {
		const svg = Icons.svg[root.name];
		if (!svg) {
			console.warn(`bloom: unknown icon "${root.name}"`);
			return "";
		}
		// SVG has no #aarrggbb, so the colour goes in as rgb; use opacity for alpha.
		const c = root.color;
		const hex = "#" + [c.r, c.g, c.b].map(v => Math.round(v * 255).toString(16).padStart(2, "0")).join("");
		const painted = svg.replace(/currentColor/g, hex).replace('stroke-width="2"', `stroke-width="${root.strokeWidth}"`);
		return "data:image/svg+xml;utf8," + encodeURIComponent(painted);
	}
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_svgicon.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 5 passed, 0 failed`.

- [ ] **Step 8: Add the icons check to `tests/run-all.sh`, and sway to CI**

In `tests/run-all.sh`, insert this block right after the "settings reference is up to date" block:

```bash
step "icons are up to date"
if [[ -f "$ROOT/tools/gen-icons.mjs" ]] && need node; then
	[[ -d "$ROOT/tools/node_modules" ]] || (cd "$ROOT/tools" && npm ci --silent)
	node "$ROOT/tools/gen-icons.mjs" --check
fi
```

In `.github/workflows/ci.yml`, change the install line to:

```yaml
        run: pacman -Syu --noconfirm --needed git quickshell qt6-declarative qt6-svg nodejs npm jq shellcheck systemd sway
```

- [ ] **Step 9: Run the whole suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -3`
Expected: `all checks passed`.

```bash
git add shell/common/tokens.js shell/common/icons.js shell/common/SvgIcon.qml tools/package.json tools/package-lock.json tools/gen-icons.mjs licenses/lucide.txt tests/qml/tst_svgicon.qml tests/run-all.sh .github/workflows/ci.yml .gitignore
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add notch tokens and Lucide icons

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Notch rules

**Files:**
- Create: `shell/modules/notch/notch.js`, `tests/qml/tst_notchlogic.qml`

**Interfaces:**
- Produces (`notch.js`):
  - Sizing:
    - `statusWidth(hovered: bool, widgetCount: int, fitWidth: number, use24h: bool) → number`
    - `fitWidth(clockWidth, leftWidth, rightWidth) → number`
  - Geometry and hiding:
    - `geometry(state: {ready, visible, hidden, expanded, impacted}, content: {width, height}) → {y, width, height, edgeRadius, farRadius, opacity}`
    - `isHidden(mode: string, overlapped: bool, interaction: "active"|"grace"|"none", eventPeek: bool, startupAnimating: bool) → bool`
  - Smart mode:
    - `focusedWindow(clients: object[], monitor: object) → {x, y, width, height, fullscreen} | null`
    - `notchRect(monitor: object, restWidth: number, uiScale: number) → {left, right, top, rowHeight}`
    - `overlaps(win | null, notchRect) → bool`
  - Clock: `clockText(date: Date, use24h: bool) → string`

- [ ] **Step 1: Write the failing test `tests/qml/tst_notchlogic.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/modules/notch/notch.js" as Notch

TestCase {
	name: "NotchLogic"

	function test_statusWidth() {
		compare(Notch.statusWidth(false, 2, 0, false), 140);
		compare(Notch.statusWidth(false, 2, 0, true), 124);
		compare(Notch.statusWidth(true, 2, 0, false), 300);
		compare(Notch.statusWidth(true, 6, 0, false), 380);
		compare(Notch.statusWidth(true, 6, 0, true), 364);
		compare(Notch.statusWidth(true, 2, 330, false), 330, "content wider than the formula wins");
	}

	function test_fitWidth() {
		compare(Notch.fitWidth(60, 80, 50), 60 + 2 * (80 + 10) + 24);
		compare(Notch.fitWidth(60.2, 0, 0), 0, "no widgets measured yet");
	}

	function shown() { return { ready: true, visible: true, hidden: false, expanded: true, impacted: true }; }

	function test_geometryShown() {
		compare(Notch.geometry(shown(), { width: 140, height: 36 }), { y: 0, width: 140, height: 36, edgeRadius: 0, farRadius: 18, opacity: 1 });
	}

	function test_geometryStartup() {
		compare(Notch.geometry({ ready: false, visible: true, hidden: false, expanded: false, impacted: false }, { width: 140, height: 36 }),
			{ y: 250, width: 34, height: 34, edgeRadius: 18, farRadius: 18, opacity: 1 });
		compare(Notch.geometry({ ready: true, visible: true, hidden: false, expanded: false, impacted: false }, { width: 140, height: 36 }),
			{ y: 0, width: 30.6, height: 44.2, edgeRadius: 18, farRadius: 18, opacity: 1 });
	}

	function test_geometryHidden() {
		const s = shown();
		s.hidden = true;
		compare(Notch.geometry(s, { width: 300, height: 36 }), { y: -100, width: 39.1, height: 28.9, edgeRadius: 0, farRadius: 18, opacity: 1 });
	}

	function test_geometryInvisible() {
		const s = shown();
		s.visible = false;
		const g = Notch.geometry(s, { width: 140, height: 36 });
		compare(g.y, -150);
		compare(g.opacity, 0);
		compare(g.width, 39.1);
	}

	function test_isHidden() {
		verify(!Notch.isHidden("fixed", true, "none", false, false));
		verify(Notch.isHidden("smart", true, "none", false, false));
		verify(!Notch.isHidden("smart", true, "grace", false, false), "grace keeps it shown");
		verify(!Notch.isHidden("smart", false, "none", false, false));
		verify(Notch.isHidden("peek", false, "none", false, false));
		verify(!Notch.isHidden("peek", false, "active", false, false));
		verify(!Notch.isHidden("peek", false, "none", true, false), "event peek shows it");
		verify(!Notch.isHidden("peek", false, "none", false, true), "startup animation shows it");
	}

	function monitor() {
		return { id: 0, name: "eDP-1", x: 1920, y: 0, width: 1920, height: 1080, scale: 1, reserved: [0, 45, 0, 0], activeWorkspace: { id: 2 } };
	}

	function client(props) {
		const c = { mapped: true, hidden: false, monitor: 0, workspace: { id: 2 }, at: [1924, 49], size: [1912, 1027], fullscreen: 0, focusHistoryID: 1 };
		for (const k in props) c[k] = props[k];
		return c;
	}

	function test_focusedWindow() {
		const clients = [
			client({ focusHistoryID: 3, at: [10, 10] }),
			client({ focusHistoryID: 1, at: [1924, 49] }),
			client({ focusHistoryID: 0, workspace: { id: 5 } }),
			client({ focusHistoryID: 0, monitor: 1 }),
			client({ focusHistoryID: 0, hidden: true })
		];
		compare(Notch.focusedWindow(clients, monitor()), { x: 1924, y: 49, width: 1912, height: 1027, fullscreen: 0 });
		compare(Notch.focusedWindow([], monitor()), null);
	}

	function test_notchRect() {
		compare(Notch.notchRect(monitor(), 140, 1), { left: 1920 + 890, right: 1920 + 1030, top: 45, rowHeight: 36 });
		const hidpi = monitor();
		hidpi.width = 3840;
		hidpi.scale = 2;
		compare(Notch.notchRect(hidpi, 140, 1.2), { left: 1920 + 960 - 84, right: 1920 + 960 + 84, top: 45, rowHeight: 43.2 });
	}

	function test_overlaps() {
		const rect = { left: 2810, right: 2950, top: 45, rowHeight: 36 };
		verify(Notch.overlaps({ x: 1924, y: 49, width: 1912, height: 1027, fullscreen: 0 }, rect), "tiled window under the notch");
		verify(!Notch.overlaps({ x: 1924, y: 77, width: 1912, height: 900, fullscreen: 0 }, rect), "starts below the trigger line");
		verify(!Notch.overlaps({ x: 1924, y: 49, width: 890, height: 900, fullscreen: 0 }, rect), "ends left of the notch");
		verify(!Notch.overlaps({ x: 2946, y: 49, width: 500, height: 900, fullscreen: 0 }, rect), "within the 4 px inset");
		verify(Notch.overlaps({ x: 1920, y: 500, width: 100, height: 100, fullscreen: 1 }, rect), "maximised counts");
		verify(!Notch.overlaps(null, rect));
	}

	function test_clockText() {
		compare(Notch.clockText(new Date(2026, 9, 25, 13, 5), false), "01:05 PM");
		compare(Notch.clockText(new Date(2026, 9, 25, 0, 30), false), "12:30 AM");
		compare(Notch.clockText(new Date(2026, 9, 25, 12, 0), false), "12:00 PM");
		compare(Notch.clockText(new Date(2026, 9, 25, 13, 5), true), "13:05");
		compare(Notch.clockText(new Date(2026, 9, 25, 7, 9), true), "07:09");
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_notchlogic.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile() Script … notch.js unavailable`.

- [ ] **Step 3: Create `shell/modules/notch/notch.js`**

```js
// Notch rules ported from Bloom (App.tsx, services.rs @ b5fb962). Plain JS,
// shared with the unit tests.

// Bloom getDynamicWidth for the status mode: the collapsed clock, or the
// hovered strip sized by widget count, never narrower than its content.
function statusWidth(hovered, widgetCount, fitWidth, use24h) {
	const trim = use24h ? 16 : 0;
	if (hovered)
		return Math.max(Math.min(200 + widgetCount * 50, 380) - trim, fitWidth);
	return 140 - trim;
}

// Both sides of the strip get the wider side's width around the centred
// clock, plus the pill's 12 px padding each side and a 10 px gap to the clock.
function fitWidth(clockWidth, leftWidth, rightWidth) {
	const side = Math.max(leftWidth, rightWidth);
	return side > 0 ? Math.ceil(clockWidth + 2 * (side + 10) + 24) : 0;
}

// Bloom pillTarget{Y,Width,Height} and corner radii. `content` is the size
// of the shown, expanded notch.
function geometry(s, content) {
	const shown = s.expanded && s.visible && !s.hidden;
	return {
		y: !s.ready ? 250 : s.visible ? (s.hidden ? -100 : 0) : -150,
		width: !s.ready ? 34 : shown ? content.width : s.impacted ? 39.1 : 30.6,
		height: !s.ready ? 34 : shown ? content.height : s.impacted ? 28.9 : 44.2,
		edgeRadius: s.impacted ? 0 : 18,
		farRadius: 18,
		opacity: s.visible ? 1 : 0
	};
}

// Bloom isHidden: smart hides while overlapped, peek hides unless something
// shows it, and nothing hides during the startup animation.
function isHidden(mode, overlapped, interaction, eventPeek, startupAnimating) {
	if (startupAnimating)
		return false;
	if (mode === "smart")
		return overlapped && interaction === "none";
	if (mode === "peek")
		return interaction === "none" && !eventPeek;
	return false;
}

// The window a monitor's notch reacts to: the most recently focused, mapped,
// visible window on that monitor's active workspace (Bloom used the
// foreground window). `clients` and `monitor` are `hyprctl -j` objects.
function focusedWindow(clients, monitor) {
	let best = null;
	for (const c of clients) {
		if (!c.mapped || c.hidden || c.monitor !== monitor.id || !c.workspace || c.workspace.id !== monitor.activeWorkspace.id)
			continue;
		if (!best || c.focusHistoryID < best.focusHistoryID)
			best = c;
	}
	return best ? { x: best.at[0], y: best.at[1], width: best.size[0], height: best.size[1], fullscreen: best.fullscreen } : null;
}

// The resting notch in global layout coordinates. Hyprland reports monitor
// width in physical pixels; the layout works in logical ones.
function notchRect(monitor, restWidth, uiScale) {
	const logicalWidth = monitor.width / monitor.scale;
	const w = restWidth * uiScale;
	const left = monitor.x + (logicalWidth - w) / 2;
	return { left: left, right: left + w, top: monitor.y + monitor.reserved[1], rowHeight: 36 * uiScale };
}

// Bloom services.rs: maximised or fullscreen always counts; otherwise the
// window must reach into the notch's row and overlap it horizontally, with a
// 4 px tolerance.
function overlaps(win, rect) {
	if (!win)
		return false;
	if (win.fullscreen > 0)
		return true;
	const triggerY = rect.top + rect.rowHeight;
	return win.x < rect.right - 4 && win.x + win.width > rect.left + 4 && win.y < triggerY - 4;
}

function _pad(n) {
	return n < 10 ? "0" + n : String(n);
}

// Bloom: toLocaleTimeString with 2-digit hour and minute ("01:05 PM", "13:05").
function clockText(date, use24h) {
	const h = date.getHours();
	const m = date.getMinutes();
	if (use24h)
		return _pad(h) + ":" + _pad(m);
	const h12 = h % 12 === 0 ? 12 : h % 12;
	return _pad(h12) + ":" + _pad(m) + " " + (h < 12 ? "AM" : "PM");
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_notchlogic.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 13 passed, 0 failed`.

- [ ] **Step 5: Run the whole suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add shell/modules/notch/notch.js tests/qml/tst_notchlogic.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add notch geometry, hiding and overlap rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: System stats

**Files:**
- Create: `shell/services/stats.js`, `shell/services/SystemStats.qml`, `tests/qml/tst_stats.qml`

**Interfaces:**
- Produces:
  - `stats.js`:
    - `parse(text) → {cpu: {idle, total}, mem: {total, available}, net: {rx, tx}, diskAvail} | null`
    - `cpuPercent(prev, cur) → int`, `ramPercent(mem) → number`
    - `netSpeed(prevNet, curNet, seconds) → [up, down]` (bytes/s)
    - `diskGB(bytes) → int`, `formatBytes(bytes) → string`
  - Singleton `SystemStats`:
    - values: `cpu: int`, `ram: real`, `disk: int`, `up: int`, `down: int`;
    - `hold(key: string, on: bool)` polls every 3 s while any key is held;
    - `active: bool`.

- [ ] **Step 1: Write the failing test `tests/qml/tst_stats.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/services/stats.js" as Stats

TestCase {
	name: "Stats"

	function sample(cpuLine, memAvail, rx, tx, disk) {
		return [
			cpuLine,
			"cpu0 1 2 3 4 5 6 7 8 0 0",
			"intr 12345",
			"---",
			"MemTotal:       16000000 kB",
			"MemFree:         1000000 kB",
			`MemAvailable:   ${memAvail} kB`,
			"---",
			"Inter-|   Receive                                                |  Transmit",
			" face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed",
			`    lo: 999999 10 0 0 0 0 0 0 999999 10 0 0 0 0 0 0`,
			`wlan0: ${rx} 100 0 0 0 0 0 0 ${tx} 80 0 0 0 0 0 0`,
			`  eth0: 500 5 0 0 0 0 0 0 300 3 0 0 0 0 0 0`,
			"---",
			String(disk),
			""
		].join("\n");
	}

	function test_parse() {
		const s = Stats.parse(sample("cpu  100 0 50 800 50 0 0 0 0 0", 4000000, 10000, 2000, 107374182400));
		compare(s.cpu, { idle: 850, total: 1000 });
		compare(s.mem, { total: 16000000, available: 4000000 });
		compare(s.net, { rx: 10500, tx: 2300 }, "lo excluded, others summed");
		compare(s.diskAvail, 107374182400);
	}

	function test_parseRejectsGarbage() {
		compare(Stats.parse("nothing here"), null);
	}

	function test_cpuPercent() {
		const a = { idle: 850, total: 1000 };
		const b = { idle: 1100, total: 1500 };
		compare(Stats.cpuPercent(a, b), 50);
		compare(Stats.cpuPercent(null, b), 0);
		compare(Stats.cpuPercent(b, b), 0, "no time passed");
	}

	function test_ramPercent() {
		compare(Stats.ramPercent({ total: 16000000, available: 4000000 }), 75);
		compare(Stats.ramPercent({ total: 0, available: 0 }), 0);
	}

	function test_netSpeed() {
		compare(Stats.netSpeed({ rx: 1000, tx: 500 }, { rx: 4000, tx: 2000 }, 3), [500, 1000]);
		compare(Stats.netSpeed(null, { rx: 4000, tx: 2000 }, 3), [0, 0]);
		compare(Stats.netSpeed({ rx: 9000, tx: 9000 }, { rx: 4000, tx: 2000 }, 3), [0, 0], "counter reset");
	}

	function test_diskGB() {
		compare(Stats.diskGB(107374182400), 100);
	}

	// Bloom formatBytes.
	function test_formatBytes() {
		compare(Stats.formatBytes(512), "512B");
		compare(Stats.formatBytes(1536), "1.5K");
		compare(Stats.formatBytes(2 * 1024 * 1024), "2.0M");
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_stats.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile() Script … stats.js unavailable`.

- [ ] **Step 3: Create `shell/services/stats.js`**

```js
// System counters for the status widgets (Bloom read the same from Windows).
// `parse` takes SystemStats' command output: /proc/stat, /proc/meminfo,
// /proc/net/dev and `df` free bytes, separated by lines of "---".

function parse(text) {
	const parts = text.split(/^---$/m);
	if (parts.length < 4)
		return null;
	const cpu = _cpu(parts[0]);
	const disk = Number(parts[3].trim());
	if (!cpu || !isFinite(disk))
		return null;
	return { cpu: cpu, mem: _mem(parts[1]), net: _net(parts[2]), diskAvail: disk };
}

function _cpu(s) {
	const line = s.split("\n").find(l => l.startsWith("cpu "));
	if (!line)
		return null;
	const v = line.trim().split(/\s+/).slice(1).map(Number);
	// user nice system idle iowait irq softirq steal (guest time is in user).
	const total = v.slice(0, 8).reduce((a, b) => a + (b || 0), 0);
	return { idle: v[3] + (v[4] || 0), total: total };
}

function _mem(s) {
	const get = key => {
		const m = s.match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
		return m ? Number(m[1]) : 0;
	};
	return { total: get("MemTotal"), available: get("MemAvailable") };
}

function _net(s) {
	let rx = 0;
	let tx = 0;
	s.split("\n").forEach(line => {
		const m = line.match(/^\s*([^:|]+):\s*(.*)$/);
		if (!m || m[1].trim() === "lo")
			return;
		const f = m[2].trim().split(/\s+/).map(Number);
		rx += f[0] || 0;
		tx += f[8] || 0;
	});
	return { rx: rx, tx: tx };
}

function cpuPercent(prev, cur) {
	if (!prev || !cur)
		return 0;
	const dt = cur.total - prev.total;
	return dt > 0 ? Math.round(100 * (1 - (cur.idle - prev.idle) / dt)) : 0;
}

function ramPercent(mem) {
	return mem.total > 0 ? 100 * (mem.total - mem.available) / mem.total : 0;
}

// Bytes per second up and down; 0 without a previous sample or after a
// counter reset.
function netSpeed(prev, cur, seconds) {
	if (!prev || !cur || seconds <= 0)
		return [0, 0];
	return [Math.max(0, Math.round((cur.tx - prev.tx) / seconds)), Math.max(0, Math.round((cur.rx - prev.rx) / seconds))];
}

// GiB, labelled GB as on Windows.
function diskGB(bytes) {
	return Math.round(bytes / 1073741824);
}

// Bloom formatBytes: "512B", "1.5K", "2.0M".
function formatBytes(bytes) {
	if (bytes < 1024)
		return `${bytes}B`;
	if (bytes < 1024 * 1024)
		return `${(bytes / 1024).toFixed(1)}K`;
	return `${(bytes / (1024 * 1024)).toFixed(1)}M`;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_stats.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 9 passed, 0 failed`.

- [ ] **Step 5: Create `shell/services/SystemStats.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "stats.js" as Logic

// CPU, RAM, free disk and network speed for the status widgets. Read every
// 3 s as Bloom does, but only while something holds the service (a status
// strip showing a stats widget), so a hidden widget costs nothing.
Singleton {
	id: root

	property int cpu: 0
	property real ram: 0
	property int disk: 0
	property int up: 0
	property int down: 0

	property var _holders: ({})
	readonly property bool active: Object.keys(root._holders).length > 0
	property var _prev: null
	property real _prevAt: 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	function _sample() {
		if (!proc.running)
			proc.running = true;
	}

	// Deltas across a pause would average the whole pause, so start fresh.
	onActiveChanged: if (!active) root._prev = null

	Timer {
		interval: 3000
		repeat: true
		triggeredOnStart: true
		running: root.active
		onTriggered: root._sample()
	}

	// CPU and network need two samples; take the second one soon after the
	// first instead of showing 0 for 3 s.
	Timer {
		id: followUp
		interval: 500
		onTriggered: root._sample()
	}

	Process {
		id: proc
		command: ["sh", "-c", "cat /proc/stat; echo ---; cat /proc/meminfo; echo ---; cat /proc/net/dev; echo ---; df -B1 --output=avail / | tail -n 1"]
		stdout: StdioCollector {
			onStreamFinished: {
				const cur = Logic.parse(text);
				if (!cur) {
					console.warn("bloom stats: could not read system counters");
					return;
				}
				const now = Date.now();
				const first = root._prev === null;
				root.cpu = Logic.cpuPercent(first ? null : root._prev.cpu, cur.cpu);
				root.ram = Logic.ramPercent(cur.mem);
				root.disk = Logic.diskGB(cur.diskAvail);
				const speed = Logic.netSpeed(first ? null : root._prev.net, cur.net, (now - root._prevAt) / 1000);
				root.up = speed[0];
				root.down = speed[1];
				root._prev = cur;
				root._prevAt = now;
				if (first && root.active)
					followUp.restart();
			}
		}
	}
}
```

- [ ] **Step 6: Run the whole suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`; qmllint accepts `SystemStats.qml`).

```bash
git add shell/services/stats.js shell/services/SystemStats.qml tests/qml/tst_stats.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add on-demand system stats service

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Battery

**Files:**
- Create: `shell/services/battery.js`, `shell/services/Battery.qml`, `shell/modules/notch/BatteryIcon.qml`, `tests/qml/tst_battery.qml`

**Interfaces:**
- Produces:
  - `battery.js`:
    - `formatDuration(seconds) → string`
    - `tooltip(d: {level, charging, pluggedIn, secondsLeft, secondsToFull, healthPercent, powerMode, energySaver}) → string`
    - `fillKind(level, charging, threshold) → "charging"|"low"|"normal"`
  - Singleton `Battery`: `available: bool`, `level: int`, `charging: bool`, `pluggedIn: bool`, `threshold: int`, `powerMode: string`, `tooltip: string`.
  - QML type `BatteryIcon`: `level: int`, `charging: bool`, `threshold: int`, `color: color` (the shell and the normal fill), and `kind: string` (readonly). Implicit size 20×14.

- [ ] **Step 1: Write the failing test `tests/qml/tst_battery.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/services/battery.js" as Battery
import "../../shell/modules/notch"

Item {
	id: host
	width: 80
	height: 20

	Rectangle { anchors.fill: parent; color: "black" }
	BatteryIcon { id: charging; level: 50; charging: true; threshold: 20 }
	BatteryIcon { id: low; x: 30; level: 15; threshold: 20; color: "white" }

	TestCase {
		name: "Battery"
		when: windowShown

		function base(props) {
			const d = { level: 80, charging: false, pluggedIn: false, secondsLeft: 0, secondsToFull: 0, healthPercent: null, powerMode: "", energySaver: false };
			for (const k in props) d[k] = props[k];
			return d;
		}

		// Bloom batteryTooltip.ts, line for line.
		function test_tooltipLines() {
			compare(Battery.tooltip(base({ level: 100, pluggedIn: true })), "Fully charged (100%)");
			compare(Battery.tooltip(base({ level: 60, pluggedIn: true, charging: true, secondsToFull: 2700 })),
				"60% available (plugged in, charging)\nAbout 45 min until full");
			compare(Battery.tooltip(base({ level: 60, pluggedIn: true })), "60% available (plugged in, not charging)");
			compare(Battery.tooltip(base({ level: 42, secondsLeft: 11520 })), "3 hr 12 min (42%) remaining");
			compare(Battery.tooltip(base({ level: 42 })), "42% remaining");
			compare(Battery.tooltip(base({ level: 42, powerMode: "Balanced", energySaver: true, healthPercent: 87 })),
				"42% remaining\nPower mode: Balanced\nEnergy saver is on\nBattery health: 87% of original capacity");
		}

		function test_formatDuration() {
			compare(Battery.formatDuration(20), "1 min");
			compare(Battery.formatDuration(3600), "1 hr");
			compare(Battery.formatDuration(11520), "3 hr 12 min");
		}

		function test_fillKind() {
			compare(Battery.fillKind(15, true, 20), "charging");
			compare(Battery.fillKind(20, false, 20), "low");
			compare(Battery.fillKind(21, false, 20), "normal");
		}

		function test_iconFillColours() {
			const img = grabImage(host);
			// The fill starts at x 3.8, y 2.5 of the 20x10 glyph, which sits 2 px down.
			verify(Qt.colorEqual(img.pixel(5, 7), "#32d74b"), `charging fill ${img.pixel(5, 7)}`);
			verify(Qt.colorEqual(img.pixel(30 + 5, 7), "#ff453a"), `low fill ${img.pixel(30 + 5, 7)}`);
			compare(charging.implicitWidth, 20);
			compare(charging.implicitHeight, 14);
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_battery.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile()` (battery.js unavailable, or BatteryIcon is not a type).

- [ ] **Step 3: Create `shell/services/battery.js`**

```js
// Battery tooltip and fill colour, ported from Bloom batteryTooltip.ts and
// App.tsx BatteryIcon. Plain JS (shared with tests).

// Durations as the Windows taskbar writes them: "3 hr 12 min", "45 min", "1 hr".
function formatDuration(seconds) {
	const minutes = Math.max(1, Math.round(seconds / 60));
	const hours = Math.floor(minutes / 60);
	const rest = minutes % 60;
	if (hours === 0)
		return `${rest} min`;
	return rest === 0 ? `${hours} hr` : `${hours} hr ${rest} min`;
}

function tooltip(d) {
	const lines = [];
	if (d.pluggedIn && d.level >= 100 && !d.charging)
		lines.push(`Fully charged (${d.level}%)`);
	else if (d.pluggedIn)
		lines.push(`${d.level}% available (plugged in${d.charging ? ", charging" : ", not charging"})`);
	else if (d.secondsLeft)
		lines.push(`${formatDuration(d.secondsLeft)} (${d.level}%) remaining`);
	else
		lines.push(`${d.level}% remaining`);
	if (d.charging && d.secondsToFull)
		lines.push(`About ${formatDuration(d.secondsToFull)} until full`);
	if (d.powerMode)
		lines.push(`Power mode: ${d.powerMode}`);
	if (d.energySaver)
		lines.push("Energy saver is on");
	if (d.healthPercent !== null && d.healthPercent !== undefined)
		lines.push(`Battery health: ${d.healthPercent}% of original capacity`);
	return lines.join("\n");
}

function fillKind(level, charging, threshold) {
	if (charging)
		return "charging";
	return level <= threshold ? "low" : "normal";
}
```

- [ ] **Step 4: Create `shell/modules/notch/BatteryIcon.qml`**

```qml
import QtQuick
import QtQuick.Shapes
import "../../common/tokens.js" as Tokens
import "../../services/battery.js" as Logic

// Bloom's battery glyph (App.tsx BatteryIcon): a 14x8.5 shell with a tip and
// a fill that is green while charging and red at or under the threshold. The
// SVG strokes are centred on their path, so the shell rectangle is grown by
// half the stroke to match.
Item {
	id: root

	property int level: 100
	property bool charging: false
	property int threshold: 20
	property color color: "white"
	readonly property string kind: Logic.fillKind(level, charging, threshold)
	readonly property color _faint: Qt.rgba(color.r, color.g, color.b, 0.35)

	implicitWidth: 20
	implicitHeight: 14

	Item {
		// The 20x10 glyph, centred in the 14 px row.
		y: 2
		width: 20
		height: 10

		Rectangle {
			x: 2 - 0.55
			y: 0.75 - 0.55
			width: 14 + 1.1
			height: 8.5 + 1.1
			radius: 2.4 + 0.55
			color: "transparent"
			border.width: 1.1
			border.color: root._faint
			antialiasing: true
		}

		Rectangle {
			x: 17.5 - 0.6
			y: 3.5
			width: 1.2
			height: 3
			radius: 0.6
			color: root._faint
		}

		Rectangle {
			x: 3.8
			y: 2.5
			height: 5
			radius: 1
			width: Math.max(0.5, Math.min(Math.max(root.level, 0), 100) / 100 * 10.4)
			color: root.kind === "charging" ? Tokens.status.green : root.kind === "low" ? Tokens.status.red : root.color
		}
	}

	// Charging bolt, centred on the shell (Bloom: left 9px, top 50%).
	Shape {
		visible: root.charging
		x: 9 - 3.5
		y: 7 - 5
		width: 7
		height: 10
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			fillColor: "white"
			strokeWidth: -1
			scale: Qt.size(7 / 8, 10 / 12)
			PathSvg { path: "M4.5 0L0 7H3.5L2.5 12L8 5H4.5L5.5 0H4.5Z" }
		}
	}
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_battery.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 6 passed, 0 failed`.
- If `test_iconFillColours` reads an antialiased edge colour, the sample point is wrong, not the icon. Pick a pixel nearer the fill's centre: x between 4 and 6, y 6–8 in host coordinates.

- [ ] **Step 6: Create `shell/services/Battery.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "battery.js" as Logic

// The laptop battery for the notch (UPower display device), with Bloom's
// tooltip text. `available` is false on machines without a laptop battery,
// and the battery widget hides then.
Singleton {
	id: root

	readonly property var device: UPower.displayDevice
	readonly property bool available: root.device?.isLaptopBattery ?? false
	readonly property int level: Math.round((root.device?.percentage ?? 0) * 100)
	readonly property bool charging: root.device?.state === UPowerDeviceState.Charging
	readonly property bool pluggedIn: !UPower.onBattery
	readonly property int threshold: Settings.values["bloom-low-battery-threshold"]
	readonly property string powerMode: {
		switch (PowerProfiles.profile) {
		case PowerProfile.PowerSaver:
			return "Power saver";
		case PowerProfile.Performance:
			return "Performance";
		case PowerProfile.Balanced:
			return "Balanced";
		}
		return "";
	}
	readonly property string tooltip: Logic.tooltip({
		level: root.level,
		charging: root.charging,
		pluggedIn: root.pluggedIn,
		secondsLeft: root.device?.timeToEmpty ?? 0,
		secondsToFull: root.device?.timeToFull ?? 0,
		healthPercent: root.device?.healthSupported ? Math.round(root.device.healthPercentage) : null,
		powerMode: root.powerMode,
		energySaver: PowerProfiles.profile === PowerProfile.PowerSaver
	})
}
```

- [ ] **Step 7: Run the whole suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add shell/services/battery.js shell/services/Battery.qml shell/modules/notch/BatteryIcon.qml tests/qml/tst_battery.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add battery service and Bloom battery icon

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Weather

**Files:**
- Create: `shell/services/weather.js`, `shell/services/Weather.qml`, `tests/qml/tst_weather.qml`

**Interfaces:**
- Consumes: `StateFile` (phase 1), `Settings`.
- Produces:
  - `weather.js`:
    - data: `WMO`, `DEFAULT_LOCATION`
    - `forecastUrl(lat, lon, unit) → string`
    - parsers, each returning a value or `null`: `parseForecast(json) → {temperature, condition, isDay}`, `parseIpapi(json)`, `parseIpApi(json)` (each location is `{lat, lon, city}`)
    - text: `icon(condition, isDay) → lucide name`, `label(temperature, unit) → string`, `tooltip(condition, city) → string`
    - `afterFetch(state, result) → state`: keeps the last value when `result` is null.
  - Singleton `Weather`:
    - `temperature: var` (number or null), `condition`, `isDay`, `city`;
    - `shown: bool`, `label`, `icon`, `tooltip`;
    - `refresh()`.

- [ ] **Step 1: Write the failing test `tests/qml/tst_weather.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/services/weather.js" as Weather

TestCase {
	name: "Weather"

	function test_forecastUrl() {
		compare(Weather.forecastUrl(12.5, 80.25, "celsius"),
			"https://api.open-meteo.com/v1/forecast?latitude=12.5&longitude=80.25&current=temperature_2m,weather_code,is_day&timezone=auto");
		verify(Weather.forecastUrl(1, 2, "fahrenheit").endsWith("&temperature_unit=fahrenheit"));
	}

	function test_parseForecast() {
		compare(Weather.parseForecast({ current: { temperature_2m: 27.6, weather_code: 2, is_day: 1 } }),
			{ temperature: 28, condition: "Partly Cloudy", isDay: true });
		compare(Weather.parseForecast({ current: { temperature_2m: 10, weather_code: 42, is_day: 0 } }).condition, "Unknown");
	}

	// Review focus 3: Bloom's truthiness check dropped 0 °C as invalid.
	function test_parseForecastKeepsZero() {
		compare(Weather.parseForecast({ current: { temperature_2m: 0, weather_code: 0, is_day: 1 } }).temperature, 0);
	}

	function test_parseForecastRejectsBadShapes() {
		compare(Weather.parseForecast(null), null);
		compare(Weather.parseForecast({}), null);
		compare(Weather.parseForecast({ current: { temperature_2m: "warm" } }), null);
	}

	function test_geolocation() {
		compare(Weather.parseIpapi({ latitude: 13.08, longitude: 80.27, city: "Chennai" }), { lat: 13.08, lon: 80.27, city: "Chennai" });
		compare(Weather.parseIpapi({ error: true, reason: "RateLimited" }), null);
		compare(Weather.parseIpApi({ status: "success", lat: 13.08, lon: 80.27, city: "Chennai" }), { lat: 13.08, lon: 80.27, city: "Chennai" });
		compare(Weather.parseIpApi({ status: "fail" }), null);
		compare(Weather.DEFAULT_LOCATION, { lat: 28.6139, lon: 77.209, city: "Delhi" });
	}

	// Bloom getWeatherIcon, with lucide-static names.
	function test_icon() {
		compare(Weather.icon("Clear", true), "sun");
		compare(Weather.icon("Mostly Clear", false), "moon");
		compare(Weather.icon("Overcast", true), "cloud");
		compare(Weather.icon("Foggy", true), "cloud-fog");
		compare(Weather.icon("Freezing Drizzle", true), "cloud-drizzle");
		compare(Weather.icon("Rain Showers", true), "cloud-rain");
		compare(Weather.icon("Snow Showers", true), "cloud-snow");
		compare(Weather.icon("Stormy", true), "cloud-lightning");
		compare(Weather.icon("Unknown", true), "thermometer");
	}

	function test_text() {
		compare(Weather.label(28, "celsius"), "28°C");
		compare(Weather.label(82, "fahrenheit"), "82°F");
		compare(Weather.tooltip("Partly Cloudy", "Chennai"), "Partly Cloudy — Chennai");
		compare(Weather.tooltip("Partly Cloudy", ""), "Partly Cloudy");
	}

	// Review focus 3: a failed fetch keeps the last reading.
	function test_failedFetchKeepsCache() {
		const last = { temperature: 28, condition: "Clear", isDay: true, city: "Chennai" };
		compare(Weather.afterFetch(last, null), last);
		compare(Weather.afterFetch(last, { temperature: 30, condition: "Overcast", isDay: false, city: "Chennai" }),
			{ temperature: 30, condition: "Overcast", isDay: false, city: "Chennai" });
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_weather.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile() Script … weather.js unavailable`.

- [ ] **Step 3: Create `shell/services/weather.js`**

```js
// Weather parsing and text, ported from Bloom hooks/useWeather.ts. Plain JS
// (shared with tests).

// WMO weather interpretation codes (https://open-meteo.com/en/docs).
var WMO = {
	0: "Clear", 1: "Mostly Clear", 2: "Partly Cloudy", 3: "Overcast",
	45: "Foggy", 48: "Foggy",
	51: "Drizzle", 53: "Drizzle", 55: "Drizzle", 56: "Freezing Drizzle", 57: "Freezing Drizzle",
	61: "Rainy", 63: "Rainy", 65: "Rainy", 66: "Freezing Rain", 67: "Freezing Rain",
	71: "Snowy", 73: "Snowy", 75: "Snowy", 77: "Snowy",
	80: "Rain Showers", 81: "Rain Showers", 82: "Rain Showers", 85: "Snow Showers", 86: "Snow Showers",
	95: "Stormy", 96: "Stormy", 99: "Stormy"
};

// Bloom's last-resort location.
var DEFAULT_LOCATION = { lat: 28.6139, lon: 77.209, city: "Delhi" };

function forecastUrl(lat, lon, unit) {
	const unitParam = unit === "fahrenheit" ? "&temperature_unit=fahrenheit" : "";
	return `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code,is_day&timezone=auto${unitParam}`;
}

// Bloom tested `!temperature_2m`, which rejected 0 °C; a type check keeps it.
function parseForecast(json) {
	const c = json && json.current;
	if (!c || typeof c.temperature_2m !== "number")
		return null;
	return { temperature: Math.round(c.temperature_2m), condition: WMO[c.weather_code] || "Unknown", isDay: c.is_day === 1 };
}

function parseIpapi(json) {
	const lat = json && (json.latitude || json.lat);
	const lon = json && (json.longitude || json.lon);
	return lat && lon ? { lat: lat, lon: lon, city: json.city || "" } : null;
}

function parseIpApi(json) {
	return json && json.lat && json.lon ? { lat: json.lat, lon: json.lon, city: json.city || "" } : null;
}

function icon(condition, isDay) {
	switch (condition) {
	case "Clear":
	case "Mostly Clear":
		return isDay ? "sun" : "moon";
	case "Partly Cloudy":
	case "Overcast":
		return "cloud";
	case "Foggy":
		return "cloud-fog";
	case "Drizzle":
	case "Freezing Drizzle":
		return "cloud-drizzle";
	case "Rainy":
	case "Rain Showers":
	case "Freezing Rain":
		return "cloud-rain";
	case "Snowy":
	case "Snow Showers":
		return "cloud-snow";
	case "Stormy":
		return "cloud-lightning";
	}
	return "thermometer";
}

function label(temperature, unit) {
	return `${temperature}°${unit === "fahrenheit" ? "F" : "C"}`;
}

function tooltip(condition, city) {
	return city ? `${condition} — ${city}` : condition;
}

// A failed fetch (null) keeps the last reading.
function afterFetch(state, result) {
	return result ? result : state;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_weather.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `Totals: 10 passed, 0 failed`.

- [ ] **Step 5: Create `shell/services/Weather.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import "weather.js" as Logic

// Current weather for the notch (Bloom useWeather): Open-Meteo for the
// configured coordinates, else IP geolocation (ipapi.co, then ip-api.com),
// else Delhi. Refreshes every 30 minutes, but only while the weather widget
// is enabled and configured. The last reading is cached in state so the
// widget has a value before the first fetch and while offline.
Singleton {
	id: root

	readonly property var _widgets: Settings.values["bloom-status-widgets"]
	readonly property bool wanted: Settings.values["bloom-weather-enabled"]
		&& (root._widgets.left.indexOf("weather") >= 0 || root._widgets.right.indexOf("weather") >= 0)
	readonly property string unit: Settings.values["bloom-temp-unit"]

	property var temperature: null
	property string condition: ""
	property bool isDay: true
	property string city: ""

	readonly property bool shown: Settings.values["bloom-weather-enabled"] && root.temperature !== null
	readonly property string label: root.temperature === null ? "" : Logic.label(root.temperature, root.unit)
	readonly property string icon: Logic.icon(root.condition, root.isDay)
	readonly property string tooltip: Logic.tooltip(root.condition, root.city)

	property bool _busy: false

	function refresh() {
		if (root._busy)
			return;
		root._busy = true;
		root._locate(loc => root._get(Logic.forecastUrl(loc.lat, loc.lon, root.unit), json => {
			const r = Logic.parseForecast(json);
			if (r) {
				root._set({ temperature: r.temperature, condition: r.condition, isDay: r.isDay, city: loc.city });
				cache.save({ temperature: r.temperature, condition: r.condition, isDay: r.isDay, city: loc.city, unit: root.unit });
			} else {
				console.warn("bloom weather: update failed; keeping the last reading");
			}
			root._busy = false;
		}));
	}

	function _set(s) {
		root.temperature = s.temperature;
		root.condition = s.condition;
		root.isDay = s.isDay;
		root.city = s.city;
	}

	function _locate(done) {
		const lat = Settings.values["bloom-weather-lat"];
		const lon = Settings.values["bloom-weather-lon"];
		if (lat !== null && lon !== null) {
			done({ lat: lat, lon: lon, city: Settings.values["bloom-weather-city"] });
			return;
		}
		root._get("https://ipapi.co/json/", json => {
			const a = Logic.parseIpapi(json);
			if (a) {
				done(root._named(a));
				return;
			}
			// ip-api.com's free tier is HTTP-only (its https endpoint needs a paid key).
			root._get("http://ip-api.com/json/?fields=status,lat,lon,city,country", json2 => {
				const b = Logic.parseIpApi(json2);
				done(b ? root._named(b) : Logic.DEFAULT_LOCATION);
			});
		});
	}

	// A city typed in settings names the place even when the coordinates come
	// from IP geolocation.
	function _named(loc) {
		const city = Settings.values["bloom-weather-city"];
		return city ? { lat: loc.lat, lon: loc.lon, city: city } : loc;
	}

	function _get(url, done) {
		const xhr = new XMLHttpRequest();
		xhr.timeout = 10000;
		xhr.onreadystatechange = () => {
			if (xhr.readyState !== XMLHttpRequest.DONE)
				return;
			let json = null;
			if (xhr.status === 200) {
				try {
					json = JSON.parse(xhr.responseText);
				} catch (e) {
					json = null;
				}
			}
			done(json);
		};
		xhr.open("GET", url);
		xhr.send();
	}

	StateFile {
		id: cache
		name: "weather"
		defaultValue: ({})
		onLoadedChanged: {
			const v = cache.value;
			if (cache.loaded && root.temperature === null && typeof v.temperature === "number" && v.unit === root.unit)
				root._set({ temperature: v.temperature, condition: v.condition || "", isDay: v.isDay !== false, city: v.city || "" });
		}
	}

	Timer {
		interval: 30 * 60 * 1000
		repeat: true
		triggeredOnStart: true
		running: root.wanted
		onTriggered: root.refresh()
	}

	onUnitChanged: if (root.wanted) root.refresh()

	Connections {
		target: Settings
		function onSettingChanged(key) {
			if (root.wanted && ["bloom-weather-lat", "bloom-weather-lon", "bloom-weather-city"].indexOf(key) >= 0)
				root.refresh();
		}
	}
}
```

- [ ] **Step 6: Run the whole suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`). Weather is not loaded by any surface yet, so no network calls happen in tests.

```bash
git add shell/services/weather.js shell/services/Weather.qml tests/qml/tst_weather.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add weather service with cached Open-Meteo readings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: The notch view

**Files:**
- Create: `shell/modules/notch/StatusWidget.qml`, `shell/modules/notch/StatusTooltip.qml`, `shell/modules/notch/NotchView.qml`, `tests/qml/tst_notchview.qml`

**Interfaces:**
- Consumes:
  - `notch.js` (Task 3), `stats.js` `formatBytes` (Task 4), `BatteryIcon` (Task 5);
  - `Spring`, `EdgeSurface`, `SvgIcon`, `tokens.js` (phase 1 and Task 2).
- Produces:
  - `StatusWidget` (Row):
    - `widgetId: string`, `icon: string`, `strokeWidth: real`, `label: string`, `textColor: color`, `battery: var`;
    - `hovered: bool` (readonly), `tooltipAnchor: Item`.
  - `StatusTooltip`: `text: string`, `bg: color`, `textColor: color`, `showFor(anchor: Item)`, `hideNow()`.
  - `NotchView` (Item):
    - inputs: `mode`, `edgeDelay`, `widgets`, `use24h`, `uiScale`, `overlapped`, `userVisible`, `bg`, `bgExpanded`, `textColor`, `textMuted`, `now`, `weather`, `battery`, `stats`, `ready`;
    - signals: `statsWanted(bool)`, `batteryHovered()`;
    - outputs: `hidden`, `statusHover`, `interaction`, `target`, `hitItem`, `bandItem`, `bandActive`;
    - methods: `peek(ms: int)`, `stateObject() → object`.

- [ ] **Step 1: Write the failing test `tests/qml/tst_notchview.qml`**

```qml
import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 1000
	height: 480

	Component {
		id: viewComponent
		NotchView {
			width: 1000
			height: 480
			weather: ({ shown: true, label: "28°C", icon: "sun", tooltip: "Clear — Chennai" })
			battery: ({ available: true, level: 80, charging: false, threshold: 20, tooltip: "80% remaining" })
		}
	}

	TestCase {
		name: "NotchView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		// After the drop-in: impacted, expanded and no longer startup-locked.
		function settle(v) {
			v.ready = true;
			tryCompare(v, "impacted", true, 1000);
			tryCompare(v, "startupAnimating", false, 3000);
		}

		function centre(v) { return { x: 500, y: v.target.height / 2 }; }

		function test_startupDropIn() {
			const v = make();
			compare(v.target.y, 250, "parked below before ready");
			v.ready = true;
			compare(v.target.y, 0);
			compare(v.target.width, 30.6, "a dot rising to the edge");
			tryCompare(v, "impacted", true, 1000);
			compare(v.target.width, 140);
			compare(v.target.height, 36);
			compare(v.target.edgeRadius, 0);
		}

		function test_hoverOpensTheStatusStrip() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(v.target.width, 300, "200 + 2 widgets x 50");
			mouseMove(v, 500, 300);
			tryCompare(v, "statusHover", false, 500);
			compare(v.target.width, 140);
		}

		function test_twentyFourHourClockIsNarrower() {
			const v = make({ use24h: true });
			settle(v);
			compare(v.target.width, 124);
		}

		// Review focus 4.
		function test_widgetWithoutDataIsHidden() {
			const v = make({ battery: { available: false } });
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(findChild(v, "widget-battery"), null);
			verify(findChild(v, "widget-weather") !== null);
			compare(v.target.width, 300, "width still counts configured widgets, as Bloom");
		}

		function test_tooltipAfterDelay() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			wait(600); // let the pill finish widening before locating the widget
			const w = findChild(v, "widget-battery");
			verify(w !== null);
			const p = w.mapToItem(v, w.width / 2, w.height / 2);
			mouseMove(v, p.x, p.y);
			const tip = findChild(v, "statusTooltip");
			verify(!tip.shown, "not before the delay");
			tryCompare(tip, "shown", true, 1000);
			compare(tip.text, "80% remaining");
			mouseMove(v, 500, 300);
			tryCompare(tip, "shown", false, 500);
		}

		function test_peekModeHidesUntilShown() {
			const v = make({ mode: "peek" });
			settle(v);
			verify(v.hidden);
			compare(v.target.y, -100);
			compare(v.target.width, 39.1);
			v.peek(300);
			verify(!v.hidden);
			tryCompare(v, "hidden", true, 1500);
		}

		// Review focus 1: the band takes input only while the notch is hidden.
		function test_bandOnlyWhileHidden() {
			const fixed = make();
			settle(fixed);
			verify(!fixed.bandActive);
			const smart = make({ mode: "smart", overlapped: true });
			settle(smart);
			verify(smart.hidden);
			verify(smart.bandActive);
			smart.overlapped = false;
			verify(!smart.hidden);
			verify(!smart.bandActive);
		}

		function test_edgeDwellRevealsAndGraceHides() {
			const v = make({ mode: "peek", edgeDelay: 200 });
			settle(v);
			verify(v.hidden);
			const b = v.bandItem.mapToItem(v, v.bandItem.width / 2, 1);
			mouseMove(v, b.x, b.y);
			wait(100);
			verify(v.hidden, "not before the dwell");
			tryCompare(v, "hidden", false, 1000);
			// The pointer never reaches the pill: the reveal lets go after the
			// 1 s hand-off, then the 800 ms grace runs.
			wait(1200);
			verify(!v.hidden, "hand-off, then grace");
			tryCompare(v, "hidden", true, 1500);
		}

		function test_smartModeFollowsOverlap() {
			const v = make({ mode: "smart" });
			settle(v);
			verify(!v.hidden);
			v.overlapped = true;
			verify(v.hidden);
			compare(v.target.y, -100);
		}

		function test_userVisibility() {
			const v = make();
			settle(v);
			v.userVisible = false;
			compare(v.target.y, -150);
			compare(v.target.opacity, 0);
		}

		function test_statsWantedOnlyForStatsWidgets() {
			const v = make({ widgets: { left: ["cpu"], right: ["battery"] } });
			const spy = createTemporaryQmlObject("import QtQuick; import QtTest; SignalSpy { signalName: \"statsWanted\" }", host);
			spy.target = v;
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(spy, "count", 1, 500);
			compare(spy.signalArguments[0][0], true);
			mouseMove(v, 500, 300);
			tryCompare(spy, "count", 2, 500);
			compare(spy.signalArguments[1][0], false);
		}

		// Review focus 5: a destroyed notch gives back its stats hold.
		function test_releasesHoldsOnDestruction() {
			const v = make({ widgets: { left: ["cpu"], right: [] } });
			let last = null;
			v.statsWanted.connect(w => last = w);
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(last, true);
			v.destroy();
			wait(0);
			compare(last, false);
		}

		function test_stateObject() {
			const v = make({ mode: "smart" });
			settle(v);
			const s = v.stateObject();
			compare(s.mode, "smart");
			compare(s.hidden, false);
			compare(s.width, 140);
			compare(s.visible, true);
		}
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_notchview.qml 2>&1 | grep -E "^FAIL|Totals"`
Expected: `FAIL!  : … compile() NotchView is not a type`.

- [ ] **Step 3: Create `shell/modules/notch/StatusWidget.qml`**

```qml
import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens

// One status widget (Bloom .passive-feature): a 12 px icon and an 11 px label.
// The battery widget draws Bloom's battery glyph instead of a Lucide icon.
Row {
	id: root

	required property string widgetId
	property string icon: ""
	property real strokeWidth: 2
	property string label: ""
	property color textColor: "white"
	property var battery: null
	readonly property bool hovered: hover.hovered
	readonly property Item tooltipAnchor: root

	objectName: "widget-" + widgetId
	spacing: Tokens.statusStrip.itemGap
	height: 14

	HoverHandler { id: hover }

	BatteryIcon {
		visible: root.widgetId === "battery"
		anchors.verticalCenter: parent.verticalCenter
		level: root.battery ? root.battery.level : 0
		charging: root.battery ? root.battery.charging : false
		threshold: root.battery ? root.battery.threshold : 20
		color: root.textColor
	}

	SvgIcon {
		visible: root.widgetId !== "battery"
		anchors.verticalCenter: parent.verticalCenter
		name: root.icon || "thermometer"
		size: Tokens.statusStrip.iconSize
		strokeWidth: root.strokeWidth
		color: root.textColor
	}

	Text {
		anchors.verticalCenter: parent.verticalCenter
		// Bloom nudges the label 0.5 px down for Inter's baseline.
		anchors.verticalCenterOffset: 0.5
		text: root.label
		color: root.textColor
		opacity: Tokens.statusStrip.labelOpacity
		font.family: Tokens.type.family
		font.pixelSize: Tokens.statusStrip.labelSize
		font.weight: Font.Medium
	}
}
```

- [ ] **Step 4: Create `shell/modules/notch/StatusTooltip.qml`**

```qml
import QtQuick
import QtQuick.Effects
import "../../common/tokens.js" as Tokens

// Bloom's status tooltip card: display only, hung 8 px under the pill and
// centred on its widget, fading in with a 4 px slide after 400 ms.
Item {
	id: root

	property string text: ""
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property color textColor: "white"
	// Bottom edge of the pill in the parent's coordinates.
	property real pillBottom: 36
	property bool shown: false
	property Item _anchor: null

	objectName: "statusTooltip"
	width: card.width
	height: card.height
	visible: opacity > 0
	opacity: root.shown ? 1 : 0
	Behavior on opacity {
		NumberAnimation {
			duration: Tokens.statusStrip.tooltip.fadeMs
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
		}
	}

	x: root._anchor ? root._anchor.mapToItem(root.parent, root._anchor.width / 2, 0).x - root.width / 2 : 0
	y: root.pillBottom + Tokens.statusStrip.tooltip.gap + (root.shown ? 0 : -Tokens.statusStrip.tooltip.slide)
	Behavior on y {
		NumberAnimation {
			duration: Tokens.statusStrip.tooltip.fadeMs
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
		}
	}

	function showFor(anchor) {
		root._anchor = anchor;
		delay.restart();
	}

	function hideNow() {
		delay.stop();
		root.shown = false;
	}

	Timer {
		id: delay
		interval: Tokens.statusStrip.tooltip.delayMs
		onTriggered: root.shown = true
	}

	RectangularShadow {
		anchors.fill: card
		offset.y: 6
		blur: 20
		radius: card.radius
		color: Qt.rgba(0, 0, 0, 0.35)
	}

	Rectangle {
		id: card
		width: label.implicitWidth + 2 * Tokens.statusStrip.tooltip.paddingH
		height: label.implicitHeight + 2 * Tokens.statusStrip.tooltip.paddingV
		radius: Tokens.statusStrip.tooltip.radius
		color: root.bg

		Text {
			id: label
			x: Tokens.statusStrip.tooltip.paddingH
			y: Tokens.statusStrip.tooltip.paddingV
			text: root.text
			color: root.textColor
			font.family: Tokens.type.family
			font.pixelSize: Tokens.statusStrip.tooltip.size
			font.weight: Font.Medium
			lineHeight: Tokens.statusStrip.tooltip.lineHeight
		}
	}
}
```

- [ ] **Step 5: Create `shell/modules/notch/NotchView.qml`**

```qml
import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../services/stats.js" as Stats
import "notch.js" as Logic

// The notch (Bloom App.tsx): a pill on the screen edge that springs between
// its startup drop-in, the collapsed clock, the hovered status strip and its
// hidden state in smart and peek modes. Pure UI: NotchWindow feeds it data
// and uses hitItem/bandItem for the layer surface's input mask. Sizes are in
// unscaled px; the stage scales them from the top centre.
Item {
	id: root

	property string mode: "fixed"
	property int edgeDelay: 200
	property var widgets: ({ left: ["weather"], right: ["battery"] })
	property bool use24h: false
	property real uiScale: 1
	property bool overlapped: false
	property bool userVisible: true
	property color bg: Qt.rgba(0, 0, 0, 0.8)
	property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property var now: new Date()
	property var weather: ({ shown: false, label: "", icon: "thermometer", tooltip: "" })
	property var battery: ({ available: false, level: 0, charging: false, threshold: 20, tooltip: "" })
	property var stats: ({ cpu: 0, ram: 0, disk: 0, up: 0, down: 0 })
	// Set once the surface is on screen; starts the drop-in.
	property bool ready: false

	signal statsWanted(bool wanted)
	signal batteryHovered()

	property bool impacted: false
	property bool expanded: false
	property bool startupAnimating: false
	property bool edgeArmed: false
	property bool eventPeek: false
	property string interaction: "none"
	property real fitWidth: 0

	readonly property bool pillHovered: pillHover.hovered
	readonly property bool hidden: Logic.isHidden(root.mode, root.overlapped, root.interaction, root.eventPeek, root.startupAnimating)
	// Bloom isHovered: the strip opens on the shown, expanded pill.
	readonly property bool statusHover: root.pillHovered && root.expanded && !root.hidden && root.userVisible
	readonly property int widgetCount: root.widgets.left.length + root.widgets.right.length
	readonly property var target: Logic.geometry(
		{ ready: root.ready, visible: root.userVisible, hidden: root.hidden, expanded: root.expanded, impacted: root.impacted },
		{ width: Logic.statusWidth(root.statusHover, root.widgetCount, root.fitWidth, root.use24h), height: Tokens.sizes.mainRow })

	readonly property Item hitItem: pillArea
	readonly property Item bandItem: band
	readonly property bool bandActive: root.hidden && root.mode !== "fixed" && root.userVisible

	readonly property bool _statsShown: root.statusHover && ["cpu", "ram", "disk", "net"].some(w => root.widgets.left.indexOf(w) >= 0 || root.widgets.right.indexOf(w) >= 0)
	property bool _statsHeld: false

	function peek(ms) {
		root.eventPeek = true;
		peekTimer.interval = ms;
		peekTimer.restart();
	}

	function stateObject() {
		return {
			mode: root.mode, hidden: root.hidden, hovered: root.statusHover, interaction: root.interaction,
			overlapped: root.overlapped, visible: root.userVisible,
			width: root.target.width, height: root.target.height, y: root.target.y
		};
	}

	on_StatsShownChanged: {
		root._statsHeld = root._statsShown;
		root.statsWanted(root._statsShown);
	}
	Component.onDestruction: if (root._statsHeld) root.statsWanted(false)

	onReadyChanged: {
		if (!root.ready)
			return;
		root.startupAnimating = true;
		impactTimer.restart();
		startupTimer.restart();
	}

	Timer {
		id: impactTimer
		interval: Tokens.notch.startup.impactDelayMs
		onTriggered: {
			root.impacted = true;
			root.expanded = true;
		}
	}

	Timer {
		id: startupTimer
		interval: Tokens.notch.startup.animatingMs
		onTriggered: root.startupAnimating = false
	}

	Timer {
		id: peekTimer
		onTriggered: root.eventPeek = false
	}

	// Bloom interactionState: active while hovered, then an 800 ms grace.
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

	Timer {
		id: graceTimer
		interval: Tokens.notch.graceMs
		onTriggered: root.interaction = "none"
	}

	onStatusHoverChanged: {
		if (!root.statusHover)
			root.fitWidth = 0;
		tooltip.hideNow();
	}

	// After an edge reveal the pill takes over once the pointer reaches it; if
	// it never does (no movement), the reveal lets go after the hand-off time.
	onBandActiveChanged: if (!root.bandActive && root.edgeArmed) handoff.restart()
	onPillHoveredChanged: {
		if (root.pillHovered) {
			handoff.stop();
			root.edgeArmed = false;
		}
	}

	Timer {
		id: handoff
		interval: Tokens.notch.edgeHandoffMs
		onTriggered: root.edgeArmed = false
	}

	Spring {
		id: wS
		stiffness: Tokens.springs.pillWidth.stiffness
		damping: Tokens.springs.pillWidth.damping
		mass: Tokens.springs.pillWidth.mass
		initial: Tokens.notch.startup.width
		target: root.target.width
	}

	Spring {
		id: hS
		stiffness: Tokens.springs.pillHeight.stiffness
		damping: Tokens.springs.pillHeight.damping
		mass: Tokens.springs.pillHeight.mass
		initial: Tokens.notch.startup.height
		target: root.target.height
	}

	Spring {
		id: yS
		stiffness: Tokens.springs.pillY.stiffness
		damping: Tokens.springs.pillY.damping
		mass: Tokens.springs.pillY.mass
		restDelta: Tokens.springs.pillY.restDelta
		initial: Tokens.notch.startup.y
		target: root.target.y
	}

	Spring {
		id: rS
		stiffness: Tokens.springs.radius.stiffness
		damping: Tokens.springs.radius.damping
		mass: Tokens.springs.radius.mass
		initial: Tokens.sizes.farRadius
		target: root.target.edgeRadius
	}

	Item {
		id: stage
		anchors.fill: parent
		scale: root.uiScale
		transformOrigin: Item.Top

		Item {
			id: pillLayer
			anchors.fill: parent
			opacity: root.target.opacity
			Behavior on opacity {
				NumberAnimation {
					duration: Tokens.notch.opacityMs
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
				}
			}

			EdgeSurface {
				x: (stage.width - width) / 2
				y: yS.value
				edge: "top"
				pillWidth: Math.max(0, wS.value)
				pillHeight: Math.max(0, hS.value)
				edgeRadius: rS.value
				farRadius: Tokens.sizes.farRadius
				flares: root.impacted
				color: root.statusHover ? root.bgExpanded : root.bg
				Behavior on color {
					ColorAnimation {
						duration: Tokens.notch.colorFadeMs
						easing.type: Easing.BezierSpline
						easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
					}
				}
			}
		}

		// The pill's box: hover, input mask and content.
		Item {
			id: pillArea
			x: (stage.width - width) / 2
			y: yS.value
			width: Math.max(0, wS.value)
			height: Math.max(0, hS.value)
			opacity: pillLayer.opacity

			HoverHandler { id: pillHover }

			Item {
				id: mainRow
				x: Tokens.sizes.padding
				width: Math.max(0, parent.width - 2 * Tokens.sizes.padding)
				height: Tokens.sizes.mainRow
				clip: true
				opacity: root.expanded && !root.hidden ? 1 : 0
				Behavior on opacity {
					NumberAnimation {
						duration: Tokens.easing.framerDefaultMs
						easing.type: Easing.BezierSpline
						easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1]
					}
				}

				Row {
					id: leftGroup
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					spacing: Tokens.statusStrip.groupGap
					opacity: root.statusHover ? 1 : 0
					visible: opacity > 0
					Behavior on opacity {
						NumberAnimation {
							duration: Tokens.statusStrip.fadeMs
							easing.type: Easing.BezierSpline
							easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
						}
					}
					Repeater {
						model: root.widgets.left
						delegate: widgetDelegate
					}
				}

				Text {
					id: clock
					anchors.centerIn: parent
					text: Logic.clockText(root.now, root.use24h)
					color: clockHover.hovered ? root.textMuted : root.textColor
					Behavior on color { ColorAnimation { duration: 200 } }
					font.family: Tokens.type.family
					font.pixelSize: Tokens.type.clock.size
					font.weight: Font.Medium
					font.letterSpacing: Tokens.type.clock.tracking
					scale: clockTap.pressed ? 0.95 : 1
					Behavior on scale { NumberAnimation { duration: 100 } }
					HoverHandler { id: clockHover }
					TapHandler { id: clockTap }
				}

				Row {
					id: rightGroup
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: Tokens.statusStrip.groupGap
					opacity: leftGroup.opacity
					visible: opacity > 0
					Repeater {
						model: root.widgets.right
						delegate: widgetDelegate
					}
				}
			}
		}

		// Bloom statusFitWidth: grows during a hover so a shrinking live label
		// doesn't make the notch jitter.
		readonly property real _needed: Logic.fitWidth(clock.implicitWidth, leftGroup.implicitWidth, rightGroup.implicitWidth)
		on_NeededChanged: if (root.statusHover && stage._needed > root.fitWidth) root.fitWidth = stage._needed

		StatusTooltip {
			id: tooltip
			bg: root.bgExpanded
			textColor: root.textColor
			pillBottom: yS.value + hS.value
		}

		// Edge reveal band (Wayland stand-in for Bloom's top-edge hook).
		Item {
			id: band
			x: (stage.width - width) / 2
			y: 0
			width: Tokens.notch.edgeBand.width
			height: Tokens.notch.edgeBand.height
			enabled: root.bandActive

			HoverHandler {
				id: bandHover
				onHoveredChanged: {
					if (bandHover.hovered) {
						if (root.edgeDelay <= 0)
							root.edgeArmed = true;
						else
							dwell.restart();
					} else if (root.bandActive) {
						// A real leave while hidden. Once the notch shows, the band
						// switches off under the pointer, and that is not a leave.
						dwell.stop();
						root.edgeArmed = false;
					}
				}
			}

			Timer {
				id: dwell
				interval: Math.max(1, root.edgeDelay)
				onTriggered: root.edgeArmed = true
			}
		}
	}

	Component {
		id: widgetDelegate

		// Only widgets with data exist at all, so a missing battery leaves no
		// gap in the row (Bloom renders nothing for it).
		Loader {
			id: slot
			required property string modelData
			readonly property bool hasData: (slot.modelData === "weather" && root.weather.shown)
				|| (slot.modelData === "battery" && root.battery.available)
				|| ["cpu", "ram", "disk", "net"].indexOf(slot.modelData) >= 0
			active: slot.hasData
			visible: slot.active

			sourceComponent: StatusWidget {
				id: w
				widgetId: slot.modelData
				textColor: root.textColor
				battery: root.battery
				icon: {
					switch (slot.modelData) {
					case "weather": return root.weather.icon;
					case "cpu": return "cpu";
					case "ram": return "memory-stick";
					case "disk": return "hard-drive";
					case "net": return "arrow-up-down";
					}
					return "";
				}
				strokeWidth: slot.modelData === "weather" ? 2.2 : 2
				label: {
					switch (slot.modelData) {
					case "weather": return root.weather.label;
					case "battery": return `${root.battery.level}%`;
					case "cpu": return `${root.stats.cpu}%`;
					case "ram": return `${Math.round(root.stats.ram)}%`;
					case "disk": return `${root.stats.disk}GB`;
					case "net": return `↑${Stats.formatBytes(root.stats.up)} ↓${Stats.formatBytes(root.stats.down)}`;
					}
					return "";
				}
				readonly property string tip: {
					switch (slot.modelData) {
					case "weather": return root.weather.tooltip;
					case "battery": return root.battery.tooltip;
					case "cpu": return "CPU Usage";
					case "ram": return "RAM Usage";
					case "disk": return "Free Disk Space";
					case "net": return "Network Speed";
					}
					return "";
				}
				onHoveredChanged: {
					if (w.hovered) {
						if (slot.modelData === "battery")
							root.batteryHovered();
						tooltip.text = w.tip;
						tooltip.showFor(w);
					} else {
						tooltip.hideNow();
					}
				}
			}
		}
	}
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_notchview.qml 2>&1 | grep -E "^FAIL|Totals|Actual|Expected" | head -20`
Expected: `Totals: 15 passed, 0 failed`. Any failure is a real defect: debug it with superpowers:systematic-debugging, and do not loosen the test.

- [ ] **Step 7: Run the whole suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -1` (expected: `all checks passed`).

```bash
git add shell/modules/notch/StatusWidget.qml shell/modules/notch/StatusTooltip.qml shell/modules/notch/NotchView.qml tests/qml/tst_notchview.qml
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: add the notch view with status strip and display modes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The notch on screen

**Files:**
- Create: `shell/services/HyprState.qml`, `shell/services/HyprEvents.qml`, `shell/modules/notch/NotchWindow.qml`, `tests/integration/sway.conf`, `tests/integration/test_notch.sh`
- Modify: `shell/shell.qml` (full replacement below), `tests/integration/lib.sh` (append)

**Interfaces:**
- Consumes:
  - `NotchView` (Task 7), `notch.js` `focusedWindow`/`notchRect`/`overlaps`/`statusWidth` (Task 3);
  - `Settings`, `Theme`, `Battery`, `Weather`, `SystemStats`.
- Produces:
  - Singleton `HyprState`: `available: bool`, `clients: var`, `monitors: var`, `hold(key, on)`, `refresh()`.
  - `NotchWindow` (a `PanelWindow` per screen), exposing `view`.
  - IPC target `notch`:
    - `state() → JSON array` (one `stateObject()` per screen);
    - `peek(ms: int) → "ok"`;
    - `setVisible(visible: bool) → "ok"`.
  - `lib.sh`: `start_sway`, `stop_sway`, `WAYLAND_DISPLAY_FOR_TEST`.

- [ ] **Step 1: Create `tests/integration/sway.conf`**

```
# Headless sway for integration tests. swaybg is disabled because sway kills
# its own process group when it cannot start it.
xwayland disable
swaybg_command -
output HEADLESS-1 resolution 1920x1080
```

- [ ] **Step 2: Append the sway helpers to `tests/integration/lib.sh`**

```bash

# Headless sway hosts the real layer surfaces. Its socket path must stay
# under 108 bytes, so it gets its own short runtime dir. Launched as a plain
# background job from some sandboxes sway is killed, so where a user systemd
# is reachable it runs as a transient unit.
SWAY_UNIT=""
SWAY_PID=""

start_sway() {
	local rt
	if [[ -d "/run/user/$UID" ]]; then
		rt="$(mktemp -d "/run/user/$UID/bt.XXXX")"
	else
		rt="$(mktemp -d)"
	fi
	chmod 700 "$rt"
	export XDG_RUNTIME_DIR="$rt"
	if systemctl --user show-environment >/dev/null 2>&1; then
		SWAY_UNIT="bloom-test-sway-$$"
		systemd-run --user --quiet --unit="$SWAY_UNIT" \
			-E XDG_RUNTIME_DIR="$rt" -E WLR_BACKENDS=headless -E WLR_RENDERER=pixman -E WLR_LIBINPUT_NO_DEVICES=1 \
			/usr/bin/sway -c "$ROOT/tests/integration/sway.conf"
	else
		WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
			sway -c "$ROOT/tests/integration/sway.conf" >"$TEST_TMP/sway.log" 2>&1 &
		SWAY_PID=$!
	fi
	wait_for "sway's Wayland socket" test -S "$rt/wayland-1"
	export WAYLAND_DISPLAY=wayland-1 QT_QPA_PLATFORM=wayland
}

stop_sway() {
	if [[ -n "$SWAY_UNIT" ]]; then
		systemctl --user stop "$SWAY_UNIT" 2>/dev/null || true
		systemctl --user reset-failed "$SWAY_UNIT" 2>/dev/null || true
	fi
	if [[ -n "$SWAY_PID" ]]; then
		kill "$SWAY_PID" 2>/dev/null || true
		wait "$SWAY_PID" 2>/dev/null || true
	fi
	[[ "$XDG_RUNTIME_DIR" == */bt.* ]] && rm -rf "$XDG_RUNTIME_DIR"
}
```

Then change `bloom_cleanup` in `lib.sh` so it stops sway before removing the temp dir. Its first lines become:

```bash
bloom_cleanup() {
	if [[ -n "$SHELL_PID" ]]; then
		kill "$SHELL_PID" 2>/dev/null || true
		wait "$SHELL_PID" 2>/dev/null || true
	fi
	if [[ -n "$SWAY_UNIT$SWAY_PID" ]]; then stop_sway; fi
	rm -rf "$TEST_TMP"
}
```

- [ ] **Step 3: Write the failing integration test `tests/integration/test_notch.sh`**

```bash
#!/usr/bin/env bash
# Runs the real shell with the notch enabled on headless sway: the layer
# surface loads cleanly, modes change live, peek and visibility work over IPC.
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

mkdir -p "$XDG_CONFIG_HOME/bloom"
# No network in tests: weather off.
printf '{ "bloom-enabled-modules": ["notch"], "bloom-weather-enabled": false }\n' >"$XDG_CONFIG_HOME/bloom/settings.json"
start_shell

state() { ipc notch state | jq -c ".[0] | {$1}"; }
state_is() { [[ "$(state "$1")" == "$2" ]]; }

wait_for "the notch to settle after the drop-in" state_is "hidden,width" '{"hidden":false,"width":140}'
pass "notch surface loads and settles at 140 px"

ipc settings set bloom-notch-mode peek >/dev/null
wait_for "peek mode to hide the notch" state_is "hidden,y" '{"hidden":true,"y":-100}'
pass "peek mode hides the notch"

assert_eq "$(ipc notch peek 1500)" "ok" "peek"
wait_for "the peek to show it" state_is "hidden" '{"hidden":false}'
wait_for "the peek to end" state_is "hidden" '{"hidden":true}'
pass "an event peek shows it for the given time"

# Review focus 2: smart mode without Hyprland is simply "not overlapped".
ipc settings set bloom-notch-mode smart >/dev/null
wait_for "smart mode to show it" state_is "hidden,overlapped" '{"hidden":false,"overlapped":false}'
pass "smart mode without Hyprland keeps the notch shown"

assert_eq "$(ipc notch setVisible false)" "ok" "setVisible"
wait_for "hiding by the user" state_is "visible,y" '{"visible":false,"y":-150}'
ipc notch setVisible true >/dev/null
wait_for "showing again" state_is "visible,y" '{"visible":true,"y":0}'
pass "setVisible hides and shows the notch"

# A CI container has no system D-Bus, so UPower/power-profiles warnings are
# expected there and only there.
problems="$(grep -E '^ *(WARN|ERROR|FATAL)' "$TEST_TMP/shell.log" || true)"
if [[ ! -S /run/dbus/system_bus_socket ]]; then
	problems="$(grep -viE 'upower|powerprofiles|dbus' <<<"$problems" || true)"
fi
[[ -z "$problems" ]] || fail "shell logged warnings or errors: $problems"
pass "no warnings or errors in the shell log"
```

Run: `chmod +x tests/integration/test_notch.sh && bash tests/integration/test_notch.sh`
Expected: FAIL at the first `wait_for` (`timed out waiting for: the notch to settle after the drop-in`), because the `notch` IPC target does not exist yet.

- [ ] **Step 4: Create `shell/services/HyprEvents.qml`**

```qml
import QtQuick
import Quickshell.Hyprland

// Hyprland's event stream, in its own file so the Hyprland module is only
// touched under Hyprland (using it elsewhere logs a warning).
Item {
	id: root

	signal changed()

	Connections {
		target: Hyprland
		function onRawEvent(event) {
			if (["openlayer", "closelayer", "screencast"].indexOf(event.name) < 0)
				root.changed();
		}
	}
}
```

- [ ] **Step 5: Create `shell/services/HyprState.qml`**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland windows and monitors (hyprctl -j) for features that react to them,
// like the smart notch. Refreshes only while something holds the service: on
// Hyprland events, and once a second because moving a floating window sends
// no event. Outside Hyprland it stays empty and quiet.
Singleton {
	id: root

	readonly property bool available: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""
	property var clients: []
	property var monitors: []

	property var _holders: ({})
	readonly property bool active: root.available && Object.keys(root._holders).length > 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	function refresh() {
		if (!clientsProc.running)
			clientsProc.running = true;
		if (!monitorsProc.running)
			monitorsProc.running = true;
	}

	onActiveChanged: if (root.active) root.refresh()

	Timer {
		interval: 1000
		repeat: true
		running: root.active
		onTriggered: root.refresh()
	}

	Timer {
		id: soon
		interval: 100
		onTriggered: root.refresh()
	}

	// Hyprland events, only while held (see HyprEvents.qml for why it's separate).
	Loader {
		id: events
		active: root.active
		source: "HyprEvents.qml"
	}

	Connections {
		target: events.item
		ignoreUnknownSignals: true
		function onChanged() { soon.restart(); }
	}

	Process {
		id: clientsProc
		command: ["hyprctl", "-j", "clients"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.clients = JSON.parse(text);
				} catch (e) {
					console.warn("bloom hypr: could not read clients");
				}
			}
		}
	}

	Process {
		id: monitorsProc
		command: ["hyprctl", "-j", "monitors"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.monitors = JSON.parse(text);
				} catch (e) {
					console.warn("bloom hypr: could not read monitors");
				}
			}
		}
	}
}
```

- [ ] **Step 6: Create `shell/modules/notch/NotchWindow.qml`**

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common/tokens.js" as Tokens
import "notch.js" as Logic

// One notch per screen: a fixed-size top layer surface (it never resizes,
// spec §3.3) whose input mask is the pill, or the edge band while hidden.
// Feeds NotchView from the services and computes smart-mode overlap.
PanelWindow {
	id: win

	required property var modelData
	readonly property alias view: view
	readonly property string _key: "notch-" + win.modelData.name

	screen: win.modelData
	anchors.top: true
	exclusiveZone: 0
	implicitWidth: Tokens.notch.surface.width
	implicitHeight: Tokens.notch.surface.height
	color: "transparent"
	WlrLayershell.namespace: "bloom:notch"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	mask: Region {
		item: view.hidden ? null : view.hitItem
		Region { item: view.bandActive ? view.bandItem : null }
	}

	readonly property var _monitor: HyprState.monitors.find(m => m.name === win.modelData.name) ?? null
	readonly property bool _overlapped: view.mode === "smart" && win._monitor !== null
		&& Logic.overlaps(Logic.focusedWindow(HyprState.clients, win._monitor),
			Logic.notchRect(win._monitor, Logic.statusWidth(false, view.widgetCount, 0, view.use24h), view.uiScale))

	readonly property bool _wantsHypr: view.mode === "smart"
	on_WantsHyprChanged: HyprState.hold(win._key, win._wantsHypr)
	Component.onCompleted: {
		HyprState.hold(win._key, win._wantsHypr);
		readyTimer.start();
	}
	Component.onDestruction: {
		HyprState.hold(win._key, false);
		SystemStats.hold(win._key, false);
	}

	// Let the surface map before the drop-in starts.
	Timer {
		id: readyTimer
		interval: 50
		onTriggered: view.ready = true
	}

	Timer {
		interval: 1000
		repeat: true
		running: true
		onTriggered: view.now = new Date()
	}

	NotchView {
		id: view
		anchors.fill: parent
		mode: Settings.values["bloom-notch-mode"]
		edgeDelay: Settings.values["bloom-notch-edge-delay"]
		widgets: Settings.values["bloom-status-widgets"]
		use24h: Settings.values["bloom-time-format-24h"]
		uiScale: Settings.values["bloom-scale"]
		overlapped: win._overlapped
		bg: Theme.bg
		bgExpanded: Theme.bgExpanded
		textColor: Theme.text
		textMuted: Theme.textMuted
		weather: ({ shown: Weather.shown, label: Weather.label, icon: Weather.icon, tooltip: Weather.tooltip })
		battery: ({ available: Battery.available, level: Battery.level, charging: Battery.charging, threshold: Battery.threshold, tooltip: Battery.tooltip })
		stats: ({ cpu: SystemStats.cpu, ram: SystemStats.ram, disk: SystemStats.disk, up: SystemStats.up, down: SystemStats.down })
		onStatsWanted: wanted => SystemStats.hold(win._key, wanted)
	}
}
```

- [ ] **Step 7: Replace `shell/shell.qml`**

```qml
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "modules/notch"

// Bloom shell root: loads the core services, the surfaces enabled in
// bloom-enabled-modules, and the IPC interface used by `bloom ipc` and keybinds.
ShellRoot {
	Component.onCompleted: console.log(`bloom: shell started (theme ${Theme.mode}, settings ${Settings.path})`)

	readonly property var _modules: Settings.values["bloom-enabled-modules"]

	LazyLoader {
		id: notchLoader
		active: _modules.indexOf("notch") >= 0

		Variants {
			model: Quickshell.screens
			NotchWindow {}
		}
	}

	IpcHandler {
		target: "shell"

		function ping(): string {
			return "pong";
		}
	}

	IpcHandler {
		target: "settings"

		// The value as JSON (null for an unknown key).
		function get(key: string): string {
			return JSON.stringify(Settings.get(key) ?? null);
		}

		// `value` is JSON (0.6, true, "\"light\""); a bare word is taken as a string.
		function set(key: string, value: string): string {
			let parsed;
			try {
				parsed = JSON.parse(value);
			} catch (e) {
				parsed = value;
			}
			return Settings.set(key, parsed) || "ok";
		}

		function nonDefaults(): string {
			return JSON.stringify(Settings.nonDefaults());
		}

		function warnings(): string {
			return JSON.stringify(Settings.warnings);
		}
	}

	IpcHandler {
		target: "theme"

		function mode(): string {
			return Theme.mode;
		}
	}

	IpcHandler {
		target: "notch"

		function _windows() {
			const variants = notchLoader.item;
			return variants ? variants.instances : [];
		}

		// One state object per screen, in screen order.
		function state(): string {
			return JSON.stringify(_windows().map(w => w.view.stateObject()));
		}

		// Shows a hidden notch for `ms` milliseconds, as Bloom's event peek.
		function peek(ms: int): string {
			_windows().forEach(w => w.view.peek(ms));
			return "ok";
		}

		// Bloom's visibility toggle.
		function setVisible(visible: bool): string {
			_windows().forEach(w => w.view.userVisible = visible);
			return "ok";
		}
	}
}
```

- [ ] **Step 8: Run the integration test to verify it passes**

Run: `bash tests/integration/test_notch.sh`
Expected: 6 `ok - …` lines.
- If `the notch to settle after the drop-in` times out, read the `log:` lines it prints. A QML error there (e.g. a mis-named import) is the cause; fix it and re-run.
- If the log shows `$HYPRLAND_INSTANCE_SIGNATURE is unset`, something touched the `Hyprland` singleton outside `HyprEvents.qml`. Find it and move it.

- [ ] **Step 9: Run the whole suite and commit**

Run: `tests/run-all.sh 2>&1 | tail -3`
Expected: `all checks passed` (the phase 1 shell test still passes; the notch is off by default).
- CI runs as root in its container, and sway may refuse to run as root there. That can only be checked on CI.
- If the CI log shows sway refusing root, add a step that creates a user (`useradd -m ci && chown -R ci .`) and runs `su ci -c "CI=true tests/run-all.sh"`. Record it as a ruling.

```bash
git add shell/services/HyprState.qml shell/services/HyprEvents.qml shell/modules/notch/NotchWindow.qml shell/shell.qml tests/integration/lib.sh tests/integration/sway.conf tests/integration/test_notch.sh
git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit -m "feat: put the notch on screen with smart-mode overlap and IPC

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Owner verification on the real session

This task changes the owner's session: it enables the notch module in `~/.config/bloom/settings.json` and starts the shell. **Ask the owner before Step 1.** ii keeps running. The notch appears under ii's bar, because the bar reserves the top strip.

**Files:** none.

- [ ] **Step 1: Owner approves; enable the notch and start the shell**

Run:
```bash
systemctl --user start bloom-shell
~/Projects/bloom-dots/bin/bloom ipc settings set bloom-enabled-modules '["notch"]'
```
Expected: `ok`. Within a second the notch drops in at the top centre, under ii's bar.

- [ ] **Step 2: Walk the owner through the parity checklist and record their answers**

Check each against Bloom (spec Appendix A); the owner judges feel:
1. **Drop-in:** a small dot rises, hits the edge, its flares fade in, and it widens to the clock.
2. **Collapsed:** 140 px wide, black at 80 %, clock `hh:mm AM/PM` in Inter 13/500, flush corners on top, 18 px rounded below.
3. **Hover:**
   - widens to 300 px with Bloom's spring;
   - the background darkens to 92 % over 0.3 s;
   - weather (left) and battery (right) fade in over 0.2 s.
4. **Battery tooltip:** after about 0.4 s a card shows Bloom's battery text under the pill.
5. **Leaving:** springs back to 140.
6. **Smart mode:**
   - Run `bloom ipc settings set bloom-notch-mode smart`.
   - Focus a tiled window: the notch hides upward.
   - Rest the pointer at the top centre for about 0.2 s: it drops back.
   - Move away: it hides about 0.8 s later.
7. **Peek mode:**
   - Run `bloom ipc settings set bloom-notch-mode peek`: the notch is hidden.
   - Run `bloom ipc notch peek 2000`: it shows for 2 s.
   - Then restore with `bloom ipc settings set bloom-notch-mode fixed`.
8. **Stats widgets:**
   - Run `bloom ipc settings set bloom-status-widgets '{"left":["cpu","ram"],"right":["battery","net"]}'`.
   - Hover: CPU, RAM and network values appear within about 0.5 s and update every 3 s.
   - Restore the default widgets afterwards.

- [ ] **Step 3: Check cost and logs**

Run:
```bash
pid=$(systemctl --user show -p MainPID --value bloom-shell)
a=$(awk '{print $14+$15}' /proc/$pid/stat); sleep 10; b=$(awk '{print $14+$15}' /proc/$pid/stat); echo "idle ticks/10s: $((b-a))"
journalctl --user -u bloom-shell --since "-10min" --no-pager | grep -E " (WARN|ERROR)" | head
```
Expected:
- idle at 10 or fewer ticks per 10 s (0.1 % or less of one core) with the notch collapsed in fixed mode;
- no warnings, or only the weather update failure while offline.

- [ ] **Step 4: Report to the owner** the checklist answers, the CPU figure and any log lines. Leave the notch enabled or disabled as they choose. To disable: `bloom ipc settings set bloom-enabled-modules '[]'`.
