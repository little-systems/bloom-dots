import QtQuick
import "../common/render"
import "../common/tokens.js" as Tokens

// The list an SSelect opens, drawn over the whole window.
Item {
	id: root
	property QtObject theme
	property var options: []
	property var _pick: null
	property point _at: Qt.point(0, 0)
	property real _width: 0
	readonly property bool opened: root.visible

	anchors.fill: parent
	visible: false

	property int _index: 0
	property Item _anchor: null
	function _close() {
		root.visible = false;
		if (root._anchor) root._anchor.forceActiveFocus();
	}
	function _choose(value) {
		root._close();
		root._pick(value);
	}
	Keys.onEscapePressed: root._close()
	Keys.onUpPressed: root._index = (root._index + root.options.length - 1) % root.options.length
	Keys.onDownPressed: root._index = (root._index + 1) % root.options.length
	Keys.onReturnPressed: root._choose(root.options[root._index].value)
	Keys.onSpacePressed: root._choose(root.options[root._index].value)

	function show(anchor, options, pick, current) {
		root.options = options;
		root._anchor = anchor;
		root._index = Math.max(0, options.findIndex(o => o.value === current));
		root._pick = pick;
		const p = anchor.mapToItem(root, 0, anchor.height + 2);
		root._width = Math.max(anchor.width, list.implicitWidth);
		root._at = Qt.point(Math.min(p.x, root.width - root._width - 8),
			Math.min(p.y, root.height - options.length * Tokens.settings.select.itemHeight - 16));
		root.visible = true;
		root.forceActiveFocus();
	}

	// cursor: default — a click anywhere else closes the list
	MouseArea {
		anchors.fill: parent
		onClicked: root._close()
	}
	Rectangle {
		x: root._at.x
		y: root._at.y
		width: root._width + 8
		height: list.implicitHeight + 8
		radius: Tokens.settings.select.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border

		Column {
			id: list
			x: 4
			y: 4
			Repeater {
				model: root.options
				delegate: Rectangle {
					id: item
					required property var modelData
					required property int index
					objectName: "option:" + item.modelData.value
					width: Math.max(root._width, itemText.implicitWidth + 16)
					implicitWidth: itemText.implicitWidth + 16
					height: Tokens.settings.select.itemHeight
					radius: 4
					color: itemHover.hovered || item.index === root._index ? root.theme.groupBg : "transparent"

					Text {
						id: itemText
						x: 8
						anchors.verticalCenter: parent.verticalCenter
						text: item.modelData.label
						color: root.theme.text
						font.family: Fonts.ui
						font.pixelSize: Tokens.settings.select.size
					}
					HoverHandler {
						id: itemHover
						cursorShape: Qt.PointingHandCursor
					}
					TapHandler {
						onTapped: root._choose(item.modelData.value)
					}
				}
			}
		}
	}
}
