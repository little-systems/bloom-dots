import QtQuick
import "../../common"
import "../../common/render"
import "chat-format.js" as Format

Item {
	id: root
	required property string body
	required property string speaker
	required property QtObject theme
	property color accent: "#007aff"
	property bool streaming: false
	readonly property bool mine: speaker === "user"
	signal copied(string text)
	signal linkRequested(string url)
	implicitHeight: bubble.height + (mine ? 0 : 25)
	opacity: arrival.progress
	transform: Translate { y: arrival.rise }
	OpeningMotion { id: arrival; initial: Render.reduceMotion ? 1 : 0; target: 1 }

	Rectangle {
		id: bubble
		x: root.mine ? parent.width - width : 0
		width: root.mine ? Math.min(parent.width * 0.84, Math.max(72, measure.width + 28)) : parent.width
		height: content.height + (root.mine ? 24 : 28)
		radius: 14
		color: root.mine ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14) : root.theme.groupBg
		TextMetrics { id: measure; text: root.body; font: content.font }
		TextEdit {
			id: content
			objectName: "chatMessage"
			x: 14; y: root.mine ? 12 : 14
			width: parent.width - 28
			height: Math.max(20, contentHeight)
			text: root.mine ? root.body : Format.markdown(root.body)
			textFormat: root.mine ? TextEdit.PlainText : TextEdit.MarkdownText
			readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
			color: root.theme.text; selectionColor: root.accent
			font.family: Fonts.family; font.pixelSize: Fonts.px(14)
			onLinkActivated: link => { if (Format.safeLink(link)) root.linkRequested(link); }
		}
	}
	Row {
		y: bubble.height + 5; height: 20; spacing: 6
		visible: !root.mine
		SvgIcon { anchors.verticalCenter: parent.verticalCenter; name: "sparkles"; color: root.theme.textMuted; size: 11 }
		Text { anchors.verticalCenter: parent.verticalCenter; text: root.streaming ? "Bloom AI · Writing" : "Bloom AI"; color: root.theme.textMuted; font.family: Fonts.family; font.pixelSize: Fonts.px(10)}
	}
	Rectangle {
		objectName: "copyReply"
		x: parent.width - width; y: bubble.height + 3; width: 24; height: 22; radius: 6
		visible: !root.mine && !root.streaming
		color: copyHover.hovered ? root.theme.groupBg : "transparent"
		activeFocusOnTab: true
		Accessible.role: Accessible.Button; Accessible.name: "Copy reply"
		Keys.onReturnPressed: root.copied(root.body)
		Keys.onSpacePressed: root.copied(root.body)
		SvgIcon { anchors.centerIn: parent; name: "copy"; size: 12; color: root.theme.textMuted }
		HoverHandler { id: copyHover; cursorShape: Qt.PointingHandCursor }
		TapHandler { onTapped: root.copied(root.body) }
	}
}
