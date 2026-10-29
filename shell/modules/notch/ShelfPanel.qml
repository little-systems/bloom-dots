import QtQuick
import qs.services
import "../../common"
import "shelf.js" as Logic

Item {
	id: root
	DropArea {
		anchors.fill: parent
		onDropped: drop => {
			if (drop.urls.length) {
				for (const url of drop.urls) { const path = Logic.filePath(url.toString()); if (path) ShelfState.addFile(path); }
			} else if (drop.text) ShelfState.addText(drop.text);
		}
	}
	Rectangle {
		id: entry
		width: parent.width; height: 28; radius: 8; color: Theme.groupBg
		TextInput {
			id: input; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
			verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font.pixelSize: 11
			onAccepted: { if (ShelfState.addText(text) === "ok") text = ""; }
		}
		Text { x: 10; anchors.verticalCenter: parent.verticalCenter; visible: !input.text && !input.activeFocus; text: "Drop a file or type a note"; color: Theme.textMuted; font.pixelSize: 11 }
	}
	Flickable {
		y: 34; width: parent.width; height: parent.height - 34; contentHeight: entries.implicitHeight; clip: true
		Column {
			id: entries; width: parent.width; spacing: 4
			Repeater {
				model: ShelfState.items
				delegate: Rectangle {
					required property var modelData
					required property int index
					width: entries.width; height: 26; radius: 7; color: Theme.groupBg
					Drag.active: dragSource.drag.active
					Drag.dragType: Drag.Automatic
					Drag.supportedActions: Qt.CopyAction
					Drag.mimeData: modelData.kind === "file"
						? ({ "text/uri-list": Logic.fileUrl(modelData.value) })
						: ({ "text/plain": modelData.value })
					SvgIcon { x: 6; anchors.verticalCenter: parent.verticalCenter; name: modelData.kind === "file" ? "folder" : "list-todo"; color: Theme.textMuted; size: 13 }
					Text { x: 24; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 61; text: modelData.kind === "file" ? modelData.value.split("/").pop() : modelData.value; color: Theme.text; font.pixelSize: 10; elide: Text.ElideRight
						MouseArea {
							id: dragSource; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
							drag.target: parent.parent
							onClicked: ShelfState.activate(index)
							onReleased: { parent.parent.x = 0; parent.parent.y = 0; }
						}
					}
					Text { anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "×"; color: Theme.textMuted; font.pixelSize: 15; MouseArea { anchors.fill: parent; onClicked: ShelfState.remove(index) } }
				}
			}
			Text { visible: ShelfState.items.length === 0; text: "Drop files here for quick access"; color: Theme.textMuted; font.pixelSize: 10 }
		}
	}
}
