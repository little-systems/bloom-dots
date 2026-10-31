pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "theme.js" as Logic

// Theme colours derived from settings with Bloom's theme maths. Surfaces bind
// to these instead of hard-coding colours.
Singleton {
	id: root

	readonly property string requestedMode: Settings.values["bloom-theme-mode"]
	readonly property string adaptiveAccent: Wallpaper.accent

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

	// The shell owns app theming; Settings and pure views only read this
	// singleton, so opening a preview cannot write desktop configuration.
	property bool syncApps: false
	readonly property string _appPalette: JSON.stringify({ surface: root._t.bgExpanded, text: root._t.text, accent: root._t.accent, light: root.isLight })
	property string _appliedPalette: ""
	on_AppPaletteChanged: if (root.syncApps) applyDelay.restart()
	onSyncAppsChanged: if (root.syncApps) applyDelay.restart()
	Timer {
		id: applyDelay; interval: 300
		onTriggered: {
			if (!root.syncApps || appTheme.running || root._appPalette === root._appliedPalette) return;
			appTheme.palette = root._appPalette;
			appTheme.stdinEnabled = true; appTheme.running = true;
		}
	}
	Process {
		id: appTheme
		property string palette: ""
		command: ["bash", Quickshell.shellPath("scripts/adaptive-theme.sh"), "palette"]
		stdinEnabled: true
		onStarted: { appTheme.write(palette); appTheme.stdinEnabled = false; }
		onExited: code => {
			if (code === 0) root._appliedPalette = palette;
			else console.warn("bloom: couldn't apply the selected app theme (exit " + code + ")");
			if (root._appPalette !== palette) applyDelay.restart();
		}
	}

	function _color(c) {
		return Qt.rgba(c.r / 255, c.g / 255, c.b / 255, c.a);
	}

	onModeChanged: {
		if (root.requestedMode === "adaptive" && root.mode !== "adaptive")
			console.info("bloom theme: adaptive needs wallpaper theming; using dark for now");
	}
}
