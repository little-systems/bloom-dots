import QtQuick
import qs.services
import "../../common"
import "shelf.js" as Logic

Item {
	id: root
	// Bloom ignores the wheel over the shelf: it doesn't switch panels.
	MouseArea {
		anchors.fill: parent
		acceptedButtons: Qt.NoButton
		onWheel: wheel => wheel.accepted = true
	}
	DropArea {
		anchors.fill: parent
		onDropped: drop => {
			if (drop.urls.length) {
				for (const url of drop.urls) { const path = Logic.filePath(url.toString()); if (path) ShelfState.addFile(path); }
			} else if (drop.text) ShelfState.addText(drop.text);
		}
	}
	Rectangle {
		x: 0; y: 12; width: parent.width; height: parent.height - 24
		visible: ShelfState.items.length === 0
		radius: 12; color: "transparent"; border.width: 1; border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
		Text { anchors.centerIn: parent; text: "Drop files or selected text here"; color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 12 }
	}
	Flickable {
		id: strip
		x: 0; y: 12; width: parent.width; height: parent.height - 24
		visible: ShelfState.items.length > 0
		contentWidth: tiles.implicitWidth; contentHeight: height
		flickableDirection: Flickable.HorizontalFlick
		clip: true
		Row {
			id: tiles; height: strip.height; spacing: 8
			Repeater {
				model: ShelfState.items
				delegate: Rectangle {
					id: tile
					required property var modelData
					required property int index
					width: 104; height: parent.height; radius: 12; color: hover.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12) : Theme.groupBg
					Drag.active: dragSource.drag.active
					Drag.dragType: Drag.Automatic
					Drag.supportedActions: Qt.CopyAction
					Drag.mimeData: modelData.kind === "file" ? ({ "text/uri-list": Logic.fileUrl(modelData.value) }) : ({ "text/plain": modelData.value })
					HoverHandler { id: hover }
					Rectangle {
						x: 6; y: 6; width: 92; height: Math.min(84, tile.height - 32); radius: 8
						color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, modelData.kind === "text" ? 0.075 : 0.05)
						clip: true
						Image {
							anchors.fill: parent
							visible: modelData.kind === "file" && /\.(png|jpe?g|webp|gif|bmp)$/i.test(modelData.value)
							source: visible ? Logic.fileUrl(modelData.value) : ""
							fillMode: Image.PreserveAspectCrop
							asynchronous: true
						}
						SvgIcon { anchors.centerIn: parent; visible: modelData.kind === "file" && !/\.(png|jpe?g|webp|gif|bmp)$/i.test(modelData.value); name: "folder"; color: Theme.textMuted; size: 25 }
						Text {
							visible: modelData.kind === "text"; x: 8; y: 7; width: parent.width - 16; height: parent.height - 14
							text: modelData.value; wrapMode: Text.WrapAnywhere; elide: Text.ElideRight
							color: Theme.text; font.family: "Inter"; font.pixelSize: 10; lineHeight: 1.45
						}
					}
					Text {
						x: 6; y: tile.height - 20; width: 92
						text: modelData.kind === "file" ? modelData.value.split("/").pop() : modelData.value
						color: Theme.text; opacity: 0.85; font.family: "Inter"; font.pixelSize: 11; elide: Text.ElideRight
					}
					MouseArea {
						id: dragSource; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
						drag.target: tile
						onClicked: ShelfState.activate(index)
						onReleased: { tile.x = 0; tile.y = 0; }
					}
					Rectangle {
						anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
						width: 18; height: 18; radius: 9; color: Qt.rgba(0, 0, 0, 0.55)
						visible: hover.hovered
						Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 14 }
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ShelfState.remove(index) }
					}
				}
			}
		}
	}
}
