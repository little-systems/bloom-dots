import QtQuick
import "../../common"

// Bloom's volume row: quiet and loud speaker icons around a thin track whose
// fill follows the system volume; dragging sets it.
Row {
	id: root

	property real volume: 0
	property real trackHeight: 5
	property real trackHoverHeight: 5
	property color color: "white"
	property real trackOpacity: 0.15
	property real trackHoverOpacity: 0.2

	signal moved(real v)

	spacing: 8
	height: 14

	SvgIcon {
		anchors.verticalCenter: parent.verticalCenter
		name: "sf-speaker.wave.1.fill"
		size: 12
		color: root.color
		opacity: 0.5
	}

	Item {
		id: hit
		anchors.verticalCenter: parent.verticalCenter
		width: Math.max(0, root.width - 12 - 14 - 2 * root.spacing)
		height: 14

		HoverHandler { id: hover }

		Rectangle {
			id: track
			objectName: "volumeTrack"
			anchors.verticalCenter: parent.verticalCenter
			width: parent.width
			height: hover.hovered ? root.trackHoverHeight : root.trackHeight
			radius: height / 2
			color: Qt.rgba(root.color.r, root.color.g, root.color.b, hover.hovered ? root.trackHoverOpacity : root.trackOpacity)
			clip: true

			Rectangle {
				height: parent.height
				radius: parent.radius
				width: parent.width * Math.max(0, Math.min(1, root.volume))
				color: root.color
				Behavior on width {
					NumberAnimation { duration: 100; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
				}
			}
		}

		// Bloom .premium-slider { cursor: pointer }
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			function set(mx) { root.moved(Math.max(0, Math.min(1, mx / width))); }
			onPressed: mouse => set(mouse.x)
			onPositionChanged: mouse => { if (pressed) set(mouse.x); }
		}
	}

	SvgIcon {
		anchors.verticalCenter: parent.verticalCenter
		name: "sf-speaker.wave.3.fill"
		size: 14
		color: root.color
		opacity: 0.5
	}
}
