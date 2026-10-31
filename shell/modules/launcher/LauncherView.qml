import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "../notch/qp"

// The launcher (owner decision: Spotlight-style): a search bar high in the
// screen's centre that grows on a spring as results appear. Bloom has no
// launcher, so this is its language: the Add App card's surface, rows,
// selection and spring. Pure: LauncherWindow.qml binds the Launcher service.
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
	// { id, name, sub, icon (a URL), glyph (a character shown as the icon) }
	property var results: []
	property int selectedIndex: 0

	signal queryEdited(string text)
	signal chosen(var item)
	signal dismissed()

	readonly property bool shown: root._open || card.opacity > 0
	readonly property real barHeight: Tokens.launcher.field.height + 2 * Tokens.launcher.padding
	readonly property real targetHeight: root.barHeight + (root.results.length
		? Tokens.launcher.gap + Math.min(root.results.length, Tokens.launcher.maxRows) * Tokens.dock.popup.row.height : 0)

	property bool _open: false
	// What the selected row shows beside the list (the clipboard's previews).
	readonly property var _preview: root.results[root.selectedIndex]?.preview ?? null

	function open() {
		field.text = "";
		root.selectedIndex = 0;
		root._open = true;
		enter.jump(0);
		field.forceActiveFocus();
	}
	// Opens, or if open moves, with this text already typed.
	function openWith(text) {
		if (!root._open) root.open();
		field.text = text;
		field.cursorPosition = text.length;
	}
	function close() {
		root._open = false;
	}
	function _move(step) {
		const n = root.results.length;
		if (n === 0) return;
		root.selectedIndex = (root.selectedIndex + step + n) % n;
		list.positionViewAtIndex(root.selectedIndex, ListView.Contain);
	}
	function _key(event) {
		if (event.key === Qt.Key_Escape) root.dismissed();
		else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) root._move(1);
		else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) root._move(-1);
		else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
			if (root.results[root.selectedIndex]) root.chosen(root.results[root.selectedIndex]);
		} else return;
		event.accepted = true;
	}
	onResultsChanged: root.selectedIndex = 0

	// cursor: default — a click on the screen around the bar dismisses it
	MouseArea {
		anchors.fill: parent
		enabled: root._open
		onClicked: root.dismissed()
	}

	Spring {
		id: heightSpring
		stiffness: Tokens.launcher.height.stiffness
		damping: Tokens.launcher.height.damping
		initial: root.barHeight
		target: root.targetHeight
	}
	Spring {
		id: enter
		stiffness: Tokens.launcher.enter.stiffness
		damping: Tokens.launcher.enter.damping
		mass: Tokens.launcher.enter.mass
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

	Rectangle {
		id: card
		objectName: "card"
		x: (root.width - width) / 2
		y: root.height * Tokens.launcher.top
		width: Tokens.launcher.width + (root._preview ? Tokens.launcher.preview.width + Tokens.launcher.preview.gap : 0)
		height: heightSpring.value
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		clip: true
		visible: opacity > 0
		transformOrigin: Item.Top
		opacity: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
		scale: Tokens.launcher.enter.scale + (1 - Tokens.launcher.enter.scale) * enter.value
		Behavior on opacity {
			enabled: !root._open
			NumberAnimation { duration: Tokens.launcher.exitMs }
		}

		// Clicks on the card stay on it.
		// cursor: default — the card's own surface
		MouseArea { anchors.fill: parent }

		Rectangle {
			id: fieldBox
			x: Tokens.launcher.padding
			y: Tokens.launcher.padding
			width: parent.width - 2 * Tokens.launcher.padding
			height: Tokens.launcher.field.height
			radius: Tokens.launcher.field.radius
			color: root.theme.groupBg

			SvgIcon {
				id: glass
				name: "search"
				size: Tokens.launcher.field.icon
				color: root.theme.textMuted
				x: Tokens.launcher.field.paddingH
				anchors.verticalCenter: parent.verticalCenter
			}
			TextInput {
				id: field
				objectName: "field"
				x: glass.x + glass.width + Tokens.launcher.field.gap
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - x - Tokens.launcher.field.paddingH
				color: root.theme.text
				selectionColor: root.accent
				selectByMouse: true
				clip: true
				font.family: Fonts.family
				font.pixelSize: Tokens.launcher.field.size
				onTextChanged: root.queryEdited(text)
				Keys.onPressed: event => root._key(event)

				Text {
					objectName: "placeholder"
					visible: field.text === ""
					text: "Search apps, or ; : = > ? ! for more"
					color: root.theme.textMuted
					font: field.font
				}
			}
		}

		Item {
			x: Tokens.launcher.padding
			y: fieldBox.y + fieldBox.height + Tokens.launcher.gap
			width: Tokens.launcher.width - 2 * Tokens.launcher.padding
			height: Tokens.launcher.maxRows * Tokens.dock.popup.row.height

			QpScroll { flickable: list }

			ListView {
				id: list
				anchors.fill: parent
				clip: true
				interactive: false // QpScroll scrolls it
				boundsBehavior: Flickable.StopAtBounds
				model: root.results

				delegate: Rectangle {
					id: row
					required property var modelData
					required property int index
					readonly property bool selected: row.index === root.selectedIndex

					objectName: "row:" + row.modelData.id
					width: list.width
					height: Tokens.dock.popup.row.height
					radius: Tokens.dock.popup.row.radius
					color: row.selected ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedAlpha) : "transparent"
					border.width: row.selected ? 1 : 0
					border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, Tokens.dock.popup.selectedEdgeAlpha)

					HoverHandler {
						cursorShape: Qt.PointingHandCursor
						onHoveredChanged: if (hovered) root.selectedIndex = row.index
					}
					TapHandler { onTapped: root.chosen(row.modelData) }

					Rectangle {
						id: iconBox
						x: Tokens.dock.popup.row.paddingH
						anchors.verticalCenter: parent.verticalCenter
						width: Tokens.dock.popup.row.icon
						height: width
						radius: Tokens.dock.popup.row.iconRadius
						color: root.theme.groupBg
						clip: true

						Rectangle {
							objectName: "swatch"
							anchors.fill: parent
							visible: !!row.modelData.swatch
							color: row.modelData.swatch || "transparent"
						}
						SvgIcon {
							objectName: "symbol"
							anchors.centerIn: parent
							visible: !!row.modelData.symbol && rowImage.status !== Image.Ready
							name: row.modelData.symbol || "file"
							size: 16
							color: root.theme.textMuted
						}
						Image {
							id: rowImage
							anchors.fill: parent
							source: row.modelData.icon || ""
							sourceSize: Qt.size(64, 64)
							asynchronous: true
							fillMode: Image.PreserveAspectFit
							opacity: status === Image.Ready ? 1 : 0
						}
						Text {
							objectName: "glyph"
							anchors.centerIn: parent
							visible: rowImage.status !== Image.Ready && !row.modelData.symbol && !row.modelData.swatch
							text: row.modelData.glyph || row.modelData.name.slice(0, 1)
							// An emoji (its own id) draws in full colour.
							color: row.modelData.id === row.modelData.glyph ? "white" : root.theme.textMuted
							font.family: Fonts.familyFor(Font.DemiBold)
							font.pixelSize: row.modelData.glyph ? 18 : Tokens.dock.popup.row.initial
							font.weight: Font.DemiBold
						}
					}

					Column {
						x: iconBox.x + iconBox.width + Tokens.dock.popup.row.gap
						anchors.verticalCenter: parent.verticalCenter
						width: row.width - x - Tokens.dock.popup.row.paddingH

						Text {
							objectName: "name"
							width: parent.width
							text: row.modelData.name
							textFormat: Text.PlainText
							elide: Text.ElideRight
							color: root.theme.text
							font.family: Fonts.familyFor(Font.Medium)
							font.pixelSize: Tokens.dock.popup.row.name
							font.weight: Font.Medium
						}
						Text {
							objectName: "sub"
							visible: text !== ""
							width: parent.width
							text: row.modelData.sub || ""
							textFormat: Text.PlainText
							elide: Text.ElideRight
							color: root.theme.textMuted
							font.family: Fonts.family
							font.pixelSize: Tokens.launcher.sub
						}
					}
				}
			}
		}

		Rectangle {
			objectName: "preview"
			visible: root._preview !== null
			x: Tokens.launcher.width
			y: Tokens.launcher.padding
			width: Tokens.launcher.preview.width - Tokens.launcher.padding + Tokens.launcher.preview.gap
			height: parent.height - 2 * Tokens.launcher.padding
			radius: Tokens.launcher.preview.radius
			color: root.theme.groupBg
			clip: true

			Image {
				objectName: "previewImage"
				anchors.fill: parent
				anchors.margins: 8
				visible: root._preview?.kind === "image"
				source: root._preview?.image ?? ""
				asynchronous: true
				fillMode: Image.PreserveAspectFit
			}
			Column {
				anchors.centerIn: parent
				visible: root._preview?.kind === "color"
				spacing: 10
				Rectangle {
					objectName: "previewSwatch"
					width: Tokens.launcher.preview.swatch
					height: width
					radius: 14
					color: root._preview?.color ?? "transparent"
					border.width: 1
					border.color: root.theme.border
				}
				Text {
					anchors.horizontalCenter: parent.horizontalCenter
					text: root._preview?.text ?? ""
					color: root.theme.text
					font.family: Fonts.family
					font.pixelSize: Tokens.launcher.preview.text
				}
			}
			Text {
				objectName: "previewText"
				anchors.fill: parent
				anchors.margins: 12
				visible: root._preview?.kind === "text"
				text: root._preview?.text ?? ""
				textFormat: Text.PlainText
				wrapMode: Text.WrapAnywhere
				elide: Text.ElideRight
				color: root.theme.text
				font.family: Fonts.family
				font.pixelSize: Tokens.launcher.preview.text
			}
		}
	}
}
