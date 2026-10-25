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
		compare(Object.keys(d).sort(), Settings.keys().sort());
	}

	function test_defaultsAreFreshCopies() {
		Settings.defaults()["bloom-enabled-modules"].push("notch");
		compare(Settings.defaults()["bloom-enabled-modules"], []);
	}

	// Review focus 2: Bloom for Windows stored every value as a string.
	function test_bloomStringForms() {
		compare(Settings.validateValue({ type: "bool" }, "true"), { ok: true, value: true });
		compare(Settings.validateValue({ type: "bool" }, "false"), { ok: true, value: false });
		compare(Settings.validateOne("bloom-theme-opacity", "0.8"), { ok: true, value: 0.8 });
		verify(!Settings.validateOne("bloom-theme-opacity", "").ok);
		verify(!Settings.validateValue({ type: "bool" }, "yes").ok);
	}

	function test_numberRange() {
		verify(Settings.validateOne("bloom-theme-opacity", 0).ok);
		verify(Settings.validateOne("bloom-theme-opacity", 1).ok);
		verify(!Settings.validateOne("bloom-theme-opacity", 1.5).ok);
		verify(!Settings.validateOne("bloom-theme-opacity", NaN).ok);
	}

	function test_enum() {
		verify(Settings.validateOne("bloom-theme-mode", "light").ok);
		verify(!Settings.validateOne("bloom-theme-mode", "neon").ok);
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
		compare(Settings.nonDefaults(v), { "bloom-theme-mode": "light" });
		compare(Settings.changedKeys(Settings.defaults(), v), ["bloom-theme-mode"]);
	}
}
