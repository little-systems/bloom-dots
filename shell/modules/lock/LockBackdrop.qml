import QtQuick
import "../../common/tokens.js" as Tokens
import "../notch"

// The wallpaper, blurred, on solid black, placed exactly where the desktop draws
// it so only the blur appears to change. It fades in over the desktop once the blur is ready, so locking never flashes
// black, and `covered` says the screen is fully hidden. A wallpaper that's
// missing or slow doesn't hold that up past enter.maxMs.
Rectangle {
	id: root

	property string source: ""
	property real zoom: 1
	// Only after a correct password does this let anything through.
	property bool leaving: false
	property bool locked: false
	property bool shown: false
	onLockedChanged: if (root.locked) root.shown = false
	signal covered()

	objectName: "backdrop"
	color: "black"
	clip: true
	// Not quite 0 at first: Qt skips a fully transparent subtree, blur included.
	opacity: root.leaving ? 0 : root.shown ? 1 : 0.01
	onOpacityChanged: if (opacity === 1) root.covered()
	Behavior on opacity {
		NumberAnimation {
			duration: root.leaving ? Tokens.lock.leave.ms : Tokens.lock.enter.coverMs
			easing.type: Easing.OutCubic
		}
	}

	FilterBlur {
		id: blur
		anchors.fill: parent
		anchors.margins: -Tokens.lock.blur.spill
		sigma: Tokens.lock.blur.sigma
		downscale: Tokens.lock.blur.downscale

		// A soft copy past the screen's edge, so the blur has colour to pull in
		// there instead of darkening towards the transparent surround.
		Image {
			anchors.fill: parent
			source: root.source
			sourceSize: Qt.size(root.width / 8, root.height / 8)
			asynchronous: true
			fillMode: Image.PreserveAspectCrop
			cache: false
		}
		Image {
			id: wallpaper
			x: Tokens.lock.blur.spill
			y: Tokens.lock.blur.spill
			width: root.width
			height: root.height
			scale: root.zoom
			source: root.source
			sourceSize: Qt.size(root.width * root.zoom, root.height * root.zoom)
			asynchronous: true
			fillMode: Image.PreserveAspectCrop
			cache: false
		}
	}

	// The blur is rendered once and kept as a still: a locked screen can sit
	// for hours, and re-running it would keep the GPU awake all that time.
	ShaderEffectSource {
		id: still
		objectName: "still"
		anchors.fill: blur
		sourceItem: blur
		hideSource: true
		live: false
		visible: false
		textureSize: Qt.size(blur.width / Tokens.lock.blur.downscale, blur.height / Tokens.lock.blur.downscale)
	}

	// The blur's own layers need a frame to fill before the still is taken.
	Timer {
		interval: Tokens.lock.blur.settleMs
		running: root.locked && wallpaper.status === Image.Ready
		onTriggered: {
			still.scheduleUpdate();
			still.visible = true;
			root.shown = true;
		}
	}
	Timer {
		interval: Tokens.lock.enter.maxMs - Tokens.lock.enter.coverMs
		running: root.locked
		onTriggered: root.shown = true
	}

	Rectangle {
		anchors.fill: parent
		color: "black"
		opacity: Tokens.lock.blur.dim
	}
}
