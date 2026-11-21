import QtQuick
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "switcher.js" as Logic

// The Alt + Tab switcher: the launcher's card with a tile per window on the
// workspace, most recent first, each a live preview with its app's icon and
// title; the selected one has the accent outline. Hyprland's alt-tab.lua does
// the switching; this only draws it. Pure: SwitcherWindow.qml binds the
// Switcher service and supplies the live captures.
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
	// { address, title, appName, icon }
	property var items: []
	property int index: 0
	property var toplevelFor: null
	property Component captureComponent: null

	signal chosen(int index)

	readonly property bool shown: root._open || root.fade > 0
	// How far the card has faded in. Under Hyprland the window fades instead
	// (compositorFade), so the compositor's blur fades with the card.
	property bool compositorFade: false
	property real fade: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
	Behavior on fade {
		enabled: !root._open
		NumberAnimation { duration: Tokens.launcher.exitMs }
	}
	property bool _open: false

	function open() {
		root._open = true;
		enter.jump(0);
	}
	function close() { root._open = false; }

	OpeningMotion {
		id: enter
		initial: 0
		target: root._open ? 1 : 0
	}

	BoxShadow {
		anchors.fill: card
		visible: card.visible
		opacity: card.opacity
		scale: card.scale
		offset.y: 12
		blur: Tokens.dock.popup.shadow.blur
		radius: Tokens.launcher.radius
		color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
	}

	readonly property Item cardItem: card
	readonly property int _columns: Logic.columns(root.items.length, Tokens.switcher.columns)
	readonly property real _morph: enter.extent
	Rectangle {
		id: card
		objectName: "card"
		scale: enter.zoom
		transform: Translate { y: enter.rise }
		x: (root.width - width) / 2
		y: (root.height - height) / 2
		width: (grid.implicitWidth + 2 * Tokens.switcher.padding) * root._morph
		height: (grid.implicitHeight + 2 * Tokens.switcher.padding) * root._morph
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		clip: true
		visible: opacity > 0
		opacity: root.compositorFade ? (root.fade > 0 ? 1 : 0) : root.fade

		Grid {
			id: grid
			x: Tokens.switcher.padding
			y: Tokens.switcher.padding
			columns: root._columns
			spacing: Tokens.switcher.gap

			Repeater {
				model: root.items

				Rectangle {
					id: tile
					required property var modelData
					required property int index
					readonly property bool selected: tile.index === root.index
					readonly property var toplevel: root.toplevelFor ? root.toplevelFor(tile.modelData.address) : null

					objectName: "tile:" + tile.index
					width: Tokens.switcher.tile.width
					height: Tokens.switcher.tile.preview + Tokens.switcher.tile.gap + Tokens.switcher.tile.icon + 2 * Tokens.switcher.tile.padding
					radius: Tokens.switcher.tile.radius
					color: tile.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedAlpha) : "transparent"
					border.width: tile.selected ? 1 : 0
					border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedEdgeAlpha)

					Rectangle {
						id: preview
						x: Tokens.switcher.tile.padding
						y: Tokens.switcher.tile.padding
						width: tile.width - 2 * Tokens.switcher.tile.padding
						height: Tokens.switcher.tile.preview
						radius: Tokens.overview.windowRadius
						clip: true
						color: root.theme.groupBg
						border.width: 1
						border.color: root.theme.border

						Text {
							anchors.centerIn: parent
							visible: !capture.item
							text: (tile.modelData.appName || tile.modelData.title || "?").charAt(0).toUpperCase()
							color: root.theme.textMuted
							font.family: Fonts.familyFor(Font.DemiBold)
							font.pixelSize: Fonts.px(22)
							font.weight: Font.DemiBold
						}
						Loader {
							id: capture
							anchors.fill: parent
							active: root.shown && !!root.captureComponent && !!tile.toplevel
							sourceComponent: root.captureComponent
							onLoaded: item.captureSource = tile.toplevel
						}
					}

					Row {
						x: Tokens.switcher.tile.padding
						y: preview.y + preview.height + Tokens.switcher.tile.gap
						width: preview.width
						spacing: Tokens.switcher.tile.gap

						Image {
							objectName: "icon"
							width: Tokens.switcher.tile.icon
							height: Tokens.switcher.tile.icon
							visible: tile.modelData.icon !== ""
							source: tile.modelData.icon
							sourceSize: Qt.size(Tokens.switcher.tile.icon * 2, Tokens.switcher.tile.icon * 2)
							asynchronous: true
						}
						Text {
							objectName: "title"
							width: parent.width - (tile.modelData.icon !== "" ? Tokens.switcher.tile.icon + parent.spacing : 0)
							anchors.verticalCenter: parent.verticalCenter
							text: tile.modelData.title || tile.modelData.appName
							elide: Text.ElideRight
							color: tile.selected ? root.theme.text : root.theme.textMuted
							font.family: Fonts.familyFor(Font.Medium)
							font.pixelSize: Fonts.px(Tokens.switcher.tile.title)
							font.weight: Font.Medium
						}
					}

					// cursor: pointer — a tile switches to its window
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: root.chosen(tile.index)
					}
				}
			}
		}
	}
}
