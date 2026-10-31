import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "logic.js" as Logic

// Bloom's PreviewDock: the real dock surface with your pinned apps, or sample
// tiles without any, and the Dock tab's settings applied.
Item {
	id: root
	property QtObject theme
	property var values
	// { name, icon }
	property var apps: []
	property bool revealed: false

	anchors.fill: parent

	readonly property var _modules: root.values["bloom-enabled-modules"]
	readonly property bool _on: root._modules.indexOf("dock") >= 0
	readonly property string _mode: root.values["bloom-dock-mode"]
	readonly property string _extrasAt: root.values["bloom-dock-extras-position"]
	readonly property bool _iconOnly: root.values["bloom-dock-icon-only"]
	readonly property var _extras: {
		const list = [];
		if (root.values["bloom-dock-extras-drives"]) list.push({ name: "Drives", glyph: "hard-drive" });
		if (Logic.folderList(root.values["bloom-dock-extras-folders"]).length) list.push({ name: "Folders", glyph: "folder" });
		if (root.values["bloom-dock-extras-recycle-bin"]) list.push({ name: "Trash", glyph: "trash-2" });
		return list.slice(0, 3);
	}
	readonly property bool _showExtras: root._extrasAt !== "off" && root._extras.length > 0
	property string selected: ""

	Text {
		objectName: "previewDockOff"
		visible: !root._on
		anchors.centerIn: parent
		text: "Dock is off"
		color: root.theme.textMuted
		font.family: Fonts.ui
		font.pixelSize: 12
	}

	Spring {
		id: slide
		stiffness: 420
		damping: 30
		initial: root._mode === "fixed" ? 20 : 75
		target: root._mode === "peek" && !root.revealed ? 42 : 0
	}

	component Tile: Item {
		id: tile
		required property string name
		property string icon: ""
		property string glyph: ""
		objectName: "dockTile:" + tile.name
		width: Tokens.dock.iconBox
		height: Tokens.dock.iconBox
		anchors.verticalCenter: parent.verticalCenter

		Rectangle {
			anchors.fill: parent
			radius: Tokens.dock.iconRadius
			color: root._iconOnly ? "transparent" : root.theme.groupBg
			scale: tileHover.hovered ? 1.08 : 1
			Behavior on scale { NumberAnimation { duration: 120 } }

			Image {
				anchors.centerIn: parent
				visible: tile.icon !== ""
				source: tile.icon
				width: root._iconOnly ? Tokens.dock.iconOnlyImage : Tokens.dock.iconImage
				height: width
				sourceSize: Qt.size(64, 64)
			}
			SvgIcon {
				anchors.centerIn: parent
				visible: tile.icon === "" && tile.glyph !== ""
				name: tile.glyph || "folder"
				size: 22
				color: root.theme.text
			}
			Text {
				anchors.centerIn: parent
				visible: tile.icon === "" && tile.glyph === ""
				text: tile.name.slice(0, 1)
				color: root.theme.text
				font.family: Fonts.uiFor(Font.DemiBold)
				font.pixelSize: 15
				font.weight: Font.DemiBold
			}
		}
		HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
		TapHandler { onTapped: root.selected = root.selected === tile.name ? "" : tile.name }
	}
	component Divider: Rectangle {
		width: 1
		height: 24
		color: root.theme.border
		anchors.verticalCenter: parent.verticalCenter
	}

	Rectangle {
		objectName: "previewDockPopover"
		visible: root.selected !== "" && root._on
		x: (root.width - width) / 2
		y: dock.y - height - 6
		width: popoverText.implicitWidth + 16
		height: 22
		radius: 6
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		Text {
			id: popoverText
			anchors.centerIn: parent
			text: root.selected
			color: root.theme.text
			font.family: Fonts.ui
			font.pixelSize: 11
		}
	}

	Item {
		id: dock
		objectName: "previewDock"
		visible: root._on
		x: (root.width - width) / 2
		y: root.height - height + slide.value
		width: row.width + 24
		height: Tokens.dock.height
		transformOrigin: Item.Bottom
		scale: 0.85

		EdgeSurface {
			edge: "bottom"
			pillWidth: dock.width
			pillHeight: dock.height
			color: root.theme.bgExpanded
		}
		Row {
			id: row
			anchors.centerIn: parent
			spacing: 6
			Repeater {
				model: root._showExtras && root._extrasAt === "left" ? root._extras : []
				delegate: Tile { required property var modelData; name: modelData.name; glyph: modelData.glyph }
			}
			Divider { visible: root._showExtras && root._extrasAt === "left" }
			Repeater {
				model: root.apps.slice(0, 4)
				delegate: Tile { required property var modelData; name: modelData.name; icon: modelData.icon }
			}
			Divider { visible: root._showExtras && root._extrasAt === "right" }
			Repeater {
				model: root._showExtras && root._extrasAt === "right" ? root._extras : []
				delegate: Tile { required property var modelData; name: modelData.name; glyph: modelData.glyph }
			}
		}
	}
}
