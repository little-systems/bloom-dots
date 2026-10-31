pragma Singleton
import QtQuick

// Bloom's font: the Inter Google Fonts serves Bloom (weights 400 to 700),
// bundled (shell/assets/fonts, tools/fetch-inter.sh) under its own names so
// an installed Inter of another build never stands in. Qt's application-font
// matching confuses a regular and a medium face of one family, so Medium is
// "Bloom Inter Medium" and text names its family with familyFor(weight).
// The first use loads the files; loaded here, not through fontconfig, they
// measure as Chromium draws them.
QtObject {
	// bloom-font-family, set by shell.qml: replaces Bloom's own font everywhere.
	property string override: ""
	readonly property string family: override || "Bloom Inter"
	readonly property string medium: override || "Bloom Inter Medium"
	readonly property bool ready: [regular, mediumLoader, semibold, bold].every(l => l.status === FontLoader.Ready)

	function familyFor(weight) {
		return weight === Font.Medium ? medium : family;
	}

	// The settings app's text: Bloom's window uses Segoe UI on Windows, which
	// can't ship; Selawik is Microsoft's free metric match. "Selawik" is the
	// family for regular, and each other weight loads as its own family.
	readonly property FontLoader _ui: FontLoader { source: Qt.resolvedUrl("../../assets/fonts/Selawik-regular.ttf") }
	readonly property FontLoader _uiSemi: FontLoader { source: Qt.resolvedUrl("../../assets/fonts/Selawik-semibold.ttf") }
	readonly property FontLoader _uiBold: FontLoader { source: Qt.resolvedUrl("../../assets/fonts/Selawik-bold.ttf") }
	readonly property string ui: override || _ui.name
	function uiFor(weight) {
		if (override) return override;
		return weight >= Font.Bold ? _uiBold.name : weight >= Font.Medium ? _uiSemi.name : _ui.name;
	}
	// Bloom's About title (Settings.css .about-title).
	readonly property FontLoader _syne: FontLoader { source: Qt.resolvedUrl("../../assets/fonts/Syne-800.woff2") }
	readonly property string syne: _syne.name
	readonly property FontLoader _regular: FontLoader { id: regular; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-400.ttf") }
	readonly property FontLoader _medium: FontLoader { id: mediumLoader; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-500.ttf") }
	readonly property FontLoader _semibold: FontLoader { id: semibold; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-600.ttf") }
	readonly property FontLoader _bold: FontLoader { id: bold; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-700.ttf") }
}
