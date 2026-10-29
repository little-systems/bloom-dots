import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens

// .qp-icon-btn: a 24 px square icon button in a panel header.
Item {
	id: root

	property QtObject theme: QpTheme {}
	required property string icon
	// .qp-spin: the refresh icon turns while a scan runs.
	property bool spinning: false

	signal clicked()

	width: Tokens.qp.iconButton.size
	height: Tokens.qp.iconButton.size
	opacity: enabled ? 1 : Tokens.qp.iconButton.disabledOpacity

	Rectangle {
		objectName: "background"
		anchors.fill: parent
		radius: Tokens.qp.iconButton.radius
		color: pointer.hovered ? root.theme.groupBg : "transparent"

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.hoverMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}
	}

	SvgIcon {
		id: glyph
		objectName: "glyph"
		anchors.centerIn: parent
		name: root.icon
		size: Tokens.qp.iconButton.glyph
		color: pointer.hovered ? root.theme.text : root.theme.textMuted

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.hoverMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}

		RotationAnimation on rotation {
			running: root.spinning && root.visible
			loops: Animation.Infinite
			from: 0
			to: 360
			duration: Tokens.qp.spinMs
			onRunningChanged: if (!running) glyph.rotation = 0
		}
	}

	PointerArea {
		id: pointer
		objectName: "pointer"
		anchors.fill: parent
		onClicked: root.clicked()
	}
}
