pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

// CSS box-shadow. RectangularShadow also paints under the item it fills, so a
// see-through card shows its own shadow as a dark band toward its bottom;
// CSS only paints outside the border box. This cuts the card's shape out of
// the shadow. Fill the shadowed item, as with RectangularShadow.
Item {
	id: root

	property alias offset: shadow.offset
	property alias blur: shadow.blur
	property alias spread: shadow.spread
	property alias radius: shadow.radius
	property alias color: shadow.color

	readonly property real _pad: Math.ceil(shadow.blur + Math.max(0, shadow.spread) + Math.max(Math.abs(shadow.offset.x), Math.abs(shadow.offset.y)))

	Item {
		id: canvas
		x: -root._pad
		y: -root._pad
		width: root.width + 2 * root._pad
		height: root.height + 2 * root._pad
		layer.enabled: true
		layer.effect: MultiEffect {
			maskEnabled: true
			maskInverted: true
			maskSource: hole
			maskThresholdMin: 0.5
			maskSpreadAtMin: 1
		}

		RectangularShadow {
			id: shadow
			x: root._pad
			y: root._pad
			width: root.width
			height: root.height
		}
	}

	Item {
		id: hole
		width: canvas.width
		height: canvas.height
		visible: false
		layer.enabled: true

		// A pixel inside the card: the mask's soft edge would otherwise leave a
		// light seam between the card and its shadow.
		Rectangle {
			x: root._pad + 1
			y: root._pad + 1
			width: Math.max(0, root.width - 2)
			height: Math.max(0, root.height - 2)
			radius: Math.max(0, shadow.radius - 1)
			antialiasing: true
		}
	}
}
