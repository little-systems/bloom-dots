import QtQuick

// The colours a quick-panel part draws with: Bloom's dark theme until the
// panel passes `Theme` (which has the same names).
QtObject {
	property color text: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property color groupBg: Qt.rgba(1, 1, 1, 0.04)
	property color border: Qt.rgba(1, 1, 1, 0.1)
	property color bgExpanded: "black"
	property color scrollbarThumb: Qt.rgba(1, 1, 1, 0.1)
}
