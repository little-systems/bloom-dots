import QtQuick
import QtQuick.Shapes
import "tokens.js" as Tokens

// Background of a surface attached to a screen edge (notch, dock, OSD): the
// pill plus two concave flares that bridge it to the edge, as Bloom's
// EdgeSurface. The pieces are painted opaque and the whole layer takes the
// colour's alpha, so no seam or darker overlap shows where they meet.
// A layer clips children outside the item, so this item's own box includes
// the flare margins along the edge; put content inside `pillRect`.
Item {
	id: root

	property string edge: "top"
	property real pillWidth: Tokens.sizes.collapsed.width
	property real pillHeight: Tokens.sizes.collapsed.height
	// Corners touching the screen edge, and corners facing away from it.
	property real edgeRadius: Tokens.sizes.edgeRadius
	property real farRadius: Tokens.sizes.farRadius
	property color color: Qt.rgba(0, 0, 0, 0.8)
	property bool flares: true

	readonly property bool horizontal: edge === "top" || edge === "bottom"
	readonly property real _f: Tokens.edge.flareSize
	readonly property rect pillRect: horizontal
		? Qt.rect(_f, 0, pillWidth, pillHeight)
		: Qt.rect(0, _f, pillWidth, pillHeight)
	readonly property color _solid: Qt.rgba(color.r, color.g, color.b, 1)

	width: horizontal ? pillWidth + 2 * _f : pillWidth
	height: horizontal ? pillHeight : pillHeight + 2 * _f

	layer.enabled: true
	opacity: color.a

	Rectangle {
		x: root.pillRect.x
		y: root.pillRect.y
		width: root.pillWidth
		height: root.pillHeight
		color: root._solid
		antialiasing: true
		topLeftRadius: root.edge === "top" || root.edge === "left" ? root.edgeRadius : root.farRadius
		topRightRadius: root.edge === "top" || root.edge === "right" ? root.edgeRadius : root.farRadius
		bottomLeftRadius: root.edge === "bottom" || root.edge === "left" ? root.edgeRadius : root.farRadius
		bottomRightRadius: root.edge === "bottom" || root.edge === "right" ? root.edgeRadius : root.farRadius
	}

	// Mirroring per edge and end, as EdgeSurface.css: index 0 = start, 1 = end.
	readonly property var _mirror: ({
		top: [[1, 1], [-1, 1]],
		bottom: [[1, -1], [-1, -1]],
		left: [[1, 1], [1, -1]],
		right: [[-1, 1], [-1, -1]]
	})

	Repeater {
		model: 2

		Shape {
			id: flare
			required property int index
			readonly property real len: root._f + 1 // 13 px curve + 1 px over the pill

			width: root.horizontal ? len : root._f
			height: root.horizontal ? root._f : len
			x: root.horizontal
				? (index === 0 ? 0 : root._f + root.pillWidth - 1)
				: (root.edge === "left" ? 0 : root.pillWidth - root._f)
			y: root.horizontal
				? (root.edge === "top" ? 0 : root.pillHeight - root._f)
				: (index === 0 ? 0 : root._f + root.pillHeight - 1)

			opacity: root.flares ? 1 : 0
			Behavior on opacity {
				// CSS `ease`, as Bloom's opacity transition.
				NumberAnimation {
					duration: Tokens.edge.flareFadeMs
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
				}
			}

			preferredRendererType: Shape.CurveRenderer
			transform: Scale {
				origin.x: flare.width / 2
				origin.y: flare.height / 2
				xScale: root._mirror[root.edge][flare.index][0]
				yScale: root._mirror[root.edge][flare.index][1]
			}

			// Drawn as the top edge's start flare (or the left edge's top flare).
			ShapePath {
				fillColor: root._solid
				strokeWidth: -1
				startX: 0
				startY: 0
				PathCubic {
					x: Tokens.edge.flareSize
					y: Tokens.edge.flareSize
					control1X: root.horizontal ? Tokens.edge.flareHandle : 0
					control1Y: root.horizontal ? 0 : Tokens.edge.flareHandle
					control2X: root.horizontal ? Tokens.edge.flareSize : Tokens.edge.flareSize - Tokens.edge.flareHandle
					control2Y: root.horizontal ? Tokens.edge.flareSize - Tokens.edge.flareHandle : Tokens.edge.flareSize
				}
				PathLine { x: root.horizontal ? flare.len : Tokens.edge.flareSize; y: root.horizontal ? Tokens.edge.flareSize : flare.len }
				PathLine { x: root.horizontal ? flare.len : 0; y: root.horizontal ? 0 : flare.len }
				PathLine { x: 0; y: 0 }
			}
		}
	}
}
