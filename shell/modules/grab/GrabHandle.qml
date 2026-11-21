import QtQuick
import "../../common/tokens.js" as Tokens

// The grab handle on a floating window's top edge (owner's request: apps like
// Spotify draw no title bar to drag): an invisible zone whose pill shows
// while the pointer is in it. Dragging reports where the pointer is, in its
// window's coordinates; GrabWindow.qml moves the window. Pure.
Item {
	id: root

	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color text: "white"
	}
	readonly property bool dragging: area.pressed
	readonly property bool shown: area.containsMouse || area.pressed

	signal grabbed(point at)
	signal dragged(point at)
	signal dropped()

	function _at(mouse) {
		const p = area.mapToItem(null, mouse.x, mouse.y);
		return Qt.point(Math.round(p.x), Math.round(p.y));
	}

	Rectangle {
		objectName: "pill"
		anchors.centerIn: parent
		width: Tokens.grab.pill.width
		height: Tokens.grab.pill.height
		radius: height / 2
		color: root.theme.text
		border.width: Tokens.grab.pill.border
		border.color: root.theme.bgExpanded
		opacity: root.shown ? 1 : 0
		Behavior on opacity { NumberAnimation { duration: Tokens.grab.fadeMs } }
	}

	MouseArea {
		id: area
		anchors.fill: parent
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton
		cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
		onPressed: mouse => root.grabbed(root._at(mouse))
		onPositionChanged: mouse => { if (pressed) root.dragged(root._at(mouse)); }
		onReleased: root.dropped()
		onCanceled: root.dropped()
	}
}
