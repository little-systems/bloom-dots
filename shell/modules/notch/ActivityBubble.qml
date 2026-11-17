import QtQuick
import "../../common"
import "../../common/render"

Rectangle {
	id: root

	property bool shown: false
	property bool leading: false
	property string icon: ""
	property string label: ""
	property string description: ""
	property url art: ""
	property string agent: ""
	property bool light: false
	property real contentPadding: root.label ? 9 : 0
	property color ink: "white"
	signal activated()

	readonly property bool hitEnabled: root.shown && root.opacity > 0.01
	width: Math.max(30, contents.implicitWidth + 2 * root.contentPadding)
	height: 30
	radius: 10
	opacity: root.shown ? 1 : 0
	scale: 0.4 + 0.6 * opacity
	transform: Translate { x: (root.leading ? 28 : -28) * (1 - root.opacity) }
	visible: opacity > 0
	enabled: root.hitEnabled
	activeFocusOnTab: root.hitEnabled
	Accessible.role: Accessible.Button
	Accessible.name: root.description
	Accessible.onPressAction: root.activated()

	Behavior on opacity {
		enabled: !Render.reduceMotion
		NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
	}
	// ColorAnimation: a NumberAnimation on a colour drops its alpha to 1.
	Behavior on color { ColorAnimation { duration: Render.reduceMotion ? 0 : 300 } }
	border.width: root.activeFocus ? 2 : 0
	border.color: root.ink
	Keys.onReturnPressed: root.activated()
	Keys.onSpacePressed: root.activated()
	HoverHandler { cursorShape: Qt.PointingHandCursor }
	TapHandler { onTapped: root.activated() }

	Row {
		id: contents
		anchors.centerIn: parent
		spacing: 4
		SvgIcon {
			anchors.verticalCenter: parent.verticalCenter
			visible: !picture.visible && !agentLogo.visible
			name: root.icon || "music"
			size: root.label ? 12 : 14
			strokeWidth: root.label ? 2.4 : 2.2
			color: root.ink
		}
		AgentLogo {
			id: agentLogo
			visible: root.agent !== ""
			agent: root.agent
			light: root.light
			width: 17
			height: 17
		}
		AlbumArt {
			id: picture
			visible: root.art.toString() !== ""
			source: root.art
			width: 22
			height: 22
		}
		Text {
			anchors.verticalCenter: parent.verticalCenter
			visible: root.label !== ""
			text: root.label
			color: root.ink
			font.family: Fonts.family
			font.pixelSize: Fonts.px(11)
			font.weight: Font.DemiBold
		}
	}
}
