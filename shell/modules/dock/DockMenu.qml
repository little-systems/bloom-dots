import QtQuick
import QtQuick.Effects
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// Bloom's dock context menu (Dock.css .context-menu): items, dividers and one
// level of submenu to the right, opened just above the pointer.
Item {
	id: root

	property var entries: []
	property bool light: false
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property color border: Qt.rgba(1, 1, 1, 0.1)
	property color textColor: "white"
	property color groupBg: Qt.rgba(1, 1, 1, 0.04)
	property real viewWidth: width
	readonly property bool opened: box.visible

	signal chosen(string key)

	property real _x: 0
	property real _y: 0
	property string _submenu: ""

	function openAt(x, y) {
		root._x = x;
		root._y = y;
		root._submenu = "";
		box.visible = true;
		root.forceActiveFocus();
	}

	function close() {
		box.visible = false;
		root._submenu = "";
	}

	Keys.onEscapePressed: root.close()

	component MenuItem: Rectangle {
		id: item
		required property var entry
		readonly property color hoverColor: item.entry.danger ? Tokens.dock.menu.dangerHover : (root.light ? root.groupBg : Tokens.dock.menu.hover)
		objectName: (item.entry.kind === "submenu" ? "menu-submenu-" : "menu-item-") + item.entry.key
		width: parent ? parent.width : implicitWidth
		implicitWidth: label.implicitWidth + 2 * Tokens.dock.menu.item.paddingH + (item.entry.kind === "submenu" ? Tokens.dock.menu.arrow.gap + arrow.implicitWidth : 0)
		implicitHeight: label.implicitHeight + 2 * Tokens.dock.menu.item.paddingV
		radius: Tokens.dock.menu.item.radius
		color: hover.hovered || (item.entry.kind === "submenu" && root._submenu === item.entry.key) ? item.hoverColor : "transparent"
		Behavior on color {
			ColorAnimation { duration: Tokens.dock.menu.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0, 0.2, 1, 1, 1] }
		}

		HoverHandler {
			id: hover
			onHoveredChanged: if (hover.hovered) root._submenu = item.entry.kind === "submenu" ? item.entry.key : (item.parent === column ? "" : root._submenu)
		}
		TapHandler {
			enabled: item.entry.kind === "item"
			onTapped: {
				root.close();
				root.chosen(item.entry.key);
			}
		}

		Text {
			id: label
			x: Tokens.dock.menu.item.paddingH
			anchors.verticalCenter: parent.verticalCenter
			text: item.entry.label
			color: root.textColor
			font.family: Tokens.type.family
			font.pixelSize: Tokens.dock.menu.item.size
			font.weight: Font.Medium
		}
		Text {
			id: arrow
			visible: item.entry.kind === "submenu"
			anchors.right: parent.right
			anchors.rightMargin: Tokens.dock.menu.item.paddingH
			anchors.verticalCenter: parent.verticalCenter
			text: "▶"
			opacity: Tokens.dock.menu.arrow.opacity
			color: root.textColor
			font.pixelSize: Tokens.dock.menu.arrow.size
		}
	}

	component Divider: Item {
		width: parent ? parent.width : 0
		height: 1 + 2 * Tokens.dock.menu.divider.marginV
		Rectangle {
			x: Tokens.dock.menu.divider.marginH
			y: Tokens.dock.menu.divider.marginV
			width: parent.width - 2 * Tokens.dock.menu.divider.marginH
			height: 1
			color: root.border
		}
	}

	component Box: Rectangle {
		radius: Tokens.dock.menu.radius
		color: root.bg
		border.width: 1
		border.color: root.border
		RectangularShadow {
			anchors.fill: parent
			z: -1
			radius: parent.radius
			offset.y: root.light ? Tokens.dock.menu.shadowLight.y : Tokens.dock.menu.shadow.y
			blur: root.light ? Tokens.dock.menu.shadowLight.blur : Tokens.dock.menu.shadow.blur
			color: Qt.rgba(0, 0, 0, root.light ? Tokens.dock.menu.shadowLight.alpha : Tokens.dock.menu.shadow.alpha)
		}
	}

	Box {
		id: box
		objectName: "menu-box"
		visible: false
		readonly property var pos: Dock.menuPosition(root._x, root._y, width, height, root.viewWidth)
		x: box.pos.left
		y: box.pos.top
		width: Math.max(Tokens.dock.menu.minWidth, column.implicitWidth) + 2 * Tokens.dock.menu.padding
		height: column.implicitHeight + 2 * Tokens.dock.menu.padding

		Column {
			id: column
			x: Tokens.dock.menu.padding
			y: Tokens.dock.menu.padding
			width: box.width - 2 * Tokens.dock.menu.padding

			Repeater {
				model: root.entries
				delegate: Loader {
					required property var modelData
					width: column.width
					sourceComponent: modelData.kind === "divider" ? dividerComponent : itemComponent
					property var entry: modelData
				}
			}
		}

		// One level of submenu, beside its item, bottoms aligned (Bloom bottom: -6px).
		Repeater {
			model: root.entries.filter(e => e.kind === "submenu")
			delegate: Box {
				required property var modelData
				readonly property Item anchorItem: root._findItem(modelData.key)
				visible: root._submenu === modelData.key && anchorItem !== null
				x: box.width - Tokens.dock.menu.padding
				y: anchorItem ? anchorItem.mapToItem(box, 0, 0).y + anchorItem.height + Tokens.dock.menu.padding - height : 0
				width: Math.max(Tokens.dock.menu.submenuMinWidth, sub.implicitWidth) + 2 * Tokens.dock.menu.padding
				height: sub.implicitHeight + 2 * Tokens.dock.menu.padding

				Column {
					id: sub
					x: Tokens.dock.menu.padding
					y: Tokens.dock.menu.padding
					width: parent.width - 2 * Tokens.dock.menu.padding
					Repeater {
						model: modelData.children
						delegate: Loader {
							required property var modelData
							width: sub.width
							sourceComponent: modelData.kind === "divider" ? dividerComponent : itemComponent
							property var entry: modelData
						}
					}
				}
			}
		}
	}

	Component { id: itemComponent; MenuItem { entry: parent.entry } }
	Component { id: dividerComponent; Divider {} }

	function _findItem(key) {
		for (let i = 0; i < column.children.length; i++) {
			const l = column.children[i];
			if (l.item && l.entry && l.entry.key === key)
				return l.item;
		}
		return null;
	}
}
