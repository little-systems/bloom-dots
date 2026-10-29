import QtQuick

// Bloom's device art (src/devices/DeviceArt.tsx): each drawing's connect
// ("play") or disconnect ("leave") animation, recorded frame by frame from
// Bloom itself (tools/bloom-audit/record-device-art.cjs), plays once and
// holds its last frame. `still` draws where the connect animation ends, for
// lists. A new `runId` replays it.
Item {
	id: root

	property string art: "device"
	property string phase: "play"
	property int runId: 0
	property bool still: false

	// The recordings are 100 px for a 60 px drawing: room for glows.
	readonly property real _pad: root.width / 3

	width: 60
	height: 60

	AnimatedImage {
		id: animation
		objectName: "animation"
		visible: !root.still
		x: -root._pad
		y: -root._pad
		width: root.width + root._pad * 2
		height: root.height + root._pad * 2
		source: root.still ? "" : Qt.resolvedUrl(`../../assets/device-art/anim/${root.art}-${root.phase}.webp`)
		fillMode: Image.PreserveAspectFit
		smooth: true
		playing: true

		// A new drawing or phase plays from the start.
		onSourceChanged: playing = true
		// Once, then hold the last frame.
		onCurrentFrameChanged: if (frameCount > 0 && currentFrame === frameCount - 1) playing = false
	}

	Image {
		objectName: "stillImage"
		visible: root.still
		x: -root._pad
		y: -root._pad
		width: root.width + root._pad * 2
		height: root.height + root._pad * 2
		source: root.still ? Qt.resolvedUrl(`../../assets/device-art/anim/${root.art}.png`) : ""
		fillMode: Image.PreserveAspectFit
		smooth: true
		asynchronous: true
	}

	onRunIdChanged: {
		animation.currentFrame = 0;
		animation.playing = true;
	}
}
