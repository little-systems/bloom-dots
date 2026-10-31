import QtQuick
import "../common/render"
import "../modules/osd"

// Bloom's OverlayPreview: the real HUD card at 70%, with a sample value you can
// drag. It changes nothing on the system.
Item {
	id: root
	property QtObject theme
	property var values
	required property string feature

	anchors.fill: parent

	readonly property bool _volume: root.feature === "volume"
	readonly property bool _on: root.values[root._volume ? "bloom-volume-hud-enabled" : "bloom-brightness-hud-enabled"]
	readonly property bool _edge: root.values[root._volume ? "bloom-volume-edge-enabled" : "bloom-brightness-edge-enabled"]
	property real sample: root._volume ? 0.64 : 0.78

	Text {
		objectName: "previewHudOff"
		visible: !root._on
		anchors.centerIn: parent
		text: (root._volume ? "Volume" : "Brightness") + " HUD is off"
		color: root.theme.textMuted
		font.family: Fonts.ui
		font.pixelSize: 12
	}
	Item {
		id: frame
		objectName: "previewHud"
		visible: root._on
		x: root._volume ? 0 : parent.width - width
		y: 5
		width: card.width
		height: card.height
		scale: 0.7
		transformOrigin: root._volume ? Item.TopLeft : Item.TopRight

		OsdCard {
			id: card
			edge: root._volume ? "left" : "right"
			theme: root.theme
			value: root.sample
			shown: true
			onValueChosen: value => root.sample = value
		}
	}
	Rectangle {
		objectName: "previewEdge"
		visible: root._on && root._edge
		x: root._volume ? 0 : parent.width - width
		y: 12
		width: 2
		height: parent.height - 24
		opacity: 0.75
		color: root.theme.accent ?? "#007aff"
	}
}
