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
		objectName: "skipGlyphViewport"
		anchors.centerIn: parent
		width: root.iconWidth
		height: root.iconHeight
		clip: true

		// The incoming copy exists only mid-push, as in Bloom's AnimatePresence;
		// parked 30 px aside it would poke into the 32 px box.
		SvgIcon {
			id: back
			visible: slide.running
			x: root.forward ? -root._d : root._d
			y: 0
			name: root._icon
			size: root.iconWidth
			height: root.iconHeight
			color: root.color
		}

		SvgIcon {
			id: front
			y: 0
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
		onFinished: {
			// Back to one icon in place.
			front.x = 0;
			back.x = root.forward ? -root._d : root._d;
			root.activated();
		}
	}
}
