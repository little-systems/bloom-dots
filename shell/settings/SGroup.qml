import QtQuick
import "../common/tokens.js" as Tokens

// Bloom's .setting-group: rows on one rounded surface.
Rectangle {
	id: root
	property QtObject theme
	default property alias rows: column.data
	width: parent.width
	height: column.implicitHeight + 2
	radius: Tokens.settings.group.radius
	color: theme.groupBg
	border.width: 1
	border.color: theme.border
	clip: true

	Column {
		id: column
		x: 1
		y: 1
		width: parent.width - 2
	}
}
