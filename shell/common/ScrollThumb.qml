import QtQuick

// A scrollbar for any Flickable: Bloom's 5 px thumb, shown only when there's
// more to scroll, and draggable. Place it beside the flickable it follows.
Rectangle {
	id: root

	required property Flickable flickable
	property color thumbColor: Qt.rgba(1, 1, 1, 0.2)

	readonly property real _max: Math.max(0, root.flickable.contentHeight - root.flickable.height)
	readonly property real _track: root.flickable.height
	readonly property real _size: Math.max(28, root._track * root.flickable.height / Math.max(1, root.flickable.contentHeight))

	objectName: "scrollThumb"
	visible: root._max > 1
	width: drag.containsMouse || drag.pressed ? 6 : 3
	x: root.flickable.x + root.flickable.width - width - 3
	y: root.flickable.y + (root._max > 0 ? (root.flickable.contentY / root._max) * (root._track - root._size) : 0)
	height: root._size
	radius: 4
	color: root.thumbColor
	z: 50
	Accessible.role: Accessible.ScrollBar

	MouseArea {
		id: drag
		anchors.fill: parent
		anchors.margins: -4
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		property real grab: 0
		onPressed: mouse => grab = mouse.y
		onPositionChanged: mouse => {
			if (!pressed) return;
			const moved = mapToItem(root.parent, mouse.x, mouse.y).y - grab - root.flickable.y;
			root.flickable.contentY = Math.max(0, Math.min(root._max, moved / (root._track - root._size) * root._max));
		}
	}
}
