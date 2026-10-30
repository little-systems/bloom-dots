import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens

// .qp-btn: a row action (Connect, Disconnect, Forget). A busy button shows
// the spinning loader in place of its label, as Bloom's does.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property string text: ""
	property bool primary: false
	property bool busy: false

	signal clicked()

	readonly property real _content: root.busy ? Tokens.qp.button.glyph : Math.ceil(label.implicitWidth)

	// Border-box, as Chromium sizes a button: text, padding and the 1 px border.
	width: Math.max(Tokens.qp.button.minWidth, root._content + Tokens.qp.button.padH * 2 + 2)
	height: Tokens.qp.button.height
	opacity: !enabled ? Tokens.qp.button.disabledOpacity : root.primary && pointer.hovered ? Tokens.qp.button.primaryHoverOpacity : 1

	Behavior on opacity {
		NumberAnimation {
			duration: Tokens.qp.hoverMs
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
	}

	Rectangle {
		objectName: "background"
		anchors.fill: parent
		radius: Tokens.qp.button.radius
		border.width: 1
		border.color: root.primary ? root.theme.text : root.theme.border
		color: root.primary ? root.theme.text : pointer.hovered ? root.theme.border : root.theme.groupBg

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.hoverMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}
	}

	FracText {
		id: label
		objectName: "label"
		visible: !root.busy
		anchors.centerIn: parent
		text: root.text
		color: root.primary ? root.theme.bgExpanded : root.theme.text
		font.family: Tokens.type.family
		font.weight: Font.DemiBold
		pixelSize: Tokens.qp.button.text
	}

	SvgIcon {
		id: spinner
		objectName: "spinner"
		visible: root.busy
		anchors.centerIn: parent
		name: "loader-circle"
		size: Tokens.qp.button.glyph
		color: label.color

		RotationAnimation on rotation {
			running: spinner.visible && root.visible
			loops: Animation.Infinite
			from: 0
			to: 360
			duration: Tokens.qp.spinMs
		}
	}

	PointerArea {
		id: pointer
		objectName: "pointer"
		anchors.fill: parent
		onClicked: root.clicked()
	}
}
