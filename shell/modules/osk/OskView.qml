import QtQuick
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "osk.js" as Logic

// The on-screen keyboard: Bloom's card along the bottom. Pure.
Item {
	id: root
	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	property color accent: "#007aff"
	property var held: []
	signal pressed(var key)

	readonly property bool _shift: root.held.indexOf("shift") >= 0
	readonly property var _rows: Logic.rows()

	Rectangle {
		objectName: "keyboard"
		anchors.fill: parent
		radius: Tokens.osk.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border

		Column {
			anchors.centerIn: parent
			spacing: Tokens.osk.gap
			Repeater {
				model: root._rows
				delegate: Row {
					id: keyRow
					required property var modelData
					anchors.horizontalCenter: parent.horizontalCenter
					spacing: Tokens.osk.gap
					Repeater {
						model: keyRow.modelData
						delegate: Rectangle {
							id: key
							required property var modelData
							readonly property bool latched: !!key.modelData.modifier && root.held.indexOf(key.modelData.modifier) >= 0
							objectName: "key:" + key.modelData.id
							width: Tokens.osk.key * (key.modelData.width ?? 1) + Tokens.osk.gap * ((key.modelData.width ?? 1) - 1)
							height: Tokens.osk.key
							radius: Tokens.osk.keyRadius
							color: key.latched ? root.accent : tap.pressed ? root.theme.border : root.theme.groupBg
							Accessible.role: Accessible.Button
							Accessible.name: key.modelData.label || key.modelData.id

							Text {
								objectName: "cap"
								anchors.centerIn: parent
								text: root._shift && key.modelData.shift ? key.modelData.shift : key.modelData.label
								color: root.theme.text
								font.family: Fonts.family
								font.pixelSize: Tokens.osk.text
							}
							HoverHandler { cursorShape: Qt.PointingHandCursor }
							TapHandler {
								id: tap
								onTapped: root.pressed(key.modelData)
							}
						}
					}
				}
			}
		}
	}
}
