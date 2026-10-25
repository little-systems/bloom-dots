import QtQuick
import QtQuick.Shapes
import "../../common/tokens.js" as Tokens
import "../../services/battery.js" as Logic

// Bloom's battery glyph (App.tsx BatteryIcon): a 14x8.5 shell with a tip and
// a fill that is green while charging and red at or under the threshold. The
// SVG strokes are centred on their path, so the shell rectangle is grown by
// half the stroke to match.
Item {
	id: root

	property int level: 100
	property bool charging: false
	property int threshold: 20
	property color color: "white"
	readonly property string kind: Logic.fillKind(level, charging, threshold)
	readonly property color _faint: Qt.rgba(color.r, color.g, color.b, 0.35)

	implicitWidth: 20
	implicitHeight: 14

	Item {
		// The 20x10 glyph, centred in the 14 px row.
		y: 2
		width: 20
		height: 10

		Rectangle {
			x: 2 - 0.55
			y: 0.75 - 0.55
			width: 14 + 1.1
			height: 8.5 + 1.1
			radius: 2.4 + 0.55
			color: "transparent"
			border.width: 1.1
			border.color: root._faint
			antialiasing: true
		}

		Rectangle {
			x: 17.5 - 0.6
			y: 3.5
			width: 1.2
			height: 3
			radius: 0.6
			color: root._faint
		}

		Rectangle {
			x: 3.8
			y: 2.5
			height: 5
			radius: 1
			width: Math.max(0.5, Math.min(Math.max(root.level, 0), 100) / 100 * 10.4)
			color: root.kind === "charging" ? Tokens.status.green : root.kind === "low" ? Tokens.status.red : root.color
		}
	}

	// Charging bolt, centred on the shell (Bloom: left 9px, top 50%).
	Shape {
		visible: root.charging
		x: 9 - 3.5
		y: 7 - 5
		width: 7
		height: 10
		preferredRendererType: Shape.CurveRenderer

		ShapePath {
			fillColor: "white"
			strokeWidth: -1
			scale: Qt.size(7 / 8, 10 / 12)
			PathSvg { path: "M4.5 0L0 7H3.5L2.5 12L8 5H4.5L5.5 0H4.5Z" }
		}
	}
}
