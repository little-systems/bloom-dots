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
	readonly property string family: "Bloom Inter"
	readonly property string medium: "Bloom Inter Medium"
	readonly property bool ready: [regular, mediumLoader, semibold, bold].every(l => l.status === FontLoader.Ready)

	function familyFor(weight) {
		return weight === Font.Medium ? medium : family;
	}

	// Bloom's About title (Settings.css .about-title).
	readonly property FontLoader _syne: FontLoader { source: Qt.resolvedUrl("../../assets/fonts/Syne-800.woff2") }
	readonly property string syne: _syne.name
	readonly property FontLoader _regular: FontLoader { id: regular; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-400.ttf") }
	readonly property FontLoader _medium: FontLoader { id: mediumLoader; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-500.ttf") }
	readonly property FontLoader _semibold: FontLoader { id: semibold; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-600.ttf") }
	readonly property FontLoader _bold: FontLoader { id: bold; source: Qt.resolvedUrl("../../assets/fonts/BloomInter-700.ttf") }
}
