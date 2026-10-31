import QtQuick
import "../../common"
import "../../common/render"
import "../../common/tokens.js" as Tokens

// The overlay: a dimmed screen with cards you can drag. Pure: OverlayWindow.qml
// binds it. A click on the dim or Escape dismisses it.
Item {
	id: root
	property QtObject theme: QtObject {
		property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
		property color border: Qt.rgba(1, 1, 1, 0.12)
		property color text: "white"
		property color textMuted: Qt.rgba(1, 1, 1, 0.6)
		property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	}
	property color accent: "#007aff"
	property string notes: ""
	property bool crosshair: false
	property int cpu: 0
	property real ram: 0
	property int disk: 0
	property int up: 0
	property int down: 0
	// { id, name, volume, muted }
	property var mixer: []
	signal notesEdited(string text)
	signal crosshairToggled(bool on)
	signal volumeChosen(var id, real volume)
	signal recordRequested(string action)
	signal dismissed()

	focus: true
	Keys.onEscapePressed: root.dismissed()

	Rectangle {
		objectName: "dim"
		anchors.fill: parent
		color: Qt.rgba(0, 0, 0, Tokens.overlay.dim)
		// cursor: default — a click on the dim closes the overlay
		MouseArea {
			anchors.fill: parent
			onClicked: root.dismissed()
		}
	}

	component Stat: Item {
		required property string label
		required property string value
		width: parent.width
		height: 22
		Text {
			anchors.verticalCenter: parent.verticalCenter
			text: parent.label
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: 12
		}
		Text {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			text: parent.value
			color: root.theme.text
			font.family: Fonts.familyFor(Font.Medium)
			font.pixelSize: 12
			font.weight: Font.Medium
		}
	}
	component Action: Rectangle {
		required property string text
		signal clicked()
		id: action
		width: label.implicitWidth + 24
		height: 28
		radius: 8
		color: actionHover.hovered ? root.theme.border : root.theme.groupBg
		Accessible.role: Accessible.Button
		Accessible.name: action.text
		Text {
			id: label
			anchors.centerIn: parent
			text: action.text
			color: root.theme.text
			font.family: Fonts.family
			font.pixelSize: 12
		}
		HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
		TapHandler { onTapped: action.clicked() }
	}

	OverlayCard {
		theme: root.theme
		title: "Notes"
		x: 40
		y: 80
		width: 300
		height: 240
		TextEdit {
			objectName: "notes"
			anchors.fill: parent
			text: root.notes
			wrapMode: TextEdit.Wrap
			color: root.theme.text
			selectionColor: root.accent
			font.family: Fonts.family
			font.pixelSize: 13
			onTextChanged: if (text !== root.notes) root.notesEdited(text)
		}
	}
	OverlayCard {
		theme: root.theme
		title: "System"
		x: 40
		y: 340
		width: 300
		height: 170
		Column {
			width: parent.width
			Stat { objectName: "statCpu"; label: "CPU"; value: root.cpu + "%" }
			Stat { label: "Memory"; value: Math.round(root.ram) + "%" }
			Stat { label: "Disk"; value: root.disk + "%" }
			Stat { label: "Network"; value: "↑ " + root.up + "  ↓ " + root.down }
		}
	}
	OverlayCard {
		theme: root.theme
		title: "Volume"
		x: 360
		y: 80
		width: 300
		height: 240
		Text {
			visible: root.mixer.length === 0
			text: "Nothing is playing"
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: 12
		}
		Column {
			width: parent.width
			spacing: 8
			Repeater {
				model: root.mixer
				delegate: Column {
					id: stream
					required property var modelData
					width: parent.width
					spacing: 3
					Text {
						width: parent.width
						text: stream.modelData.name
						textFormat: Text.PlainText
						elide: Text.ElideRight
						color: root.theme.text
						font.family: Fonts.family
						font.pixelSize: 12
					}
					Rectangle {
						objectName: "stream:" + stream.modelData.name
						width: parent.width
						height: 6
						radius: 3
						color: root.theme.groupBg
						Rectangle {
							width: parent.width * Math.min(1, stream.modelData.volume)
							height: parent.height
							radius: 3
							color: root.accent
						}
						MouseArea {
							anchors.fill: parent
							anchors.margins: -6
							cursorShape: Qt.PointingHandCursor
							onPressed: mouse => root.volumeChosen(stream.modelData.id, Math.max(0, Math.min(1, (mouse.x - 6) / parent.width)))
							onPositionChanged: mouse => { if (pressed) root.volumeChosen(stream.modelData.id, Math.max(0, Math.min(1, (mouse.x - 6) / parent.width))); }
						}
					}
				}
			}
		}
	}
	OverlayCard {
		theme: root.theme
		title: "Capture"
		x: 360
		y: 340
		width: 300
		height: 100
		Row {
			spacing: 8
			Action { objectName: "shot"; text: "Screenshot"; onClicked: root.recordRequested("screenshot") }
			Action { objectName: "record"; text: "Record"; onClicked: root.recordRequested("record") }
		}
	}
	OverlayCard {
		theme: root.theme
		title: "Crosshair"
		x: 360
		y: 460
		width: 300
		height: 100
		Action {
			objectName: "crosshairToggle"
			text: root.crosshair ? "Turn Off" : "Pin to Screen"
			onClicked: root.crosshairToggled(!root.crosshair)
		}
	}
}
