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
	// Chat replaces the list while `chatting`: [{ role, text }].
	property bool chatting: false
	property var messages: []
	property bool busy: false
	property string chatError: ""
	signal chatSubmitted(string text)
	property int selectedIndex: 0

	signal queryEdited(string text)
	signal chosen(var item)
	signal dismissed()

	readonly property bool shown: root._open || card.opacity > 0
	readonly property real barHeight: Tokens.launcher.field.height + 2 * Tokens.launcher.padding
	readonly property real targetHeight: root.barHeight + (root.chatting
		? Tokens.launcher.gap + Tokens.launcher.maxRows * Tokens.dock.popup.row.height
		: root.results.length ? Tokens.launcher.gap + root._listHeight : 0)
	// Images run taller than the other rows, so the card grows by what's shown.
	readonly property real _maxList: Tokens.launcher.maxRows * Tokens.dock.popup.row.height
	readonly property real _listHeight: Math.min(root._maxList, root.results.reduce((sum, r) => sum + root._rowHeight(r), 0))
	function _rowHeight(row) {
		return row.thumbnail !== undefined ? Tokens.launcher.thumb.height + 2 * Tokens.launcher.thumb.padding : Tokens.dock.popup.row.height;
	}

	property bool _open: false

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
			if (root.chatting) {
				const text = field.text.replace(/^@\s*/, "").trim();
				if (text && !root.busy) {
					root.chatSubmitted(text);
					field.text = "@ ";
				}
			} else if (root.results[root.selectedIndex]) root.chosen(root.results[root.selectedIndex]);
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
		width: Tokens.launcher.width
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
					text: "Search anything, or ; : = > ? ! @ for more"
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
			visible: !root.chatting

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
					height: root._rowHeight(row.modelData)
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
						readonly property bool big: row.modelData.thumbnail !== undefined

						width: big ? Tokens.launcher.thumb.width : Tokens.dock.popup.row.icon

						height: big ? Tokens.launcher.thumb.height : width

						radius: big ? Tokens.launcher.thumb.radius : Tokens.dock.popup.row.iconRadius
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
							visible: !!row.modelData.symbol && rowImage.status !== Image.Ready && !row.modelData.thumbnail
							name: row.modelData.symbol || "file"
							size: 16
							color: root.theme.textMuted
						}
						// Decoded at full size, not a reduced copy, so it stays sharp.
						Image {
							objectName: "thumbnail"
							anchors.fill: parent
							visible: iconBox.big
							source: row.modelData.thumbnail ?? ""
							asynchronous: true
							cache: false
							mipmap: true
							smooth: true
							fillMode: Image.PreserveAspectFit
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

		Flickable {
			id: chat
			objectName: "chat"
			visible: root.chatting
			x: Tokens.launcher.padding
			y: fieldBox.y + fieldBox.height + Tokens.launcher.gap
			width: Tokens.launcher.width - 2 * Tokens.launcher.padding
			height: Tokens.launcher.maxRows * Tokens.dock.popup.row.height
			contentHeight: transcript.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds
			onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

			Column {
				id: transcript
				width: chat.width
				spacing: 10

				Text {
					objectName: "chatHint"
					visible: root.messages.length === 0 && root.chatError === ""
					width: parent.width
					topPadding: 8
					horizontalAlignment: Text.AlignHCenter
					text: "Ask Gemini anything. Only what you type here is sent."
					color: root.theme.textMuted
					font.family: Fonts.family
					font.pixelSize: 12
				}
				Repeater {
					model: root.messages
					delegate: Item {
						id: bubble
						required property var modelData
						readonly property bool mine: bubble.modelData.role === "user"
						width: transcript.width
						height: message.implicitHeight + (bubble.mine ? 14 : 0)

						Rectangle {
							visible: bubble.mine
							x: parent.width - width
							width: Math.min(message.implicitWidth + 20, parent.width * 0.8)
							height: parent.height
							radius: 12
							color: root.theme.groupBg
						}
						Text {
							id: message
							objectName: "chatMessage"
							x: bubble.mine ? parent.width - width - 10 : 2
							y: bubble.mine ? 7 : 0
							width: Math.min(implicitWidth, parent.width * 0.8 - 20)
							text: bubble.modelData.text
							textFormat: bubble.mine ? Text.PlainText : Text.MarkdownText
							wrapMode: Text.Wrap
							color: root.theme.text
							linkColor: root.accent
							font.family: Fonts.family
							font.pixelSize: 13
						}
					}
				}
				Text {
					objectName: "chatBusy"
					visible: root.busy && (root.messages[root.messages.length - 1]?.role ?? "") === "user"
					leftPadding: 2
					text: "Thinking…"
					color: root.theme.textMuted
					font.family: Fonts.family
					font.pixelSize: 12
				}
				Text {
					objectName: "chatError"
					visible: root.chatError !== ""
					width: parent.width
					text: root.chatError
					wrapMode: Text.Wrap
					color: "#ff8a80"
					font.family: Fonts.family
					font.pixelSize: 12
				}
			}
		}
	}
}
