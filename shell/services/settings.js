// Settings schema and validation. Plain JS shared by Settings.qml, the QML
// unit tests and tools/gen-settings-doc.mjs (no .pragma, no exports).
// Each phase adds the keys its surfaces use; docs/SETTINGS.md is generated
// from SCHEMA.

var MODULES = ["notch", "dock", "osd", "notifications", "launcher", "overview", "session", "lock", "polkit", "tray", "regiontools", "wallpaper", "cheatsheet", "osk", "overlay"];

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
	"bloom-calendar-enabled": {
		type: "bool", default: true,
		doc: "Show the Calendar and timer panel in the notch."
	},
	"bloom-notch-command-center-enabled": {
		type: "bool", default: true,
		doc: "Show Command Center and its Wi-Fi/Bluetooth subpanels in the notch."
	},
	"bloom-notch-devices-enabled": {
		type: "bool", default: true,
		doc: "Show the Connected Devices panel in the notch."
	},
	"bloom-notch-default-panel": {
		type: "enum", values: ["calendar", "command-center", "devices"], default: "calendar",
		doc: "Tool panel opened by clicking the collapsed notch when panel memory is off or unavailable."
	},
	"bloom-notch-panel-memory": {
		type: "bool", default: true,
		doc: "Reopen the last used notch tool panel."
	},
	"bloom-shelf-persist": {
		type: "bool", default: false,
		doc: "Keep Shelf items across shell restarts in local state."
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
	"bloom-wallpaper": {
		type: "string", maxLength: 4096, default: "",
		doc: "Wallpaper image or video. Empty uses the one set in ii."
	},
	"bloom-wallpaper-dir": {
		type: "string", maxLength: 4096, default: "",
		doc: "Folder the wallpaper picker lists. Empty means ~/Pictures/Wallpapers."
	},
	"bloom-lock-wallpaper": {
		type: "string", maxLength: 4096, default: "",
		doc: "Image behind the lock screen. Empty uses the desktop wallpaper, or black if there is none."
	},
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
	"bloom-dock-workspaces-enabled": {
		type: "bool",
		default: true,
		doc: "Show this monitor's workspaces at the start of the dock (Hyprland)."
	},
	"bloom-dock-preview-enabled": {
		type: "bool", default: true,
		doc: "Show live previews of an app's windows after hovering its dock icon."
	},
	"bloom-dock-extras-position": {
		type: "enum", values: ["off", "left", "right"], default: "off",
		doc: "Show drive, trash and folder extras beside the dock apps."
	},
	"bloom-dock-extras-drives": {
		type: "bool", default: true,
		doc: "Include removable and user-mounted drives in dock extras."
	},
	"bloom-dock-extras-recycle-bin": {
		type: "bool", default: true,
		doc: "Include the XDG trash in dock extras."
	},
	"bloom-dock-extras-hidden-drives": {
		type: "string", maxLength: 8192, default: "[]",
		doc: "JSON array of hidden drive UUIDs, or path:device IDs when a UUID is unavailable."
	},
	"bloom-dock-extras-folders": {
		type: "string", maxLength: 8192, default: "downloads",
		doc: "Comma-separated XDG user folders to show, such as downloads and documents."
	},
	"bloom-dock-extras-custom-folders": {
		type: "string", maxLength: 8192, default: "[]",
		doc: "JSON array of custom folder paths to show in dock extras."
	},
	"bloom-device-looks": {
		type: "string", maxLength: 8192, default: "{}",
		doc: "JSON object of the drawing picked for an audio device, by device name (Connected devices' Looks like)."
	},
	"bloom-osd-timeout": {
		type: "number", min: 250, max: 10000, default: 2000,
		doc: "Milliseconds an OSD stays visible after a volume or brightness change (Bloom: 2000)."
	},
	"bloom-volume-protection-enabled": {
		type: "bool", default: false,
		doc: "Limit sudden output-volume increases and enforce a maximum level."
	},
	"bloom-volume-max-jump": {
		type: "number", min: 1, max: 100, default: 10,
		doc: "Largest allowed output-volume increase in percentage points at once when protection is enabled."
	},
	"bloom-volume-max-level": {
		type: "number", min: 0, max: 200, default: 99,
		doc: "Maximum output volume in percent when protection is enabled."
	},
	"bloom-notifications-dnd": {
		type: "bool", default: false,
		doc: "Do Not Disturb suppresses normal and low notification cards while retaining history; critical cards still appear."
	},
	"bloom-notifications-timeout": {
		type: "number", min: 1000, max: 60000, default: 7000,
		doc: "Default notification card timeout in milliseconds when the sender does not specify one."
	},
	"bloom-notifications-history-limit": {
		type: "number", min: 0, max: 500, default: 200,
		doc: "Maximum number of non-transient notifications retained in local history."
	},
	"bloom-scale": {
		type: "number",
		min: 0.8,
		max: 1.3,
		// Chosen by the owner against Bloom on Windows at 125 % (2026-10-29).
		default: 1.15,
		doc: "Size of Bloom's surfaces."
	},
	"bloom-music-mode-enabled": {
		type: "bool",
		default: true,
		doc: "Show playing media in the notch: album art, visualizer and the music player."
	},
	"bloom-music-compact-notch": {
		type: "bool",
		default: true,
		doc: "Show playing media in the collapsed notch. When off, music appears only when you hover the notch."
	},
	"bloom-media-layout": {
		type: "enum",
		values: ["classic", "compact"],
		default: "classic",
		doc: "Music player layout: classic = large album art; compact = small art with a progress bar."
	},
	"bloom-media-visualizer-enabled": {
		type: "bool",
		default: true,
		legacyKey: "bloom-visualizer-enabled",
		doc: "Audio visualizer bars in music mode (needs cava)."
	},
	"bloom-media-album-art-enabled": {
		type: "bool",
		default: true,
		doc: "Album artwork in the collapsed notch."
	},
	"bloom-volume-hud-enabled": {
		type: "bool", default: true,
		doc: "Show the volume overlay."
	},
	"bloom-volume-edge-enabled": {
		type: "bool", default: true,
		doc: "Slide the volume overlay in from the left edge on hover."
	},
	"bloom-brightness-hud-enabled": {
		type: "bool", default: true,
		doc: "Show the brightness overlay."
	},
	"bloom-brightness-edge-enabled": {
		type: "bool", default: true,
		doc: "Slide the brightness overlay in from the right edge on hover."
	},
	"bloom-reduce-motion": {
		type: "bool", default: false,
		doc: "Land every spring at once instead of animating it."
	},
	"bloom-ai-model": {
		type: "enum",
		values: ["gemini-2.5-flash", "gemini-2.5-pro"],
		default: "gemini-2.5-flash",
		doc: "Gemini model for chat in the launcher."
	},
	"bloom-timer-sound-enabled": {
		type: "bool", default: true,
		doc: "Play a chime when the timer finishes."
	},
	"bloom-battery-sound-enabled": {
		type: "bool", default: true,
		doc: "Play a sound when the battery reaches the alert level."
	},
	"bloom-translucent-apps": {
		type: "bool", default: false,
		doc: "Apply Background Opacity and blur to app windows and the terminal."
	},
	"bloom-font-family": {
		type: "string", maxLength: 200, default: "",
		doc: "Font for Bloom's surfaces. Empty uses Bloom's own."
	},
	"bloom-translate-to": {
		type: "string", maxLength: 20, default: "en",
		doc: "Language translations go to, as a code such as en or hi. Text is sent to Google."
	},
	"bloom-low-power": {
		type: "enum",
		values: ["off", "auto", "on"],
		default: "off",
		doc: "Turns off album-art glow and slows live previews. Auto does this while on battery."
	},
	"bloom-media-ambience-enabled": {
		type: "bool",
		default: true,
		doc: "Coloured glow from the album art behind the open player."
	},
	"bloom-media-compact-glow-enabled": {
		type: "bool",
		default: true,
		doc: "Glow around the album art in the collapsed notch."
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
	// Keys Bloom used to store under another name: legacy -> modern.
	const legacy = {};
	keys().forEach(k => {
		if (SCHEMA[k].legacyKey)
			legacy[SCHEMA[k].legacyKey] = k;
	});
	Object.keys(obj).forEach(k => {
		if (!SCHEMA[k]) {
			const modern = legacy[k];
			if (!modern) {
				warnings.push(k + ": unknown setting, ignored");
				return;
			}
			// The modern key wins when both are present.
			if (Object.prototype.hasOwnProperty.call(obj, modern))
				return;
			const r = validateOne(modern, obj[k]);
			if (r.ok)
				values[modern] = r.value;
			else
				warnings.push(`${k}: ${r.error}; using default ${JSON.stringify(SCHEMA[modern].default)}`);
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
