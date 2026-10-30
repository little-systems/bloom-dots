import QtQuick
import "../../../common/tokens.js" as Tokens

// .qp-header: back, a title that fills the row, then the panel's actions
// (refresh or add, and the switch), 4 px apart.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property string title: ""
	default property alias actions: actionRow.data

	signal back()

	height: Tokens.qp.iconButton.size

	QpIconButton {
		id: back
		objectName: "back"
		theme: root.theme
		icon: "chevron-left"
		onClicked: root.back()
	}

	Text {
		objectName: "title"
		x: back.width + Tokens.qp.header.gap
		width: actionRow.x - Tokens.qp.header.gap - x
		anchors.verticalCenter: parent.verticalCenter
		text: root.title
		color: root.theme.text
		elide: Text.ElideRight
		font.family: Tokens.type.family
		font.pixelSize: Tokens.qp.header.title
		font.weight: Font.DemiBold
	}

	Row {
		id: actionRow
		anchors.right: parent.right
		anchors.verticalCenter: parent.verticalCenter
		spacing: Tokens.qp.header.gap
		// align-items: center: each action sits mid-row (the 17 px switch
		// beside 24 px buttons).
		onChildrenChanged: {
			for (const child of children) {
				// Unrounded, as Chromium places it (3.5 px down).
				child.anchors.alignWhenCentered = false;
				child.anchors.verticalCenter = actionRow.verticalCenter;
			}
		}
	}
}
