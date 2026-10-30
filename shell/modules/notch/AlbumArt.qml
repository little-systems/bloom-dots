import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../common/render"

// Album art that flips when the track's art changes, like Bloom's
// AnimatePresence "wait": the old art turns away, then the new one turns in,
// each half easeInOut. Qt Quick has no perspective, so the turn reads as a
// horizontal squash. Without art it shows Bloom's music-note placeholder.
Item {
	id: root

	property url source: ""
	property real radius: 6
	property int flipMs: Tokens.music.flipMs
	property real noteScale: 0.55
	property color noteColor: Qt.rgba(1, 1, 1, 0.85)
	property color placeholderTop: Qt.rgba(1, 1, 1, 0.12)
	property color placeholderBottom: Qt.rgba(1, 1, 1, 0.03)

	readonly property bool flipping: flip.running
	property url shown: ""
	property real _angle: 0

	Component.onCompleted: root.shown = root.source
	onSourceChanged: if (root.source !== root.shown || flip.running) flip.restart()

	SequentialAnimation {
		id: flip
		NumberAnimation {
			target: root; property: "_angle"; to: -90; duration: root.flipMs
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1]
		}
		ScriptAction { script: { root.shown = root.source; root._angle = 90; } }
		NumberAnimation {
			target: root; property: "_angle"; to: 0; duration: root.flipMs
			easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1]
		}
	}

	Item {
		id: face
		anchors.fill: parent
		opacity: 1 - Math.abs(root._angle) / 90
		transform: Scale { origin.x: face.width / 2; xScale: Math.cos(root._angle * Math.PI / 180) }
		layer.enabled: true
		layer.textureSize: Render.texture(width, height)
		layer.effect: MultiEffect {
			maskEnabled: true
			maskSource: mask
			maskThresholdMin: 0.5
			maskSpreadAtMin: 1
		}

		Rectangle {
			anchors.fill: parent
			visible: image.status !== Image.Ready
			gradient: Gradient {
				GradientStop { position: 0; color: root.placeholderTop }
				GradientStop { position: 1; color: root.placeholderBottom }
			}
		}

		SvgIcon {
			anchors.centerIn: parent
			visible: image.status !== Image.Ready
			name: "sf-music.note"
			size: parent.width * root.noteScale
			color: root.noteColor
		}

		Image {
			id: image
			anchors.fill: parent
			source: root.shown
			fillMode: Image.PreserveAspectCrop
			asynchronous: true
			sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
			visible: status === Image.Ready
		}
	}

	Item {
		id: mask
		anchors.fill: parent
		visible: false
		layer.enabled: true
		layer.textureSize: Render.texture(width, height)
		Rectangle { anchors.fill: parent; radius: root.radius }
	}
}
