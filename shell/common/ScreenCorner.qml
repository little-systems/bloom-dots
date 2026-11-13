import QtQuick
import QtQuick.Shapes

// One rounded screen corner: black outside a quarter circle centred on the
// corner's inner point. Used by the corner surfaces and the lock screen.
Shape {
	id: root
	property int radius: 23
	property bool isLeft: true
	property bool isTop: true

	width: root.radius
	height: root.radius
	preferredRendererType: Shape.CurveRenderer

	ShapePath {
		strokeWidth: -1
		fillColor: "black"
		startX: root.isLeft ? 0 : root.radius
		startY: root.isTop ? 0 : root.radius
		PathLine { x: root.isLeft ? 0 : root.radius; y: root.isTop ? root.radius : 0 }
		PathArc {
			x: root.isLeft ? root.radius : 0; y: root.isTop ? 0 : root.radius
			radiusX: root.radius; radiusY: root.radius
			direction: (root.isLeft === root.isTop) ? PathArc.Clockwise : PathArc.Counterclockwise
		}
		PathLine { x: root.isLeft ? 0 : root.radius; y: root.isTop ? 0 : root.radius }
	}
}
