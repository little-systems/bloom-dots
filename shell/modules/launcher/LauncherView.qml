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
	// The window supplies compositor activation; standalone views may focus directly.
	property bool inputAllowed: true
	property string chatError: ""
	signal chatSubmitted(string text)
	signal chatSettingsRequested()
	signal chatStopRequested()
	signal chatClearRequested()
	signal chatRetryRequested()
	signal chatCopyRequested(string text)
	signal chatLinkRequested(string url)
	property int selectedIndex: 0

	signal queryEdited(string text)
	signal chosen(var item)
	signal dismissed()

	readonly property bool shown: root._open || card.opacity > 0
	readonly property real barHeight: Tokens.launcher.field.height + 2 * Tokens.launcher.padding
	readonly property real targetHeight: root.chatting ? Math.min(chatSurface.preferredHeight, root.height * 0.76)
		: root.barHeight + (root.results.length ? Tokens.launcher.gap + root._listHeight : 0)
	readonly property real targetWidth: root.chatting ? Math.min(660, root.width - 48) : Tokens.launcher.width
	// Images run taller than the other rows, so the card grows by what's shown.
	readonly property real _maxList: Tokens.launcher.maxRows * Tokens.dock.popup.row.height
	readonly property real _listHeight: Math.min(root._maxList, root.results.reduce((sum, r) => sum + root._rowHeight(r), 0))
	function _rowHeight(row) {
		return row.thumbnail !== undefined ? Tokens.launcher.thumb.height + 2 * Tokens.launcher.thumb.padding : Tokens.dock.popup.row.height;
	}

	property bool _open: false
	function focusInput() {
		if (!root._open || !root.inputAllowed) return;
		if (root.chatting) chatSurface.focusInput(); else field.forceActiveFocus();
	}
	function clearInputFocus() { field.focus = false; chatSurface.clearInputFocus(); }
	onInputAllowedChanged: {
		if (root.inputAllowed) root.focusInput(); else root.clearInputFocus();
	}

	function open() {
		field.text = "";
		root.selectedIndex = 0;
		root._open = true;
		enter.jump(0);
		root.focusInput();
	}
	// Opens, or if open moves, with this text already typed.
	function openWith(text) {
		if (!root._open) root.open();
		field.text = text;
		field.cursorPosition = text.length;
		if (root.chatting) { chatSurface.draft = text.replace(/^@\s*/, ""); root.focusInput(); }
	}
	function close() {
		root._open = false;
		root.clearInputFocus();
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
	onChattingChanged: if (root.chatting) { chatSurface.draft = field.text.replace(/^@\s*/, ""); root.focusInput(); }

	// cursor: default — a click on the screen around the bar dismisses it
	MouseArea {
		anchors.fill: parent
		enabled: root._open
		onClicked: root.dismissed()
	}

	Spring { id: widthSpring; stiffness: Tokens.launcher.height.stiffness; damping: Tokens.launcher.height.damping; initial: Tokens.launcher.width; target: root.targetWidth }
	Spring {
		id: heightSpring
		stiffness: Tokens.launcher.height.stiffness
		damping: Tokens.launcher.height.damping
		initial: root.barHeight
		target: root.targetHeight
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
		y: root.height * Tokens.launcher.top
		width: widthSpring.value * root._morph
		height: heightSpring.value * root._morph
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		clip: true
		visible: opacity > 0
		transformOrigin: Item.Top
		opacity: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
		Behavior on opacity {
			enabled: !root._open
			NumberAnimation { duration: Tokens.launcher.exitMs }
		}

		// Clicks on the card stay on it.
		// cursor: default — the card's own surface
		MouseArea { anchors.fill: parent }

		Rectangle {
			id: fieldBox
			visible: !root.chatting
			x: Tokens.launcher.padding
			y: Tokens.launcher.padding
			width: Tokens.launcher.width - 2 * Tokens.launcher.padding
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
				font.pixelSize: Fonts.px(Tokens.launcher.field.size)
				onTextChanged: { root.queryEdited(text); if (root.chatting) chatSurface.draft = text.replace(/^@\s*/, ""); }
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
			ScrollThumb { objectName: "listThumb"; flickable: list; thumbColor: Qt.rgba(1, 1, 1, 0.2) }

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
							font.pixelSize: Fonts.px(row.modelData.glyph ? 18 : Tokens.dock.popup.row.initial)
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
							font.pixelSize: Fonts.px(Tokens.dock.popup.row.name)
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
							font.pixelSize: Fonts.px(Tokens.launcher.sub)
						}
					}
				}
			}
		}

		ChatView {
			id: chatSurface
			anchors.fill: parent
			visible: root.chatting
			theme: root.theme; accent: root.accent
			messages: root.messages; busy: root.busy; error: root.chatError
			onSubmitted: text => { root.chatSubmitted(text); field.text = "@ "; }
			onSettingsRequested: root.chatSettingsRequested()
			onStopRequested: root.chatStopRequested()
			onClearRequested: root.chatClearRequested()
			onRetryRequested: root.chatRetryRequested()
			onCopied: text => root.chatCopyRequested(text)
			onLinkRequested: url => root.chatLinkRequested(url)
			onDismissed: root.dismissed()
			onBackRequested: { field.text = ""; field.forceActiveFocus(); }
		}
	}
}
