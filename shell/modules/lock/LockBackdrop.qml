import QtQuick
import "../../common/tokens.js" as Tokens
import "../notch"

// The wallpaper, blurred and zoomed in as the screen locks, on solid black.
// Solid black stays underneath: session_lock_xray shows anything behind a
// translucent lock surface, so nothing here may ever let the windows through.
Rectangle {
	id: root

	property string source: ""
	// Only after a correct password does this let anything through.
	property bool leaving: false

	objectName: "backdrop"
	color: "black"
	clip: true
	opacity: root.leaving ? 0 : 1
	Behavior on opacity {
		NumberAnimation { duration: Tokens.lock.leave.ms; easing.type: Easing.OutCubic }
	}

	FilterBlur {
		id: blur
		anchors.fill: parent
		anchors.margins: -Tokens.lock.blur.spill
		sigma: Tokens.lock.blur.sigma
		downscale: Tokens.lock.blur.downscale

		Image {
			id: wallpaper
			anchors.fill: parent
			source: root.source
			sourceSize: Qt.size(root.width, root.height)
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
		scale: root.leaving ? 1 : still._zoom
		property real _zoom: 1
		textureSize: Qt.size(blur.width / Tokens.lock.blur.downscale, blur.height / Tokens.lock.blur.downscale)
		Behavior on scale {
			NumberAnimation { duration: Tokens.lock.blur.zoomMs; easing.type: Easing.OutCubic }
		}
	}

	// The blur's own layers need a frame to fill before the still is taken.
	Timer {
		interval: Tokens.lock.blur.settleMs
		running: wallpaper.status === Image.Ready
		onTriggered: {
			still.scheduleUpdate();
			still.visible = true;
			still._zoom = Tokens.lock.blur.zoom;
		}
	}

	Rectangle {
		anchors.fill: parent
		color: "black"
		opacity: Tokens.lock.blur.dim
	}
}
