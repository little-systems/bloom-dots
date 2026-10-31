import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "qp"
import "../../common/render"

// .cc-classic-slider-row: a label, a 6 px track with its fill, and the
// percentage. Bloom's range input is invisible over the track: a press sets
// the value where it lands and a drag follows.
Item {
	id: root

	property QtObject theme: QpTheme {}
	// .light-mode .cc-classic-slider-row svg uses `text`.
	property bool light: false
	property string label: ""
	required property string icon
	// 0..1; ignored while unavailable.
	property real value: 0
	property bool available: true
	property string percentText: ""

	// The chosen fraction, already on Bloom's step (0.01).
	signal chosen(real fraction)

	readonly property bool _hover: rowHover.hovered

	height: Tokens.cc.sliders.rowHeight

	HoverHandler {
		id: rowHover
	}

	Row {
		id: labelRow
		anchors.verticalCenter: parent.verticalCenter
		spacing: Tokens.cc.sliders.labelGap

		SvgIcon {
			objectName: "glyph"
			anchors.verticalCenter: parent.verticalCenter
			name: root.icon
			size: Tokens.cc.sliders.glyph
			// Both of Bloom's slider icons set opacity 0.5 inline.
			opacity: 0.5
			color: root.light ? root.theme.text : root.theme.textMuted
		}

		Text {
			objectName: "label"
			anchors.verticalCenter: parent.verticalCenter
			text: root.label
			color: root.theme.textMuted
			font.family: Fonts.familyFor(Font.DemiBold)
			font.pixelSize: Fonts.px(Tokens.cc.sliders.text)
			font.weight: Font.DemiBold
		}
	}

	Rectangle {
		id: track
		objectName: "track"
		x: Tokens.cc.sliders.label + Tokens.cc.sliders.rowGap
		anchors.verticalCenter: parent.verticalCenter
		width: root.width - x - Tokens.cc.sliders.rowGap - Tokens.cc.sliders.percent
		height: Tokens.cc.sliders.track
		radius: Tokens.cc.sliders.trackRadius
		color: root._hover ? root.theme.border : root.theme.groupBg

		Behavior on color {
			ColorAnimation {
				duration: Tokens.qp.hoverMs
				easing.type: Easing.BezierSpline
				easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
			}
		}

		// :hover box-shadow 0 0 4px var(--bloom-border) around the fill.
		RectangularShadow {
			objectName: "glow"
			visible: root._hover && fill.width > 0
			anchors.fill: fill
			blur: 4
			radius: fill.radius
			color: root.theme.border
		}

		Rectangle {
			id: fill
			objectName: "fill"
			// A percentage width, as Bloom's: a resize moves it with the track
			// and only a new value eases (transition: width 0.05s linear).
			property real fraction: root.available ? Math.max(0, Math.min(1, root.value)) : 0
			width: track.width * fraction
			height: parent.height
			radius: parent.radius
			color: root.theme.text

			Behavior on fraction {
				NumberAnimation {
					duration: 50
				}
			}
		}
	}

	Text {
		objectName: "percent"
		x: root.width - width
		anchors.verticalCenter: parent.verticalCenter
		width: Tokens.cc.sliders.percent
		horizontalAlignment: Text.AlignRight
		text: root.percentText
		// No transition on the percentage's hover colour.
		color: root._hover ? root.theme.text : root.theme.textMuted
		font.family: Fonts.familyFor(Font.DemiBold)
		font.pixelSize: Fonts.px(Tokens.cc.sliders.text)
		font.weight: Font.DemiBold
		font.features: {
			"tnum": 1
		}
	}

	// .cc-classic-input: top -6px, 18 px tall, over the track.
	MouseArea {
		objectName: "pointer"
		x: track.x
		width: track.width
		height: root.height
		enabled: root.available
		cursorShape: Qt.PointingHandCursor
		preventStealing: true

		function choose(px) {
			const f = Math.max(0, Math.min(1, px / width));
			root.chosen(Math.round(f * 100) / 100);
		}

		onPressed: mouse => choose(mouse.x)
		onPositionChanged: mouse => {
			if (pressed)
				choose(mouse.x);
		}
	}
}
