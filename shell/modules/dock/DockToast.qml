import QtQuick
import "../../common/tokens.js" as Tokens

// Bloom's dock toast (Dock.css .dock-toast): a red message for 4 s that
// rises 10 px and fades in, shown again for each new serial.
Rectangle {
	id: root

	property string message: ""
	property int serial: 0

	property bool _showing: false
	onSerialChanged: if (root.message) { root._showing = true; hideTimer.restart(); }
	Timer { id: hideTimer; interval: Tokens.dock.toast.showMs; onTriggered: root._showing = false }

	width: text.implicitWidth + 2 * Tokens.dock.toast.paddingH
	height: text.implicitHeight + 2 * Tokens.dock.toast.paddingV
	radius: Tokens.dock.toast.radius
	color: Qt.rgba(40 / 255, 40 / 255, 40 / 255, 0.95)
	border.width: 1
	border.color: Qt.rgba(1, 1, 1, 0.1)
	opacity: root._showing ? 1 : 0
	visible: opacity > 0
	transform: Translate {
		y: root._showing ? 0 : Tokens.dock.toast.slide
		Behavior on y { NumberAnimation { duration: Tokens.dock.toast.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }
	}
	Behavior on opacity { NumberAnimation { duration: Tokens.dock.toast.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }

	Text {
		id: text
		objectName: "dock-toast-text"
		anchors.centerIn: parent
		text: root.message
		color: Tokens.dock.toast.color
		font.family: Tokens.type.family
		font.pixelSize: Tokens.dock.toast.size
		font.weight: Font.Medium
	}
}
