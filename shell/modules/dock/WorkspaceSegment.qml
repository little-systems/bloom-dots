import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// The workspace switcher (spec D7) at the start of the dock: one cell per
// workspace on this monitor in the icon tile's look; the active highlight
// springs between cells. Click switches, the wheel steps, right-click asks
// for its menu (Hide Workspaces).
Item {
	id: root

	property var cells: []
	property bool iconOnly: false
	property bool light: false
	property color textColor: "white"
	property color tooltipBg: Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
	property color tooltipText: "white"

	signal switchTo(var cell)
	signal step(int dir)
	signal menuRequested(real x, real y)

	readonly property int _active: root.cells.findIndex(c => c.active)
	readonly property real _cellX: Tokens.dock.workspaces.cell + Tokens.dock.workspaces.gap

	width: Dock.segmentWidth(root.cells.length)
	height: Tokens.dock.iconBox

	RectangularShadow {
		anchors.fill: tile
		visible: tile.visible
		offset.y: 4
		blur: 12
		radius: tile.radius
		color: Qt.rgba(0, 0, 0, 0.1)
	}
	Rectangle {
		id: tile
		anchors.fill: parent
		visible: !root.iconOnly
		radius: Tokens.dock.iconRadius
		gradient: Gradient {
			GradientStop { position: 0; color: root.light ? Qt.rgba(0, 0, 0, 0.04) : Qt.rgba(1, 1, 1, 0.2) }
			GradientStop { position: 1; color: root.light ? Qt.rgba(0, 0, 0, 0.01) : Qt.rgba(1, 1, 1, 0.05) }
		}
	}

	Rectangle {
		id: highlight
		objectName: "ws-highlight"
		visible: root._active >= 0
		x: hx.value
		y: (root.height - height) / 2
		width: Tokens.dock.workspaces.cell
		height: width
		radius: Tokens.dock.workspaces.cellRadius
		color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, Tokens.dock.workspaces.highlightAlpha)
		Spring {
			id: hx
			stiffness: Tokens.springs.dockLayout.stiffness
			damping: Tokens.springs.dockLayout.damping
			initial: Tokens.dock.workspaces.padding + Math.max(0, root._active) * root._cellX
			target: Tokens.dock.workspaces.padding + Math.max(0, root._active) * root._cellX
		}
	}

	Repeater {
		model: root.cells
		delegate: Item {
			id: cell
			required property var modelData
			required property int index
			objectName: "ws-cell-" + cell.modelData.id
			x: Tokens.dock.workspaces.padding + cell.index * root._cellX
			y: (root.height - height) / 2
			width: Tokens.dock.workspaces.cell
			height: width

			Text {
				anchors.centerIn: parent
				text: cell.modelData.label
				color: root.textColor
				opacity: cell.modelData.active ? 1 : Tokens.dock.workspaces.idleOpacity
				Behavior on opacity { NumberAnimation { duration: 200 } }
				font.family: Tokens.type.family
				font.pixelSize: Tokens.dock.workspaces.size
				font.weight: Font.DemiBold
			}

			HoverHandler { id: cellHover }
			TapHandler {
				acceptedButtons: Qt.LeftButton
				onTapped: root.switchTo(cell.modelData)
			}

			// Bloom's dock tooltip, 36 px above the segment.
			Rectangle {
				x: (parent.width - width) / 2
				y: -Tokens.dock.tooltip.offset - (root.height - parent.height) / 2
				z: 1
				width: tipLabel.implicitWidth + 2 * Tokens.dock.tooltip.paddingH
				height: tipLabel.implicitHeight + 2 * Tokens.dock.tooltip.paddingV
				radius: Tokens.dock.tooltip.radius
				color: root.tooltipBg
				opacity: cellHover.hovered ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: Tokens.dock.tooltip.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
				Text {
					id: tipLabel
					anchors.centerIn: parent
					text: cell.modelData.tip
					color: root.tooltipText
					font.family: Tokens.type.family
					font.pixelSize: Tokens.dock.tooltip.size
				}
			}
		}
	}

	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.NoButton
		onWheel: event => root.step(event.angleDelta.y < 0 ? 1 : -1)
	}
	TapHandler {
		acceptedButtons: Qt.RightButton
		onTapped: eventPoint => {
			const p = root.mapToItem(null, eventPoint.position.x, eventPoint.position.y);
			root.menuRequested(p.x, p.y);
		}
	}
}
