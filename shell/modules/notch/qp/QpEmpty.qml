import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens
import "../../../common/render"

// .qp-empty: a centred message filling the panel body ("Wi-Fi is off"), with
// an optional icon above and room for a button below.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property string icon: ""
	property string text: ""
	default property alias extra: column.data

	Column {
		id: column
		anchors.centerIn: parent
		width: root.width - Tokens.qp.empty.padH * 2
		spacing: Tokens.qp.empty.gap

		SvgIcon {
			objectName: "glyph"
			visible: root.icon !== ""
			anchors.horizontalCenter: parent.horizontalCenter
			name: root.icon || "wifi-off"
			size: Tokens.qp.empty.glyph
			color: root.theme.textMuted
		}

		Text {
			objectName: "label"
			width: parent.width
			horizontalAlignment: Text.AlignHCenter
			wrapMode: Text.Wrap
			text: root.text
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Tokens.qp.text
		}
	}
}
