import QtQuick
import QtQuick.Effects
import "../../common/tokens.js" as Tokens
import "music.js" as Music

// A track title that scrolls when it doesn't fit (Bloom TitleMarquee): hold,
// slide to the end, hold, slide back, hold, at 30 px/s and never quicker than
// 5 s, each slide eased with CSS `ease`. The right edge fades over 8 px.
Item {
	id: root

	property string text: ""
	property color color: "white"
	property real pixelSize: 14.5
	property int weight: Font.DemiBold
	property real letterSpacing: -0.15
	property real lineHeight: 1

	// Qt sizes fonts in whole pixels: draw at the next whole size and scale
	// the glyphs down to Bloom's fractional one (14.5 px), as FracText does.
	readonly property real _k: root.pixelSize / Math.ceil(root.pixelSize)
	readonly property real overflow: Math.max(0, Math.ceil(label.implicitWidth * root._k - root.width))
	readonly property bool scrolling: root.overflow > 0 && root.width > 0
	readonly property real cycleMs: Music.marqueeDuration(root.overflow) * 1000

	implicitHeight: label.implicitHeight * root._k
	clip: true
	layer.enabled: true
	layer.effect: MultiEffect {
		maskEnabled: true
		maskSource: fade
	}

	Text {
		id: label
		objectName: "marqueeLabel"
		text: root.text
		color: root.color
		font.family: Tokens.type.family
		font.pixelSize: Math.ceil(root.pixelSize)
		font.weight: root.weight
		font.letterSpacing: root.letterSpacing / root._k
		lineHeight: root.lineHeight
		scale: root._k
		transformOrigin: Item.TopLeft
	}

	// A running animation keeps the distances it started with, so a new title
	// (or width) restarts the scroll from the start, as Bloom re-keys it.
	function _restart() {
		label.x = 0;
		if (scroll.running)
			scroll.restart();
	}
	onTextChanged: root._restart()
	onOverflowChanged: root._restart()

	SequentialAnimation {
		id: scroll
		running: root.scrolling && root.visible
		loops: Animation.Infinite
		onRunningChanged: if (!running) label.x = 0
		PauseAnimation { duration: root.cycleMs * 0.12 }
		NumberAnimation {
			target: label; property: "x"; from: 0; to: -root.overflow; duration: root.cycleMs * 0.30
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
		PauseAnimation { duration: root.cycleMs * 0.13 }
		NumberAnimation {
			target: label; property: "x"; to: 0; duration: root.cycleMs * 0.25
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
		PauseAnimation { duration: root.cycleMs * 0.20 }
	}

	Item {
		id: fade
		anchors.fill: parent
		visible: false
		layer.enabled: true
		Rectangle {
			anchors.fill: parent
			gradient: Gradient {
				orientation: Gradient.Horizontal
				GradientStop { position: 0; color: "black" }
				GradientStop { position: Math.max(0, 1 - Tokens.music.marquee.fade / Math.max(1, root.width)); color: "black" }
				GradientStop { position: 1; color: "transparent" }
			}
		}
	}
}
