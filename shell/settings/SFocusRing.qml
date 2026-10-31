import QtQuick

// The keyboard focus ring: drawn only for focus that came from the keyboard.
Rectangle {
	property Item target: parent
	property real inset: -2
	anchors.fill: target
	anchors.margins: inset
	radius: target.radius !== undefined ? target.radius - inset : 4
	color: "transparent"
	border.width: 2
	border.color: "#0a84ff"
	visible: target.activeFocus && [Qt.TabFocusReason, Qt.BacktabFocusReason, Qt.OtherFocusReason].indexOf(target.focusReason ?? Qt.TabFocusReason) >= 0
	z: 100
}
