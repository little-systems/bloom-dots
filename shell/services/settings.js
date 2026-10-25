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
