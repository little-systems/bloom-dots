import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/tokens.js" as Tokens
import "../../common/screens.js" as Screens

// The overlay on the focused screen, plus the pinned crosshair, which stays
// after the overlay closes and lets every click through.
Scope {
	id: root
	required property var modelData
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(root.modelData, HyprState.monitors, Quickshell.screens)

	onTargetScreenChanged: SystemStats.hold("overlay", OverlayState.opened)
	Connections {
		target: OverlayState
		function onOpenedChanged() {
			SystemStats.hold("overlay", OverlayState.opened);
			if (OverlayState.opened) view.forceActiveFocus();
		}
	}

	PanelWindow {
		screen: root.modelData
		anchors.top: true
		anchors.bottom: true
		anchors.left: true
		anchors.right: true
		color: "transparent"
		exclusiveZone: -1
		visible: OverlayState.crosshair
		mask: Region {}
		WlrLayershell.namespace: "bloom:crosshair"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

		Rectangle { anchors.centerIn: parent; width: Tokens.overlay.crosshair; height: 2; color: "#00ff66" }
		Rectangle { anchors.centerIn: parent; width: 2; height: Tokens.overlay.crosshair; color: "#00ff66" }
	}

	PanelWindow {
		id: win
		screen: root.modelData
		anchors.top: true
		anchors.bottom: true
		anchors.left: true
		anchors.right: true
		color: "transparent"
		exclusiveZone: -1
		visible: root.targetScreen && (OverlayState.opened || view.shown)
		WlrLayershell.namespace: "bloom:overlay"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: OverlayState.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

		OverlayView {
			id: view
			open: OverlayState.opened
			width: win.width / root.uiScale
			height: win.height / root.uiScale
			scale: root.uiScale
			transformOrigin: Item.TopLeft
			theme: Theme
			accent: Theme.accent
			notes: OverlayState.notes
			crosshair: OverlayState.crosshair
			cpu: SystemStats.cpu
			ram: SystemStats.ram
			disk: SystemStats.disk
			up: SystemStats.up
			down: SystemStats.down
			mixer: Audio.mixerRows
			onNotesEdited: text => OverlayState.setNotes(text)
			onCrosshairToggled: on => OverlayState.crosshair = on
			onVolumeChosen: (id, volume) => Audio.setStreamVolume(id, volume)
			onRecordRequested: action => {
				OverlayState.hide();
				Quickshell.execDetached(["qs", "-c", "bloom", "ipc", "call", "region", "run", action]);
			}
			onDismissed: OverlayState.hide()
		}
	}
}
