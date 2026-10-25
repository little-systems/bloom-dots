import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens

// Bloom's prev/next push: the icon slides out 30 px while a copy slides in
// (180 ms, cubic-bezier(0.4, 0, 0.2, 1)), then the skip is sent.
PressArea {
	id: root

	property bool forward: true
	property real iconWidth: 32
	property real iconHeight: 16
	property real boxWidth: 32
	property real boxHeight: 16
	property real padding: 8
	property color color: "white"

	signal activated()

	implicitWidth: root.boxWidth + 2 * root.padding
	implicitHeight: root.boxHeight + 2 * root.padding
	hoverScale: 1.2
	tapScale: 0.9
	stiffness: 400
	damping: 25

	readonly property real _d: Tokens.music.slide.distance
	readonly property string _icon: root.forward ? "sf-forward.fill" : "sf-backward.fill"

	onClicked: {
		front.x = 0;
		back.x = root.forward ? -root._d : root._d;
		slide.restart();
	}

	Item {
		anchors.centerIn: parent
		width: root.boxWidth
		height: root.boxHeight
		clip: true

		SvgIcon {
			id: back
			x: root.forward ? -root._d : root._d
			y: (root.boxHeight - height) / 2
			name: root._icon
			size: root.iconWidth
			height: root.iconHeight
			color: root.color
		}

		SvgIcon {
			id: front
			y: (root.boxHeight - height) / 2
			name: root._icon
			size: root.iconWidth
			height: root.iconHeight
			color: root.color
		}
	}

	ParallelAnimation {
		id: slide
		NumberAnimation {
			target: front; property: "x"; to: root.forward ? root._d : -root._d; duration: Tokens.music.slide.ms
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
		}
		NumberAnimation {
			target: back; property: "x"; to: 0; duration: Tokens.music.slide.ms
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1]
		}
		onFinished: root.activated()
	}
}
