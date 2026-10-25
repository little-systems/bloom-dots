import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../common/tokens.js" as Tokens

// Bloom's ambient glow behind the open player: the album art, enlarged and
// heavily blurred, under a radial vignette that fades into the notch colour,
// clipped to the pill's rounded bottom.
Item {
	id: root

	property url source: ""
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property real radius: 18
	readonly property bool shown: art.status === Image.Ready

	opacity: root.shown ? 1 : 0
	Behavior on opacity { NumberAnimation { duration: Tokens.music.ambience.fadeMs } }
	layer.enabled: true
	layer.effect: MultiEffect {
		maskEnabled: true
		maskSource: pillShape
	}

	Image {
		id: art
		anchors.centerIn: parent
		width: parent.width * Tokens.music.ambience.scale
		height: parent.height * Tokens.music.ambience.scale
		source: root.source
		fillMode: Image.PreserveAspectCrop
		asynchronous: true
		sourceSize: Qt.size(128, 128)
		visible: false
	}

	MultiEffect {
		anchors.fill: art
		source: art
		blurEnabled: true
		blurMax: 64
		blur: Tokens.music.ambience.blur / 64
		saturation: 1
		contrast: 0.1
		brightness: 0.4
		opacity: Tokens.music.ambience.opacity
	}

	// Ellipse vignette: a circle stretched to the pill.
	Shape {
		width: root.width
		height: root.width
		y: (root.height - root.width) / 2
		transform: Scale { origin.x: root.width / 2; origin.y: root.width / 2; yScale: root.height / Math.max(1, root.width) }
		ShapePath {
			strokeWidth: -1
			fillGradient: RadialGradient {
				centerX: root.width / 2; centerY: root.width / 2; centerRadius: root.width / 2
				focalX: centerX; focalY: centerY
				GradientStop { position: 0.2; color: "transparent" }
				GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.25) }
				GradientStop { position: 0.85; color: root.bg }
				GradientStop { position: 1; color: root.bg }
			}
			PathRectangle { x: 0; y: 0; width: root.width; height: root.width }
		}
	}

	Item {
		id: pillShape
		anchors.fill: parent
		visible: false
		layer.enabled: true
		Rectangle {
			anchors.fill: parent
			bottomLeftRadius: root.radius
			bottomRightRadius: root.radius
		}
	}
}
