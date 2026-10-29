import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "qp"

// .cc-circular-btn: one of the Command Center's six round buttons.
Item {
	id: root

	property QtObject theme: QpTheme {}
	required property string icon
	// Bloom draws these at their own sizes (18 px moon and battery, 14 px others).
	property real glyphSize: 14
	property real glyphOpacity: 1
	property bool active: false

	signal clicked()

	readonly property bool _hover: pointer.hovered
	// :hover lifts 1 px; :active is scale(0.95) translateY(0).
	readonly property real lift: liftValue
	property real liftValue: root._hover && !pointer.pressed ? Tokens.cc.round.hoverLift : 0

	width: Tokens.cc.round.size
	height: Tokens.cc.round.size
	scale: pointer.pressed ? Tokens.cc.round.pressScale : 1
	transform: Translate {
		y: root.liftValue
	}

	Behavior on liftValue {
		NumberAnimation {
			duration: Tokens.cc.round.ms
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
		}
	}

	Behavior on scale {
		NumberAnimation {
			duration: Tokens.cc.round.ms
			easing.type: Easing.BezierSpline
			easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
		}
	}

	// .active: box-shadow 0 2px 8px var(--bloom-border).
	RectangularShadow {
		objectName: "shadow"
		visible: root.active
		anchors.fill: background
		offset.y: 2
		blur: 8
		radius: background.radius
		color: root.theme.border
	}

	Rectangle {
		id: background
		objectName: "background"
		anchors.fill: parent
		radius: width / 2
		border.width: 1
		border.color: root.active ? root.theme.text : root.theme.border
		// .active:hover is Bloom's hard-coded rgba(255, 255, 255, 0.9).
		color: root.active ? (root._hover ? Qt.rgba(1, 1, 1, 0.9) : root.theme.text) : root._hover ? root.theme.border : root.theme.groupBg

		Behavior on color {
			ColorAnimation {
				duration: Tokens.cc.round.ms
				easing.type: Easing.BezierSpline
				easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
			}
		}
	}

	SvgIcon {
		objectName: "glyph"
		anchors.centerIn: parent
		name: root.icon
		size: root.glyphSize
		strokeWidth: 2.5
		opacity: root.glyphOpacity
		color: root.active ? root.theme.bgExpanded : root._hover ? root.theme.text : root.theme.textMuted

		Behavior on color {
			ColorAnimation {
				duration: Tokens.cc.round.ms
				easing.type: Easing.BezierSpline
				easing.bezierCurve: Tokens.cc.easeOut.concat([1, 1])
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
