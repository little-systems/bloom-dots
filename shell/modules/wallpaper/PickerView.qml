import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "wallpaper.js" as Logic

// The wallpaper picker: the launcher's card holding a grid of thumbnails,
// driven by arrows and Enter or the pointer. Pure: PickerWindow.qml binds it.
Item {
	id: root

	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	property color accent: "#007aff"
	property var items: []
	property string current: ""
	property int selectedIndex: 0

	signal chosen(string path)
	signal dismissed()

	readonly property bool shown: root._open || card.opacity > 0
	property bool _open: false
	readonly property int _columns: Tokens.picker.columns

	function open() {
		root._open = true;
		root._syncSelection();
		enter.jump(0);
		root.forceActiveFocus();
	}
	function close() { root._open = false; }
	function _syncSelection() {
		root.selectedIndex = Math.max(0, root.items.indexOf(root.current));
	}
	function _move(direction) {
		if (root.items.length === 0) return;
		root.selectedIndex = Logic.move(root.selectedIndex, direction, root.items.length, root._columns);
		grid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
	}
	onItemsChanged: root._syncSelection()

	focus: true
	Keys.onEscapePressed: root.dismissed()
	Keys.onLeftPressed: root._move("left")
	Keys.onRightPressed: root._move("right")
	Keys.onUpPressed: root._move("up")
	Keys.onDownPressed: root._move("down")
	Keys.onReturnPressed: if (root.items.length) root.chosen(root.items[root.selectedIndex])
	Keys.onEnterPressed: if (root.items.length) root.chosen(root.items[root.selectedIndex])

	// cursor: default — a click on the screen around the card dismisses it
	MouseArea {
		anchors.fill: parent
		enabled: root._open
		onClicked: root.dismissed()
	}

	Spring {
		id: enter
		stiffness: Tokens.morph.stiffness
		damping: Tokens.morph.damping
		mass: Tokens.morph.mass
		initial: 0
		target: root._open ? 1 : 0
	}

	RectangularShadow {
		anchors.fill: card
		visible: card.visible
		opacity: card.opacity
		scale: card.scale
		offset.y: 12
		blur: Tokens.dock.popup.shadow.blur
		radius: Tokens.launcher.radius
		color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
	}

	readonly property real _morph: Tokens.morph.from + (1 - Tokens.morph.from) * Math.max(0, Math.min(1.02, enter.value))
	Rectangle {
		id: card
		objectName: "card"
		x: (root.width - width) / 2
		y: (root.height - height) / 2
		width: (root._columns * Tokens.picker.cellWidth + 2 * Tokens.picker.padding) * root._morph
		height: (Tokens.picker.rows * Tokens.picker.cellHeight + 2 * Tokens.picker.padding) * root._morph
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		clip: true
		visible: opacity > 0
		opacity: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
		Behavior on opacity {
			enabled: !root._open
			NumberAnimation { duration: Tokens.launcher.exitMs }
		}

		// Clicks on the card stay on it.
		// cursor: default — the card's own surface
		MouseArea { anchors.fill: parent }

		Text {
			objectName: "empty"
			anchors.centerIn: parent
			visible: root.items.length === 0
			text: "No wallpapers in this folder"
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Tokens.picker.text
		}

		ScrollThumb { objectName: "gridThumb"; flickable: grid; thumbColor: Qt.rgba(1, 1, 1, 0.2) }
		GridView {
			id: grid
			anchors.fill: parent
			anchors.margins: Tokens.picker.padding
			cellWidth: Tokens.picker.cellWidth
			cellHeight: Tokens.picker.cellHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds
			model: root.items

			delegate: Item {
				id: cell
				required property string modelData
				required property int index
				objectName: "tile:" + cell.modelData
				width: grid.cellWidth
				height: grid.cellHeight

				Rectangle {
					anchors.fill: parent
					anchors.margins: Tokens.picker.gap / 2
					radius: Tokens.picker.radius
					color: root.theme.groupBg
					clip: true

					Image {
						anchors.fill: parent
						source: Logic.isVideo(cell.modelData) ? "" : "file://" + cell.modelData
						sourceSize: Qt.size(Tokens.picker.cellWidth * 2, Tokens.picker.cellHeight * 2)
						asynchronous: true
						fillMode: Image.PreserveAspectCrop
					}
					Text {
						anchors.centerIn: parent
						visible: Logic.isVideo(cell.modelData)
						text: cell.modelData.split("/").pop()
						textFormat: Text.PlainText
						color: root.theme.textMuted
						font.family: Fonts.family
						font.pixelSize: Tokens.picker.text
					}
					Rectangle {
						anchors.fill: parent
						radius: parent.radius
						color: "transparent"
						visible: cell.index === root.selectedIndex
						border.width: 2
						border.color: root.accent
					}
				}
				HoverHandler {
					cursorShape: Qt.PointingHandCursor
					onHoveredChanged: if (hovered) root.selectedIndex = cell.index
				}
				TapHandler { onTapped: root.chosen(cell.modelData) }
			}
		}
	}
}
