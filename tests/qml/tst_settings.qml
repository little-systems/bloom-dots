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
		compare(d["bloom-scale"], 1.15, "the owner's size against Bloom at 125 %");
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

	function test_osdAndNotificationDefaultsAndBounds() {
		const d = Settings.defaults();
		compare(d["bloom-osd-timeout"], 2000, "Bloom's 2 s");
		compare(d["bloom-volume-protection-enabled"], false);
		compare(d["bloom-volume-max-jump"], 10);
		compare(d["bloom-volume-max-level"], 99);
		compare(d["bloom-notifications-dnd"], false);
		compare(d["bloom-notifications-timeout"], 2500);
		compare(d["bloom-notifications-history-limit"], 200);
		verify(Settings.validateOne("bloom-osd-timeout", 250).ok);
		verify(!Settings.validateOne("bloom-osd-timeout", 0).ok);
		verify(!Settings.validateOne("bloom-volume-max-jump", 101).ok);
		verify(!Settings.validateOne("bloom-volume-max-level", -1).ok);
		compare(Settings.validateOne("bloom-notifications-dnd", "true"), { ok: true, value: true });
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

	function test_musicDefaults() {
		const d = Settings.defaults();
		compare(d["bloom-music-mode-enabled"], true);
		compare(d["bloom-music-compact-notch"], true);
		compare(d["bloom-media-layout"], "classic");
		compare(d["bloom-media-visualizer-enabled"], true);
		compare(d["bloom-media-album-art-enabled"], true);
		compare(d["bloom-media-ambience-enabled"], true);
		compare(d["bloom-media-compact-glow-enabled"], true);
		verify(!Settings.validateOne("bloom-media-layout", "grid").ok);
	}

	function test_pulseDefaults() {
		const d = Settings.defaults();
		compare(d["bloom-show-update-indicator"], true);
		compare(d["bloom-workspace-peek-enabled"], undefined, "the notch workspace pulse was removed (owner, 2026-10-27)");
		const off = Settings.validate({ "bloom-show-update-indicator": "false" });
		compare(off.values["bloom-show-update-indicator"], false, "Bloom's string form");
		compare(off.warnings, []);
	}

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

	function test_dockWorkspacesSetting() {
		compare(Settings.defaults()["bloom-dock-workspaces-enabled"], true);
		compare(Settings.validate({ "bloom-dock-workspaces-enabled": "false" }).values["bloom-dock-workspaces-enabled"], false);
	}

	function test_dockPreviewAndExtrasSettings() {
		const d = Settings.defaults();
		compare(d["bloom-dock-preview-enabled"], true);
		compare(d["bloom-dock-extras-position"], "off");
		compare(d["bloom-dock-extras-drives"], true);
		compare(d["bloom-dock-extras-recycle-bin"], true);
		compare(d["bloom-dock-extras-hidden-drives"], "[]");
		compare(d["bloom-dock-extras-folders"], "downloads");
		compare(d["bloom-dock-extras-custom-folders"], "[]");
		const v = Settings.validate({ "bloom-dock-preview-enabled": "false", "bloom-dock-extras-position": "left" });
		compare(v.values["bloom-dock-preview-enabled"], false);
		compare(v.values["bloom-dock-extras-position"], "left");
		compare(v.warnings, []);
		verify(!Settings.validateOne("bloom-dock-extras-position", "top").ok);
		verify(!Settings.validateOne("bloom-dock-extras-custom-folders", "x".repeat(8193)).ok);
	}

	// Bloom read the visualizer switch from an older key too.
	function test_legacyVisualizerKey() {
		const old = Settings.validate({ "bloom-visualizer-enabled": "false" });
		compare(old.values["bloom-media-visualizer-enabled"], false);
		compare(old.warnings, [], "the legacy key is not an unknown setting");
		const both = Settings.validate({ "bloom-visualizer-enabled": false, "bloom-media-visualizer-enabled": true });
		compare(both.values["bloom-media-visualizer-enabled"], true, "the modern key wins");
		compare(both.warnings, []);
		const bad = Settings.validate({ "bloom-visualizer-enabled": "maybe" });
		compare(bad.values["bloom-media-visualizer-enabled"], true);
		compare(bad.warnings.length, 1);
	}}
