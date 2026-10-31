import QtQuick
import "../common/render"

// Bloom's .unit-toggle-minimal: a small segmented control.
Rectangle {
	id: root
	property QtObject theme
	// [{ value, label }]
	property var options: []
	property string value: ""
	property bool wide: false
	signal activated(string value)

	width: row.width + 6
	height: 24
	radius: 6
	color: root.theme.groupBg
	border.width: 1
	border.color: root.theme.border

	Row {
		id: row
		anchors.centerIn: parent
		spacing: 2
		Repeater {
			model: root.options
			delegate: Rectangle {
				id: cell
				required property var modelData
				objectName: "unit:" + cell.modelData.value
				readonly property bool active: cell.modelData.value === root.value
				width: root.wide ? label.implicitWidth + 20 : 18
				height: 18
				radius: 4
				color: cell.active ? root.theme.border : "transparent"
				Text {
					id: label
					anchors.centerIn: parent
					text: cell.modelData.label
					color: cell.active ? root.theme.text : root.theme.textMuted
					font.family: Fonts.uiFor(Font.Bold)
					font.pixelSize: root.wide ? 11 : 10
					font.weight: Font.Bold
				}
				HoverHandler { cursorShape: Qt.PointingHandCursor }
				TapHandler { onTapped: root.activated(cell.modelData.value) }
			}
		}
	}
}
