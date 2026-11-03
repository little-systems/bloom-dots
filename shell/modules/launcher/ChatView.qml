import QtQuick
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens

// A dedicated conversation surface inside Spotlight. Stable message rows are
// updated in place while streaming, so new chunks don't replay entrances.
Item {
	id: root
	required property QtObject theme
	property color accent: "#007aff"
	property var messages: []
	property bool busy: false
	property string error: ""
	property string draft: ""
	property bool followTail: true
	readonly property real preferredHeight: Math.min(590, Math.max(340, 70 + transcript.implicitHeight + composer.height + 48))
	signal settingsRequested()
	signal submitted(string text)
	signal stopRequested()
	signal clearRequested()
	signal retryRequested()
	signal backRequested()
	signal dismissed()
	signal copied(string text)
	signal linkRequested(string url)

	function focusInput() { editor.forceActiveFocus(); }
	function clearInputFocus() { editor.focus = false; }
	function send() {
		const text = root.draft.trim();
		if (!text || root.busy) return;
		root.followTail = true; root.submitted(text); root.draft = "";
	}
	ListModel { id: rows }
	function _sync() {
		for (let i = 0; i < messages.length; i++) {
			const m = messages[i]; const key = String(m.id || i);
			if (i >= rows.count || rows.get(i).key !== key) {
				if (i < rows.count) rows.remove(i, rows.count - i);
				rows.append({ key: key, speaker: m.role, body: m.text });
			} else if (rows.get(i).body !== m.text) rows.setProperty(i, "body", m.text);
		}
		if (rows.count > messages.length) rows.remove(messages.length, rows.count - messages.length);
		if (root.followTail) tail.restart();
	}
	onMessagesChanged: _sync()
	Component.onCompleted: _sync()
	Timer { id: tail; interval: 0; onTriggered: if (root.followTail) conversation.contentY = Math.max(0, conversation.contentHeight - conversation.height) }

	component IconButton: Rectangle {
		id: button
		required property string icon
		required property string label
		signal clicked()
		width: 30; height: 30; radius: 9
		color: hover.hovered || activeFocus ? root.theme.groupBg : "transparent"
		activeFocusOnTab: true
		Accessible.role: Accessible.Button; Accessible.name: label
		Keys.onReturnPressed: clicked()
		Keys.onSpacePressed: clicked()
		SvgIcon { anchors.centerIn: parent; name: button.icon; color: root.theme.textMuted; size: 15 }
		HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
		TapHandler { onTapped: button.clicked() }
	}
	Item {
		id: header
		x: 18; y: 14; width: parent.width - 36; height: 40
		Rectangle {
			width: 34; height: 34; radius: 11; color: root.theme.groupBg
			SvgIcon { anchors.centerIn: parent; name: "sparkles"; size: 17; color: root.accent }
		}
		Column {
			x: 44; y: 1; spacing: 2
			Text { text: "Bloom AI"; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(15); font.weight: Font.DemiBold }
			Text { text: root.busy ? "Writing a reply…" : "Gemini · This session"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(11)}
		}
		Row {
			anchors.right: parent.right; spacing: 3
			IconButton { objectName: "chatBack"; icon: "search"; label: "Back to Spotlight"; onClicked: root.backRequested() }
			IconButton { objectName: "chatClear"; icon: "square-pen"; label: "New conversation"; onClicked: { root.clearRequested(); root.focusInput(); } }
			IconButton { objectName: "chatSettings"; icon: "settings"; label: "AI settings"; onClicked: root.settingsRequested() }
			IconButton { icon: "x"; label: "Close chat"; onClicked: root.dismissed() }
		}
	}
	Rectangle { x: 18; y: 62; width: parent.width - 36; height: 1; color: root.theme.border }

	Flickable {
		id: conversation
		objectName: "chat"
		x: 18; y: 76; width: parent.width - 36
		height: Math.max(0, composer.y - y - 14)
		contentHeight: transcript.implicitHeight
		contentWidth: width
		clip: true; interactive: false; boundsBehavior: Flickable.StopAtBounds
		ScrollGlide { flickable: conversation; onUserScrolled: root.followTail = false }
		onContentYChanged: {
			if (contentHeight > height + 2 && contentY < contentHeight - height - 36) root.followTail = false;
		}
		onContentHeightChanged: if (root.followTail) tail.restart()
		onHeightChanged: if (root.followTail) tail.restart()
		Column {
			id: transcript
			width: parent.width; spacing: 16
			Item {
				objectName: "chatHint"
				visible: rows.count === 0 && root.error === ""
				width: parent.width; height: visible ? 186 : 0
				Column {
					anchors.centerIn: parent; width: parent.width; spacing: 10
					SvgIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "sparkles"; size: 26; color: root.accent }
					Text { anchors.horizontalCenter: parent.horizontalCenter; text: "What’s on your mind?"; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(21); font.weight: Font.DemiBold }
					Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: "Think it through, write something, or ask a question."; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(12)}
					Flow {
						anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(430, parent.width); spacing: 6
						Repeater {
							model: ["Explain an idea", "Help me write", "Solve a problem"]
							delegate: Rectangle {
								id: suggestion
								required property string modelData
								width: suggestionLabel.implicitWidth + 20; height: 28; radius: 10
								color: suggestionHover.hovered ? root.theme.border : root.theme.groupBg
								activeFocusOnTab: true
								Accessible.role: Accessible.Button; Accessible.name: modelData
								function fill() { root.draft = modelData + ": "; root.focusInput(); }
								Keys.onReturnPressed: fill()
								Text { id: suggestionLabel; anchors.centerIn: parent; text: suggestion.modelData; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(11)}
								HoverHandler { id: suggestionHover; cursorShape: Qt.PointingHandCursor }
								TapHandler { onTapped: suggestion.fill() }
							}
						}
					}
				}
			}
			Repeater {
				model: rows
				delegate: ChatMessage {
					required property int index
					objectName: "message:" + index
					width: transcript.width
					theme: root.theme; accent: root.accent
					streaming: root.busy && index === rows.count - 1 && speaker === "model"
					onCopied: text => root.copied(text)
					onLinkRequested: url => root.linkRequested(url)
				}
			}
			Row {
				objectName: "chatBusy"
				visible: root.busy && (root.messages[root.messages.length - 1]?.role ?? "") !== "model"
				height: visible ? 28 : 0; spacing: 5
				Repeater {
					model: 3
					delegate: Rectangle {
						id: dot
						required property int index
						width: 5; height: 5; radius: 3; y: 10; color: root.theme.textMuted
						opacity: 0.45
						SequentialAnimation on opacity {
							running: root.busy && dot.visible && !Render.reduceMotion; loops: Animation.Infinite
							PauseAnimation { duration: dot.index * 120 }
							NumberAnimation { to: 1; duration: 280; easing.type: Easing.InOutSine }
							NumberAnimation { to: 0.3; duration: 280; easing.type: Easing.InOutSine }
							PauseAnimation { duration: (2 - dot.index) * 120 }
						}
					}
				}
			}
			Rectangle {
				visible: root.error !== ""; width: parent.width; height: visible ? errorCopy.implicitHeight + 48 : 0; radius: 12; color: root.theme.groupBg
				Text { id: errorCopy; objectName: "chatError"; visible: root.error !== ""; x: 12; y: 10; width: parent.width - 24; text: root.error; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(12)}
				Text {
					x: 12; y: errorCopy.y + errorCopy.height + 8; text: "Try again"; color: root.accent; font.family: Fonts.family; font.pixelSize: Fonts.px(11)
					MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.retryRequested() }
				}
			}
		}
	}
	ScrollThumb { flickable: conversation; thumbColor: root.theme.textMuted }

	Rectangle {
		visible: !root.followTail && conversation.contentHeight > conversation.height
		x: (parent.width - width) / 2; y: composer.y - 32
		width: 104; height: 26; radius: 13; color: root.theme.bgExpanded
		border.width: 1; border.color: root.theme.border
		Text { anchors.centerIn: parent; text: "Latest ↓"; color: root.theme.text; font.family: Fonts.family; font.pixelSize: Fonts.px(11)}
		MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.followTail = true; tail.restart(); } }
	}

	Rectangle {
		id: composer
		x: 14; width: parent.width - 28; height: Math.max(64, Math.min(132, editor.contentHeight + 42))
		y: parent.height - height - 30
		radius: 15; color: root.theme.groupBg
		border.width: 1; border.color: editor.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6) : root.theme.border
		Behavior on height { NumberAnimation { duration: Render.reduceMotion ? 0 : 160; easing.type: Easing.OutCubic } }
		Flickable {
			id: draftScroll
			x: 14; y: 12; width: parent.width - 62; height: Math.min(90, Math.max(22, editor.contentHeight))
			contentHeight: editor.height; contentWidth: width
			clip: true; interactive: false; boundsBehavior: Flickable.StopAtBounds
			ScrollGlide { flickable: draftScroll }

		TextEdit {
			id: editor
			objectName: "chatInput"
			width: draftScroll.width; height: Math.max(22, contentHeight)
			text: root.draft
			onTextChanged: if (root.draft !== text) root.draft = text
			wrapMode: TextEdit.Wrap; selectByMouse: true; clip: true
			color: root.theme.text; selectionColor: root.accent; font.family: Fonts.family; font.pixelSize: Fonts.px(14)
			Accessible.name: "Message Bloom AI"
			onCursorRectangleChanged: {
				if (cursorRectangle.y < draftScroll.contentY) draftScroll.contentY = cursorRectangle.y;
				else if (cursorRectangle.y + cursorRectangle.height > draftScroll.contentY + draftScroll.height)
					draftScroll.contentY = Math.max(0, cursorRectangle.y + cursorRectangle.height - draftScroll.height);
			}
			Keys.onPressed: event => {
				if (event.key === Qt.Key_Escape) { root.dismissed(); event.accepted = true; }
				else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) { root.send(); event.accepted = true; }
			}
		}
		}

		Text { x: draftScroll.x; y: draftScroll.y; visible: !editor.text; text: "Message Bloom AI…"; color: root.theme.textMuted; font: editor.font }
		Rectangle {
			objectName: "chatSend"
			anchors.right: parent.right; anchors.rightMargin: 10; anchors.bottom: parent.bottom; anchors.bottomMargin: 10
			width: 32; height: 32; radius: 11
			readonly property bool actionable: root.busy || root.draft.trim().length > 0
			color: actionable ? root.accent : root.theme.border
			activeFocusOnTab: true
			Accessible.role: Accessible.Button; Accessible.name: root.busy ? "Stop response" : "Send message"
			function act() { if (root.busy) root.stopRequested(); else root.send(); }
			Keys.onReturnPressed: act()
			SvgIcon { anchors.centerIn: parent; name: root.busy ? "square" : "arrow-up"; size: root.busy ? 12 : 16; color: "white" }
			HoverHandler { cursorShape: Qt.PointingHandCursor }
			TapHandler { onTapped: parent.act() }
		}
	}
	Text {
		anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 22
		text: "Enter to send · Shift+Enter for a new line"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(10)
	}
}
