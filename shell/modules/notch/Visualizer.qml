import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "music.js" as Music

// Bloom's 5-bar visualizer: each bar's height and opacity spring (600/30,
// mass 0.5) towards its level while playing, and rest low and dim when paused.
Row {
	id: root

	property bool playing: false
	property var levels: [0.18, 0.18, 0.18, 0.18, 0.18]
	property real barHeight: Tokens.music.visualizer.height
	property color color: "white"

	spacing: Tokens.music.visualizer.gap
	height: root.barHeight

	Repeater {
		model: Tokens.music.visualizer.bars

		Rectangle {
			id: bar
			required property int index
			readonly property real targetScale: Music.barScale(root.playing, root.levels[bar.index] ?? Tokens.music.visualizer.idleLevel)
			readonly property real targetOpacity: root.playing ? 0.95 : 0.5

			objectName: "bar" + bar.index
			anchors.verticalCenter: parent.verticalCenter
			width: Tokens.music.visualizer.barWidth
			height: root.barHeight
			radius: 2
			color: root.color
			opacity: opacitySpring.value
			transform: Scale { origin.y: root.barHeight / 2; yScale: scaleSpring.value }

			Spring { id: scaleSpring; stiffness: 600; damping: 30; mass: 0.5; initial: 0.1; target: bar.targetScale }
			Spring { id: opacitySpring; stiffness: 600; damping: 30; mass: 0.5; initial: 0.5; target: bar.targetOpacity }
		}
	}
}
