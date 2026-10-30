import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens

// .qp-chip: one choice in a row of chips ("Looks like" for a Bluetooth device).
Item {
	id: root

	property QtObject theme: QpTheme {}
	property string text: ""
	property bool on: false

	signal clicked()

	// Border-box, as Chromium sizes a button: text, padding and the 1 px border.
	width: Math.ceil(label.implicitWidth) + Tokens.qp.chip.padH * 2 + 2
	height: Tokens.qp.chip.height

	Rectangle {
		objectName: "background"
		anchors.fill: parent
		radius: Tokens.qp.chip.radius
		border.width: 1
		border.color: root.on ? root.theme.text : root.theme.border
		color: root.on ? root.theme.text : "transparent"

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.hoverMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}
	}

	Text {
		id: label
		objectName: "label"
		anchors.centerIn: parent
		text: root.text
		color: root.on ? root.theme.bgExpanded : pointer.hovered ? root.theme.text : root.theme.textMuted
		font.family: Tokens.type.family
		font.pixelSize: Tokens.qp.chip.text
		font.weight: Font.DemiBold

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.hoverMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}
	}

	PointerArea {
		id: pointer
		objectName: "pointer"
		anchors.fill: parent
		onClicked: root.clicked()
	}
}
