import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens

// .qp-switch: the radio's on/off switch. Controlled: a click asks to toggle,
// and the owner sets `checked` from the real state.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property bool checked: false

	signal toggled()

	// margin-left: 4px sits outside the clickable track.
	width: Tokens.qp.switch.margin + Tokens.qp.switch.width
	height: Tokens.qp.switch.height

	Rectangle {
		id: track
		objectName: "track"
		x: Tokens.qp.switch.margin
		width: Tokens.qp.switch.width
		height: Tokens.qp.switch.height
		radius: Tokens.qp.switch.radius
		color: root.checked ? root.theme.text : root.theme.groupBg

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.switch.ms
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}

		Rectangle {
			objectName: "knob"
			x: Tokens.qp.switch.inset + (root.checked ? Tokens.qp.switch.travel : 0)
			y: Tokens.qp.switch.inset
			width: Tokens.qp.switch.knob
			height: Tokens.qp.switch.knob
			radius: width / 2
			color: root.checked ? root.theme.bgExpanded : root.theme.textMuted

			Behavior on x {
				NumberAnimation {
					duration: Tokens.qp.switch.ms
					easing.type: Easing.BezierSpline
					easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
				}
			}

			Behavior on color {
				ColorAnimation {
					duration: Tokens.qp.switch.ms
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
				}
			}
		}

		PointerArea {
			objectName: "pointer"
			anchors.fill: parent
			onClicked: root.toggled()
		}
	}
}
