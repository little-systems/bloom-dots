import QtQuick
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's .settings-disclosure: a summary line over rows that fold away.
Column {
	id: root
	property QtObject theme
	required property string summary
	property string hint: ""
	property bool standalone: false
	property bool open: false
	default property alias content: body.data

	objectName: "disclosure:" + root.summary
	width: parent.width

	Rectangle {
		visible: !root.standalone
		width: parent.width
		height: 1
		color: root.theme.border
	}
	Rectangle {
		id: summaryRow
		activeFocusOnTab: true
		Accessible.role: Accessible.Button
		Accessible.name: root.summary
		Keys.onSpacePressed: root.open = !root.open
		Keys.onReturnPressed: root.open = !root.open
		SFocusRing { inset: 1; radius: 6 }
		width: parent.width
		height: Math.max(summaryText.implicitHeight, 14) + 22
		color: hover.hovered ? root.theme.border : "transparent"

		Text {
			id: summaryText
			objectName: "summary"
			x: 14
			anchors.verticalCenter: parent.verticalCenter
			text: root.summary
			color: root.theme.text
			font.family: Fonts.uiFor(Font.DemiBold)
			font.pixelSize: 12
			font.weight: Font.DemiBold
		}
		Text {
			anchors.right: chevron.left
			anchors.rightMargin: 8
			anchors.verticalCenter: parent.verticalCenter
			text: root.hint
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: 11
		}
		Rectangle {
			id: chevron
			x: parent.width - 14 - width
			anchors.verticalCenter: parent.verticalCenter
			anchors.verticalCenterOffset: root.open ? 1 : -1
			width: 6
			height: 6
			color: "transparent"
			rotation: root.open ? 225 : 45
			Behavior on rotation { NumberAnimation { duration: 150 } }
			Rectangle { anchors.right: parent.right; width: 1.5; height: parent.height; color: root.theme.textMuted }
			Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1.5; color: root.theme.textMuted }
		}
		HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
		TapHandler { onTapped: root.open = !root.open }
	}
	Rectangle {
		visible: root.open
		width: parent.width
		height: 1
		color: root.theme.border
	}
	Column {
		id: body
		visible: root.open
		width: parent.width
	}
}
