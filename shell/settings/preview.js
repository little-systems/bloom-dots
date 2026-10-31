// Bloom's FeaturePreview, as rules: which scenes each tab has, which setting
// switches to which scene, the sample pill's size, and the caption. Pure.
var FEATURES = {
	general: [
		{ id: "clock", label: "Clock", description: "Time format and update status as they appear in the notch." },
		{ id: "battery", label: "Battery alert", description: "The alert threshold controls when the low-battery pulse appears." }
	],
	appearance: [{ id: "theme", label: "Theme", description: "Your current theme applied to Bloom's actual notch and dock surfaces." }],
	notch: [
		{ id: "resting", label: "Resting", description: "The same compact notch shown on your desktop." },
		{ id: "device", label: "Device alert", description: "Bloom's USB alert wakes the notch, even when it was hidden." },
		{ id: "music", label: "Music", description: "Music controls appear when a player is active." }
	],
	dock: [{ id: "dock", label: "Dock", description: "The Bloom dock rises from the bottom edge." }],
	overlays: [
		{ id: "volume", label: "Volume", description: "Bloom's volume HUD slides in from the left edge." },
		{ id: "brightness", label: "Brightness", description: "The brightness HUD appears on the right edge." }
	]
};

var SCENES = {
	general: { "bloom-time-format-24h": "clock", "bloom-show-update-indicator": "clock", "bloom-low-battery-threshold": "battery" },
	notch: {
		"bloom-music-mode-enabled": "music", "bloom-music-compact-notch": "music", "bloom-media-layout": "music",
		"bloom-media-ambience-enabled": "music", "bloom-media-compact-glow-enabled": "music"
	},
	overlays: {
		"bloom-volume-hud-enabled": "volume", "bloom-volume-edge-enabled": "volume",
		"bloom-brightness-hud-enabled": "brightness", "bloom-brightness-edge-enabled": "brightness"
	}
};

// Any other Notch setting goes to the resting pill; the other tabs have one scene.
function sceneFor(tab, key) {
	const scenes = SCENES[tab];
	if (scenes && scenes[key]) return scenes[key];
	if (tab === "notch") return "resting";
	return "";
}

function firstFeature(tab) {
	const list = FEATURES[tab];
	return list ? list[0].id : "";
}

function clock(use24) {
	return use24 ? "15:42" : "3:42 PM";
}

function pillWidth(feature, v, widgets, musicOpen, layout) {
	if (feature === "device") return 330;
	if (feature === "battery") return 235;
	if (feature === "music") {
		if (musicOpen) return layout === "compact" ? 300 : 340;
		return v["bloom-music-compact-notch"] ? 230 : 270;
	}
	if (feature === "resting") return Math.min(420, Math.max(300, 200 + widgets * 50 - (v["bloom-time-format-24h"] ? 16 : 0)));
	return 180;
}

function pillHeight(feature, musicOpen, layout, volumeOpen) {
	if (feature === "device") return 76;
	if (feature === "music" && musicOpen) return layout === "compact" ? 132 + (volumeOpen ? 36 : 0) : 120;
	return 36;
}

function widgetText(id, v) {
	if (id === "weather") return v["bloom-temp-unit"] === "fahrenheit" ? "72°F" : "22°C";
	return { battery: "85%", cpu: "24%", ram: "48%", disk: "120GB", net: "1MB" }[id] || "";
}

function onOff(value) {
	return value ? "on" : "off";
}

function description(feature, v, autostart, dockOn, fallback) {
	switch (feature) {
	case "clock":
		return (v["bloom-time-format-24h"] ? "24-hour time" : "12-hour time") + " · Launch at login " + onOff(autostart)
			+ " · Update available: dot " + onOff(v["bloom-show-update-indicator"]);
	case "battery":
		return "Sample battery: 15% · Alert threshold: " + v["bloom-low-battery-threshold"] + "%";
	case "theme":
		return v["bloom-theme-mode"] + " theme · " + Math.round(v["bloom-theme-opacity"] * 100) + "% opacity · "
			+ Math.round(v["bloom-scale"] * 100) + "% scale";
	case "resting": {
		const mode = v["bloom-notch-mode"];
		const weather = v["bloom-weather-enabled"] ? (v["bloom-temp-unit"] === "fahrenheit" ? "°F" : "°C") : "off";
		return mode + " mode · " + (mode === "fixed" ? "Always visible" : "Edge delay " + v["bloom-notch-edge-delay"] + "ms")
			+ " · Weather " + weather + " · Panel " + (v["bloom-notch-panel-memory"] ? "remembered" : v["bloom-notch-default-panel"]);
	}
	case "music":
		return "Music mode " + onOff(v["bloom-music-mode-enabled"]) + " · Compact " + onOff(v["bloom-music-compact-notch"])
			+ " · Saved layout: " + v["bloom-media-layout"] + " · Glow " + onOff(v["bloom-media-compact-glow-enabled"]);
	case "dock":
		return (dockOn ? v["bloom-dock-mode"] + " mode" : "Dock off") + " · Icon only " + onOff(v["bloom-dock-icon-only"])
			+ " · Extras " + v["bloom-dock-extras-position"] + " · Previews " + onOff(v["bloom-dock-preview-enabled"]);
	case "volume":
		return "Volume HUD " + onOff(v["bloom-volume-hud-enabled"]) + " · Edge hover " + onOff(v["bloom-volume-edge-enabled"]);
	case "brightness":
		return "Brightness HUD " + onOff(v["bloom-brightness-hud-enabled"]) + " · Edge hover " + onOff(v["bloom-brightness-edge-enabled"]);
	default:
		return fallback;
	}
}

var TRACKS = [
	{ title: "Midnight Bloom", artist: "Sample Artist" },
	{ title: "Golden Hour", artist: "Sample Artist" },
	{ title: "Paper Skies", artist: "Sample Artist" }
];
