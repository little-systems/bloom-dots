import QtQuick
import "../common"
import "../common/render"
import "logic.js" as Logic
import "preview.js" as Preview

// One sample status widget in the notch preview.
Row {
	id: root
	required property string modelData
	property QtObject theme
	property var values
	spacing: 3

	SvgIcon {
		name: Logic.widget(root.modelData).icon
		size: 12
		color: root.theme.textMuted
		anchors.verticalCenter: parent.verticalCenter
	}
	Text {
		text: Preview.widgetText(root.modelData, root.values)
		color: root.theme.textMuted
		font.family: Fonts.familyFor(Font.Medium)
		font.pixelSize: 10
		font.weight: Font.Medium
		anchors.verticalCenter: parent.verticalCenter
	}
}
