import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services

// The wallpaper on one screen, below every window, crossfading when it changes.
// A video has nothing to draw here: mpvpaper paints the layer below.
PanelWindow {
	id: win
	required property var modelData

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "black"
	// Ignore fixed panels' work-area reservations: the image belongs to the
	// physical output, including the space behind the notch and dock.
	exclusiveZone: -1
	visible: !Wallpaper.video
	mask: Region {}
	WlrLayershell.namespace: "bloom:wallpaper"
	WlrLayershell.layer: WlrLayer.Bottom
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	property Image _front: a

	function _show(path) {
		const next = win._front === a ? b : a;
		next.source = path;
	}
	Connections {
		target: Wallpaper
		function onPathChanged() { if (!Wallpaper.video) win._show(Wallpaper.path); }
	}

	component Layer: Image {
		id: layer
		anchors.fill: parent
		scale: Wallpaper.zoom
		sourceSize: Qt.size(win.width * Wallpaper.zoom, win.height * Wallpaper.zoom)
		asynchronous: true
		cache: false
		fillMode: Image.PreserveAspectCrop
		opacity: win._front === layer ? 1 : 0
		Behavior on opacity {
			NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
		}
		onStatusChanged: if (status === Image.Ready && win._front !== layer && source != "") win._front = layer
	}

	Layer { id: a; source: Wallpaper.video ? "" : Wallpaper.path }
	Layer { id: b }

	Process {
		running: Wallpaper.video && win.modelData === Quickshell.screens[0]
		command: ["mpvpaper", "-o", "no-audio loop", "*", Wallpaper.path]
	}
}
