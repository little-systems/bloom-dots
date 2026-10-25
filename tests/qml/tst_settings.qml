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
