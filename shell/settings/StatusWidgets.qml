import QtQuick
import "../common/render"
import "logic.js" as Logic

// Bloom's StatusWidgetConfig: left and right of the clock, then what's unused.
Column {
	id: root
	property QtObject theme
	property var config: ({ left: [], right: [] })
	signal changed(var config)

	readonly property var _pool: Logic.pool(root.config)
	property string _dragId: ""
	property point _dragAt: Qt.point(0, 0)
	readonly property string _over: root._dragId === "" ? "" : root._zoneAt(root._dragAt)

	x: 14
	width: parent.width - 28
	topPadding: 8
	bottomPadding: 12
	spacing: 8

	function _zoneAt(at) {
		for (const zone of [leftZone, rightZone]) {
			const p = zone.mapFromItem(root, at.x, at.y);
			if (p.x >= 0 && p.y >= 0 && p.x <= zone.width && p.y <= zone.height) return zone.side;
		}
		return "";
	}
	function dropAt(id, at) {
		const side = root._zoneAt(at);
		if (side !== "") root.changed(Logic.place(root.config, id, side));
	}
	function _track(id, at, active) {
		root._dragId = active ? id : "";
		root._dragAt = at;
	}

	component Zone: Rectangle {
		id: zone
		required property string side
		readonly property var items: root.config[zone.side]
		objectName: "zone:" + zone.side
		width: root.width
		height: Math.max(34, chips.height + 14)
		radius: 8
		color: root._over === zone.side ? Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.06) : "transparent"
		border.width: 1
		border.color: root._over === zone.side ? Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.4) : "transparent"

		Text {
			x: 8
			anchors.verticalCenter: parent.verticalCenter
			text: zone.side
			color: root.theme.textMuted
			font.family: Fonts.uiFor(Font.DemiBold)
			font.pixelSize: 10
			font.weight: Font.DemiBold
			font.letterSpacing: 0.5
			font.capitalization: Font.AllUppercase
		}
		Flow {
			id: chips
			x: 58
			anchors.verticalCenter: parent.verticalCenter
			width: parent.width - x - 8
			spacing: 6
			Text {
				visible: zone.items.length === 0
				text: "Drop here"
				color: root.theme.textMuted
				font.family: Fonts.ui
				font.pixelSize: 11
				font.italic: true
			}
			Repeater {
				model: zone.items
				delegate: WidgetPill {
					required property string modelData
					required property int index
					theme: root.theme
					host: root
					placed: true
					widgetId: modelData
					total: zone.items.length
					onMoved: step => root.changed(Logic.moveInSide(root.config, widgetId, step))
					onSwapped: root.changed(Logic.swapSide(root.config, widgetId))
					onRemoved: root.changed(Logic.remove(root.config, widgetId))
					onDropped: at => root.dropAt(widgetId, at)
					onDragged: (at, active) => root._track(widgetId, at, active)
				}
			}
		}
	}

	Zone { id: leftZone; side: "left" }
	Zone { id: rightZone; side: "right" }
	Column {
		visible: root._pool.length > 0
		width: parent.width
		spacing: 8
		Rectangle { width: parent.width; height: 1; color: root.theme.border }
		Flow {
			width: parent.width
			spacing: 6
			Repeater {
				model: root._pool
				delegate: WidgetPill {
					required property string modelData
					theme: root.theme
					host: root
					widgetId: modelData
					onDropped: at => root.dropAt(widgetId, at)
					onDragged: (at, active) => root._track(widgetId, at, active)
				}
			}
		}
	}
	// Bloom's DragOverlay: the pill under the pointer.
	Item {
		width: 0
		height: 0
		Rectangle {
			objectName: "dragGhost"
			readonly property var def: Logic.widget(root._dragId)
			visible: root._dragId !== ""
			parent: root
			z: 10
			x: root._dragAt.x - width / 2
			y: root._dragAt.y - height / 2
			width: ghost.width + 18
			height: 26
			radius: 6
			color: Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.15)
			border.width: 1
			border.color: Qt.rgba(96 / 255, 165 / 255, 250 / 255, 0.3)
			Text {
				id: ghost
				anchors.centerIn: parent
				text: parent.def ? parent.def.label : ""
				color: root.theme.text
				font.family: Fonts.uiFor(Font.Medium)
				font.pixelSize: 11
				font.weight: Font.Medium
			}
		}
	}
}
