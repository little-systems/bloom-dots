import QtQuick
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens

// A card on the overlay: Bloom's surface, dragged by its title.
Rectangle {
	id: root
	property QtObject theme
	required property string title
	default property alias content: body.data
	// The view's morph: cards open from their top-left in both directions.
	property real factor: 1
	required property real fullWidth
	required property real fullHeight
	width: root.fullWidth * root.factor
	height: root.fullHeight * root.factor
	clip: true

	objectName: "card:" + root.title
	radius: Tokens.overlay.radius
	color: root.theme.bgExpanded
	border.width: 1
	border.color: root.theme.border

	// A click on the card stays on it.
	// cursor: default — the card's own surface
	MouseArea { anchors.fill: parent }

	Text {
		id: heading
		x: Tokens.overlay.padding
		y: Tokens.overlay.padding
		text: root.title
		color: root.theme.text
		font.family: Fonts.familyFor(Font.DemiBold)
		font.pixelSize: 13
		font.weight: Font.DemiBold
	}
	MouseArea {
		objectName: "drag:" + root.title
		width: parent.width
		height: heading.y + heading.height + 6
		cursorShape: Qt.OpenHandCursor
		drag.target: root
		drag.minimumX: 0
		drag.minimumY: 0
		drag.maximumX: root.parent.width - root.width
		drag.maximumY: root.parent.height - root.height
	}
	Item {
		id: body
		x: Tokens.overlay.padding
		y: heading.y + heading.height + 8
		width: root.fullWidth - 2 * Tokens.overlay.padding
		height: root.fullHeight - y - Tokens.overlay.padding
	}
}
