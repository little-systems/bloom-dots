pragma Singleton

import QtQuick
import Quickshell
import "theme.js" as Logic

// Theme colours derived from settings with Bloom's theme maths. Surfaces bind
// to these instead of hard-coding colours.
Singleton {
	id: root

	readonly property string requestedMode: Settings.values["bloom-theme-mode"]
	// Wallpaper accent for the adaptive theme; set by wallpaper theming (phase 7).
	property string adaptiveAccent: ""

	readonly property var _t: Logic.compute(
		root.requestedMode,
		Settings.values["bloom-theme-color"],
		Settings.values["bloom-theme-opacity"],
		Settings.values["bloom-theme-saturation"],
		Settings.values["bloom-theme-brightness"],
		root.adaptiveAccent || null)

	readonly property string mode: _t.mode
	readonly property bool isLight: _t.isLight
	readonly property color bg: _color(_t.bg)
	readonly property color bgExpanded: _color(_t.bgExpanded)
	readonly property color text: _color(_t.text)
	readonly property color textMuted: _color(_t.textMuted)
	readonly property color border: _color(_t.border)
	readonly property color groupBg: _color(_t.groupBg)
	readonly property color accent: _color(_t.accent)
	readonly property color scrollbarThumb: _color(_t.scrollbarThumb)

	function _color(c) {
		return Qt.rgba(c.r / 255, c.g / 255, c.b / 255, c.a);
	}

	onModeChanged: {
		if (root.requestedMode === "adaptive" && root.mode !== "adaptive")
			console.info("bloom theme: adaptive needs wallpaper theming; using dark for now");
	}
}
