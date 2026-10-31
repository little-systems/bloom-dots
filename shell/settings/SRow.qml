import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's SettingRow: icon, label and description, then a control.
Item {
	id: root
	property QtObject theme
	required property string icon
	required property string label
	property string desc: ""
	property bool action: false
	property bool danger: false
	property bool divider: true
	default property alias control: slot.data
	signal clicked()

	objectName: "row:" + root.label
	width: parent.width
	height: body.height + (root.divider ? 1 : 0)

	Rectangle {
		id: body
		width: parent.width
		height: Math.max(Tokens.settings.row.icon, info.implicitHeight) + 2 * Tokens.settings.row.paddingV
		color: !root.action || !hover.hovered ? "transparent" : root.danger ? Qt.rgba(1, 59 / 255, 48 / 255, 0.15) : root.theme.groupBg
		Behavior on color {
			ColorAnimation { duration: Tokens.settings.row.ms }
		}

		HoverHandler {
			id: hover
			cursorShape: root.action ? Qt.PointingHandCursor : Qt.ArrowCursor
		}
		TapHandler {
			enabled: root.action
			onTapped: root.clicked()
		}

		SvgIcon {
			x: Tokens.settings.row.paddingH + (Tokens.settings.row.icon - width) / 2
			anchors.verticalCenter: parent.verticalCenter
			name: root.icon
			size: Tokens.settings.row.glyph
			strokeWidth: 1.5
			color: hover.hovered ? root.theme.text : root.theme.textMuted
		}
		Column {
			id: info
			x: Tokens.settings.row.paddingH + Tokens.settings.row.icon + Tokens.settings.row.iconGap
			anchors.verticalCenter: parent.verticalCenter
			width: slot.x - x
			spacing: Tokens.settings.row.gap

			Text {
				objectName: "label"
				width: parent.width
				text: root.label
				elide: Text.ElideRight
				color: root.danger ? Tokens.settings.danger : root.theme.text
				font.family: Fonts.uiFor(Font.Medium)
				font.pixelSize: Tokens.settings.row.label
				font.weight: Font.Medium
				height: 16.8
				lineHeight: 16.8
				lineHeightMode: Text.FixedHeight
			}
			Text {
				objectName: "desc"
				visible: root.desc !== ""
				width: parent.width
				text: root.desc
				elide: Text.ElideRight
				color: root.theme.textMuted
				opacity: 0.8
				font.family: Fonts.ui
				font.pixelSize: Tokens.settings.row.desc
				height: 12
				lineHeight: 12
				lineHeightMode: Text.FixedHeight
			}
		}
		Item {
			id: slot
			x: parent.width - Tokens.settings.row.paddingH - width
			anchors.verticalCenter: parent.verticalCenter
			width: childrenRect.width
			height: childrenRect.height
		}
	}
	Rectangle {
		visible: root.divider
		x: Tokens.settings.row.divider
		y: body.height
		width: parent.width - x
		height: 1
		color: root.theme.border
	}
}
