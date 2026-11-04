import QtQuick
import QtQuick.Effects
import QtQuick.Controls
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
	property string folder: ""
	property string defaultFolder: ""
	property string error: ""
	property bool loading: false
	property string query: ""
	readonly property var displayItems: Logic.search(root.items, root.query)
	signal browseFolderRequested()
	signal browseFileRequested()
	signal folderRequested(string path)
	signal refreshRequested()
	component PickerButton: Rectangle {
		property string label: ""
		signal clicked()
		width: caption.implicitWidth + 24
		height: 32
		radius: 8
		color: buttonHover.hovered ? root.theme.border : root.theme.groupBg
		Text { id: caption; anchors.centerIn: parent; text: parent.label; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(12) }
		HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }
		TapHandler { onTapped: parent.clicked() }
		Accessible.role: Accessible.Button
		Accessible.name: label
		Accessible.onPressAction: clicked()
	}

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
		root.selectedIndex = Math.max(0, root.displayItems.indexOf(root.current));
	}
	function _move(direction) {
		if (root.displayItems.length === 0) return;
		root.selectedIndex = Logic.move(root.selectedIndex, direction, root.displayItems.length, root._columns);
		grid.positionViewAtIndex(root.selectedIndex, GridView.Contain);
	}
	onDisplayItemsChanged: root._syncSelection()

	focus: true
	Keys.onEscapePressed: root.dismissed()
	Keys.onLeftPressed: root._move("left")
	Keys.onRightPressed: root._move("right")
	Keys.onUpPressed: root._move("up")
	Keys.onDownPressed: root._move("down")
	Keys.onReturnPressed: if (root.displayItems.length) root.chosen(root.displayItems[root.selectedIndex])
	Keys.onEnterPressed: if (root.displayItems.length) root.chosen(root.displayItems[root.selectedIndex])

	// cursor: default — a click on the screen around the card dismisses it
	MouseArea {
		anchors.fill: parent
		enabled: root._open
		onClicked: root.dismissed()
	}

	OpeningMotion {
		id: enter
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

	readonly property real _morph: enter.extent
	Rectangle {
		id: card
		objectName: "card"
		scale: enter.zoom
		transform: Translate { y: enter.rise }
		x: (root.width - width) / 2
		y: (root.height - height) / 2
		width: Math.min(root.width - 32, root._columns * Tokens.picker.cellWidth + 40) * root._morph
		height: Math.min(root.height - 32, Tokens.picker.rows * Tokens.picker.cellHeight + 166) * root._morph
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

		Column {
			id: toolbar
			x: 20; y: 18; width: parent.width - 40
			spacing: 10
			Row {
				spacing: 8
				Text { width: toolbar.width - actions.width - 8; anchors.verticalCenter: parent.verticalCenter; text: "Wallpapers"; color: root.theme.text; font.family: Fonts.familyFor(Font.DemiBold); font.weight: Font.DemiBold; font.pixelSize: Fonts.px(22) }
				Row {
					id: actions; spacing: 8
					PickerButton { objectName: "openFile"; label: "Open file…"; onClicked: root.browseFileRequested() }
					PickerButton { objectName: "browseFolder"; label: "Choose folder…"; onClicked: root.browseFolderRequested() }
					PickerButton { objectName: "closePicker"; label: "×"; onClicked: root.dismissed() }
				}
			}
			Row {
				width: parent.width; spacing: 8
				TextField {
					id: location; objectName: "folderPath"
					width: parent.width - folderActions.width - 8; height: 32
					text: root.folder; placeholderText: "Wallpaper folder"
					color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(12)
					background: Rectangle { radius: 8; color: root.theme.groupBg; border.color: location.activeFocus ? root.accent : root.theme.border }
					onAccepted: root.folderRequested(text)
				}
				Row {
					id: folderActions; spacing: 6
					PickerButton { label: "Up"; onClicked: root.folderRequested(Logic.parentFolder(root.folder)) }
					PickerButton { label: "Default"; enabled: root.defaultFolder !== ""; onClicked: root.folderRequested(root.defaultFolder) }
					PickerButton { objectName: "refresh"; label: "Refresh"; onClicked: root.refreshRequested() }
				}
			}
			TextField {
				id: search; objectName: "search"
				width: parent.width; height: 32
				placeholderText: "Search wallpapers…"; color: root.theme.text
				font.family: Fonts.family; font.pixelSize: Fonts.px(12)
				background: Rectangle { radius: 8; color: root.theme.groupBg; border.color: search.activeFocus ? root.accent : root.theme.border }
				onTextChanged: root.query = text
				onAccepted: { root.forceActiveFocus(); if (root.displayItems.length) root.chosen(root.displayItems[root.selectedIndex]); }
			}
		}
		Text {
			id: footer; objectName: "libraryStatus"
			anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20; bottomMargin: 12 }
			text: root.error || (root.loading ? "Reading wallpapers…" : root.displayItems.length + " wallpapers · Includes subfolders · Arrows to browse, Enter to apply")
			textFormat: Text.PlainText; elide: Text.ElideRight
			color: root.error ? "#ff6961" : root.theme.textMuted
			font.family: Fonts.family; font.pixelSize: Fonts.px(11)
		}

		Text {
			objectName: "empty"
			anchors.centerIn: grid
			visible: root.displayItems.length === 0 && !root.loading
			text: root.query ? "No matching wallpapers" : "No wallpapers in this folder"
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Fonts.px(Tokens.picker.text)
		}

		ScrollThumb { objectName: "gridThumb"; flickable: grid; x: grid.x + grid.width + 8; thumbColor: root.theme.textMuted }
		GridView {
			id: grid
			interactive: false
			ScrollGlide { flickable: grid }
			anchors { left: parent.left; right: parent.right; top: toolbar.bottom; bottom: footer.top; leftMargin: 16; rightMargin: 24; topMargin: 12; bottomMargin: 10 }
			cellWidth: width / root._columns
			cellHeight: Tokens.picker.cellHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds
			model: root.displayItems

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
						id: thumbnail
						anchors.fill: parent
						anchors.bottomMargin: 27
						source: Logic.isVideo(cell.modelData) ? "" : Logic.fileUrl(cell.modelData)
						sourceSize: Qt.size(Tokens.picker.cellWidth * 2, Tokens.picker.cellHeight * 2)
						asynchronous: true
						fillMode: Image.PreserveAspectCrop
					}
					Text {
						anchors.centerIn: parent
						visible: Logic.isVideo(cell.modelData) || thumbnail.status === Image.Error
						text: Logic.isVideo(cell.modelData) ? "▶  Video" : "Preview unavailable"
						textFormat: Text.PlainText
						color: root.theme.textMuted
						font.family: Fonts.family
						font.pixelSize: Fonts.px(Tokens.picker.text)
					}
					Text {
						anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 8; bottomMargin: 6 }
						text: (cell.modelData === root.current ? "✓  " : "") + cell.modelData.split("/").pop()
						textFormat: Text.PlainText
						elide: Text.ElideMiddle
						color: root.theme.text
						font.family: Fonts.family
						font.pixelSize: Fonts.px(11)
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
