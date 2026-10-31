import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens
import "../notch/qp"
import "cheatsheet.js" as Logic

// The keybind cheatsheet: the launcher's card, with each group as a column of
// keycaps and what they do. Pure: CheatsheetWindow.qml binds the service.
Item {
	id: root

	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	// { name, binds: [{ keys: [text], text }] }
	property var groups: []

	signal dismissed()

	readonly property bool shown: root._open || card.opacity > 0
	property bool _open: false

	function open() {
		root._open = true;
		enter.jump(0);
		root.forceActiveFocus();
	}
	function close() { root._open = false; }

	focus: true
	Keys.onEscapePressed: root.dismissed()

	// cursor: default — a click on the screen around the card dismisses it
	MouseArea {
		anchors.fill: parent
		enabled: root._open
		onClicked: root.dismissed()
	}

	Spring {
		id: enter
		stiffness: Tokens.morph.stiffness
		damping: Tokens.morph.damping
		mass: Tokens.morph.mass
		initial: 0
		target: root._open ? 1 : 0
	}

	RectangularShadow {
		anchors.fill: card
		visible: card.visible
		opacity: card.opacity
		scale: card.scale
		offset.y: 12
		blur: Tokens.dock.popup.shadow.blur
		radius: Tokens.launcher.radius
		color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
	}

	readonly property real _morph: Tokens.morph.from + (1 - Tokens.morph.from) * Math.max(0, Math.min(1.02, enter.value))
	Rectangle {
		id: card
		objectName: "card"
		x: (root.width - width) / 2
		y: (root.height - height) / 2
		width: Math.min(Tokens.cheatsheet.width, root.width - 2 * Tokens.cheatsheet.margin) * root._morph
		height: Math.min(flick.contentHeight + 2 * Tokens.cheatsheet.padding, root.height - 2 * Tokens.cheatsheet.margin) * root._morph
		radius: Tokens.launcher.radius
		color: root.theme.bgExpanded
		border.width: 1
		border.color: root.theme.border
		clip: true
		visible: opacity > 0
		opacity: root._open ? Math.min(1, Math.max(0, enter.value)) : 0
		Behavior on opacity {
			enabled: !root._open
			NumberAnimation { duration: Tokens.launcher.exitMs }
		}

		// Clicks on the card stay on it.
		// cursor: default — the card's own surface
		MouseArea { anchors.fill: parent }

		QpScroll { flickable: flick }
		ScrollThumb { objectName: "sheetThumb"; flickable: flick; thumbColor: Qt.rgba(1, 1, 1, 0.2) }

		Flickable {
			id: flick
			anchors.fill: parent
			anchors.margins: Tokens.cheatsheet.padding
			contentHeight: Math.max(sheet.implicitHeight, empty.visible ? empty.implicitHeight : 0)
			interactive: false // QpScroll scrolls it
			boundsBehavior: Flickable.StopAtBounds
			clip: true

			Text {
				id: empty
				objectName: "empty"
				visible: root.groups.length === 0
				text: "No keybinds have descriptions yet"
				color: root.theme.textMuted
				font.family: Fonts.family
				font.pixelSize: Tokens.cheatsheet.text
			}

			Row {
				id: sheet
				spacing: Tokens.cheatsheet.gap

				Repeater {
					model: Logic.columns(root.groups, 3)
					delegate: Column {
						id: column
						required property var modelData
						width: (flick.width - 2 * Tokens.cheatsheet.gap) / 3
						spacing: Tokens.cheatsheet.gap

						Repeater {
							model: column.modelData
							delegate: Column {
								id: group
								required property var modelData
								readonly property string title: group.modelData.name
								objectName: "group:" + group.modelData.name
								width: column.width
								spacing: Tokens.cheatsheet.rowGap

						Text {
							text: group.title
							color: root.theme.text
							font.family: Fonts.familyFor(Font.DemiBold)
							font.pixelSize: Tokens.cheatsheet.title
							font.weight: Font.DemiBold
						}
						Repeater {
							model: group.modelData.binds
							delegate: Item {
								id: line
								required property var modelData
								width: group.width
								height: Math.max(caps.height, label.height)

								Row {
									id: caps
									spacing: Tokens.cheatsheet.capGap
									anchors.verticalCenter: parent.verticalCenter

									Repeater {
										model: line.modelData.keys
										delegate: Rectangle {
											id: cap
											required property string modelData
											readonly property string text: cap.modelData
											objectName: "cap:" + line.modelData.text + ":" + cap.modelData
											width: capText.implicitWidth + 2 * Tokens.cheatsheet.capPadding
											height: Tokens.cheatsheet.capHeight
											radius: Tokens.cheatsheet.capRadius
											color: root.theme.groupBg

											Text {
												id: capText
												anchors.centerIn: parent
												text: cap.modelData
												color: root.theme.text
												font.family: Fonts.familyFor(Font.Medium)
												font.pixelSize: Tokens.cheatsheet.cap
												font.weight: Font.Medium
											}
										}
									}
								}
								Text {
									id: label
									objectName: "bind:" + line.modelData.text
									x: caps.width + Tokens.cheatsheet.capGap * 2
									width: line.width - x
									anchors.verticalCenter: parent.verticalCenter
									text: line.modelData.text
									textFormat: Text.PlainText
									elide: Text.ElideRight
									color: root.theme.textMuted
									font.family: Fonts.family
									font.pixelSize: Tokens.cheatsheet.text
								}
							}
						}
							}
						}
					}
				}
			}
		}
	}
}
