import QtQuick
import "../common"
import "../common/render"
import "logic.js" as Logic

// Bloom's .widget-pill, in the pool or placed in a zone, and draggable from
// either. `drop` is told where it was let go, in `host` coordinates.
Rectangle {
	id: root
	property QtObject theme
	required property string widgetId
	property Item host
	property bool placed: false
	property int index: 0
	property int total: 1
	signal moved(int step)
	signal swapped()
	signal removed()
	signal dropped(point at)
	signal dragged(point at, bool active)

	readonly property var _def: Logic.widget(root.widgetId)

	objectName: "pill:" + root.widgetId
	width: row.width + (root.placed ? 8 : 18)
	height: 26
	radius: 6
	color: drag.active ? Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.15) : root.placed ? Qt.rgba(1, 1, 1, 0.07) : drag.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : root.theme.groupBg
	border.width: 1
	border.color: drag.active ? Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.3) : root.placed ? Qt.rgba(1, 1, 1, 0.06) : root.theme.border
	opacity: drag.active ? 0.5 : 1

	Item {
		id: dragProxy
		width: 1
		height: 1
	}
	Row {
		id: row
		anchors.centerIn: parent
		spacing: 0
		Row {
			spacing: 5
			padding: root.placed ? 2 : 0
			leftPadding: root.placed ? 4 : 0
			rightPadding: root.placed ? 4 : 0
			anchors.verticalCenter: parent.verticalCenter
			SvgIcon {
				name: root._def.icon
				size: 12
				color: root._def.color
				anchors.verticalCenter: parent.verticalCenter
			}
			Text {
				text: root._def.label
				color: root.theme.text
				font.family: Fonts.familyFor(Font.Medium)
				font.pixelSize: 11
				font.weight: Font.Medium
				anchors.verticalCenter: parent.verticalCenter
			}
		}
		Row {
			visible: root.placed
			leftPadding: 2
			spacing: 1
			anchors.verticalCenter: parent.verticalCenter
			Repeater {
				model: [
					{ id: "up", icon: "chevron-up", show: root.index > 0, size: 9 },
					{ id: "down", icon: "chevron-down", show: root.index < root.total - 1, size: 9 },
					{ id: "swap", icon: "arrow-left-right", show: true, size: 9 },
					{ id: "x", icon: "x", show: true, size: 10 }
				]
				delegate: Rectangle {
					id: action
					required property var modelData
					objectName: "pill:" + root.widgetId + ":" + action.modelData.id
					visible: action.modelData.show
					width: 14
					height: 14
					radius: 3
					color: !actionHover.hovered ? "transparent" : action.modelData.id === "x" ? Qt.rgba(239 / 255, 68 / 255, 68 / 255, 0.25) : Qt.rgba(1, 1, 1, 0.12)
					SvgIcon {
						anchors.centerIn: parent
						name: action.modelData.icon
						size: action.modelData.size
						color: !actionHover.hovered ? root.theme.textMuted : action.modelData.id === "x" ? "#ef4444" : root.theme.text
					}
					HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
					TapHandler {
						onTapped: {
							if (action.modelData.id === "up") root.moved(-1);
							else if (action.modelData.id === "down") root.moved(1);
							else if (action.modelData.id === "swap") root.swapped();
							else root.removed();
						}
					}
				}
			}
		}
	}
	// Bloom's PointerSensor: a drag starts past 5 px.
	// cursor: grab — the pill's own drag surface, under its buttons
	MouseArea {
		id: drag
		z: -1
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
		preventStealing: true
		property bool active: false
		property point start
		property point last
		onPressed: mouse => {
			drag.start = Qt.point(mouse.x, mouse.y);
			drag.active = false;
		}
		onPositionChanged: mouse => {
			if (!pressed) return;
			if (!drag.active && Math.hypot(mouse.x - drag.start.x, mouse.y - drag.start.y) <= 5) return;
			drag.active = true;
			drag.last = root.mapToItem(root.host, mouse.x, mouse.y);
			root.dragged(drag.last, true);
		}
		onReleased: {
			if (!drag.active) return;
			drag.active = false;
			root.dragged(drag.last, false);
			root.dropped(drag.last);
		}
	}
}
