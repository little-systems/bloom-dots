import QtQuick
import QtQuick.Effects
import "../../common/tokens.js" as Tokens
import "../../common/render"

// Bloom's status tooltip card: display only, hung 8 px under the pill and
// centred on its widget, fading in with a 4 px slide after 400 ms.
Item {
	id: root

	property string text: ""
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property color textColor: "white"
	// Bottom edge of the pill in the parent's coordinates.
	property real pillBottom: 36
	property bool shown: false
	property Item _anchor: null

	objectName: "statusTooltip"
	width: card.width
	height: card.height
	visible: opacity > 0
	opacity: root.shown ? 1 : 0
	Behavior on opacity {
		NumberAnimation {
			duration: Tokens.statusStrip.tooltip.fadeMs
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
		}
	}

	x: root._anchor ? root._anchor.mapToItem(root.parent, root._anchor.width / 2, 0).x - root.width / 2 : 0
	y: root.pillBottom + Tokens.statusStrip.tooltip.gap + (root.shown ? 0 : -Tokens.statusStrip.tooltip.slide)
	Behavior on y {
		NumberAnimation {
			duration: Tokens.statusStrip.tooltip.fadeMs
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
		}
	}

	function showFor(anchor) {
		root._anchor = anchor;
		delay.restart();
	}

	function hideNow() {
		delay.stop();
		root.shown = false;
	}

	Timer {
		id: delay
		interval: Tokens.statusStrip.tooltip.delayMs
		onTriggered: root.shown = true
	}

	RectangularShadow {
		anchors.fill: card
		offset.y: 6
		blur: 20
		radius: card.radius
		color: Qt.rgba(0, 0, 0, 0.35)
	}

	Rectangle {
		id: card
		width: label.implicitWidth + 2 * Tokens.statusStrip.tooltip.paddingH
		height: label.implicitHeight + 2 * Tokens.statusStrip.tooltip.paddingV
		radius: Tokens.statusStrip.tooltip.radius
		color: root.bg

		Text {
			id: label
			x: Tokens.statusStrip.tooltip.paddingH
			y: Tokens.statusStrip.tooltip.paddingV
			text: root.text
			color: root.textColor
			font.family: Fonts.familyFor(Font.Medium)
			font.pixelSize: Fonts.px(Tokens.statusStrip.tooltip.size)
			font.weight: Font.Medium
			lineHeight: Tokens.statusStrip.tooltip.lineHeight
		}
	}
}
