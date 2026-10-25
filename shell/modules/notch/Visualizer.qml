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
	// Off-screen visualizers must not animate: a moving spring makes the whole
	// surface redraw every frame. Owners set this to "actually on screen".
	property bool active: true

	spacing: Tokens.music.visualizer.gap
	height: root.barHeight

	// One shared ticker steps every bar together at cava's 30 Hz, so the
	// surface redraws once per data frame instead of every display frame
	// (measured on the UHD 620: 60 fps redraws cost ~15 % of a core). Springs
	// are exact for any step, so the motion follows the same curve.
	property bool _moving: false
	property real _last: 0
	onLevelsChanged: root._moving = true
	onPlayingChanged: root._moving = true
	onActiveChanged: if (root.active) root._moving = true

	Timer {
		interval: Tokens.music.visualizer.frameMs
		repeat: true
		running: root.active && root._moving
		onRunningChanged: root._last = Date.now()
		onTriggered: {
			const now = Date.now();
			const dt = Math.min((now - root._last) / 1000, 0.064);
			root._last = now;
			let moving = false;
			for (let i = 0; i < bars.count; i++) {
				const b = bars.itemAt(i);
				b.scaleSpring.step(dt);
				b.opacitySpring.step(dt);
				moving = moving || !b.scaleSpring.settled || !b.opacitySpring.settled;
			}
			root._moving = moving;
		}
	}

	Repeater {
		id: bars
		model: Tokens.music.visualizer.bars

		Rectangle {
			id: bar
			required property int index
			readonly property real targetScale: Music.barScale(root.playing, root.levels[bar.index] ?? Tokens.music.visualizer.idleLevel)
			readonly property real targetOpacity: root.playing ? 0.95 : 0.5

			objectName: "bar" + bar.index
			readonly property alias scaleSpring: scaleSpring
			readonly property alias opacitySpring: opacitySpring
			anchors.verticalCenter: parent.verticalCenter
			width: Tokens.music.visualizer.barWidth
			height: root.barHeight
			radius: 2
			color: root.color
			opacity: opacitySpring.value
			transform: Scale { origin.y: root.barHeight / 2; yScale: scaleSpring.value }

			Spring { id: scaleSpring; objectName: "barScale" + bar.index; autoRun: false; stiffness: 600; damping: 30; mass: 0.5; initial: 0.1; target: bar.targetScale }
			Spring { id: opacitySpring; autoRun: false; stiffness: 600; damping: 30; mass: 0.5; initial: 0.5; target: bar.targetOpacity }
		}
	}
}
