import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../common/tokens.js" as Tokens

// Bloom's GreenDownArrowIcon: a green-tinted 18 px disc with a soft glow and
// a 10 px download arrow (viewBox 24, stroke 3, round caps).
Item {
	id: root
	objectName: "update-arrow"
	// `visible` reads false inside an effect source, so layout and tests use this.
	property bool shown: true
	visible: root.shown
	implicitWidth: Tokens.pulse.arrow.box
	implicitHeight: Tokens.pulse.arrow.box
	readonly property real _k: Tokens.pulse.arrow.glyph / 24

	RectangularShadow {
		anchors.fill: disc
		radius: disc.radius
		blur: 8
		color: Qt.rgba(50 / 255, 215 / 255, 75 / 255, 0.25)
	}

	Rectangle {
		id: disc
		anchors.fill: parent
		radius: width / 2
		color: Qt.rgba(50 / 255, 215 / 255, 75 / 255, 0.15)
		border.width: 1
		border.color: Qt.rgba(50 / 255, 215 / 255, 75 / 255, 0.35)
	}

	Shape {
		anchors.centerIn: parent
		width: Tokens.pulse.arrow.glyph
		height: Tokens.pulse.arrow.glyph
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			fillColor: "transparent"
			strokeColor: Tokens.status.green
			strokeWidth: Tokens.pulse.arrow.stroke * root._k
			capStyle: ShapePath.RoundCap
			joinStyle: ShapePath.RoundJoin
			scale: Qt.size(root._k, root._k)
			PathSvg { path: "M12 4L12 16M18 10L12 16L6 10M6 20L18 20" }
		}
	}
}
