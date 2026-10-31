import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/screens.js" as Screens

// The session menu on the focused screen: a full-screen layer, mapped only
// while it shows, that takes the keyboard.
PanelWindow {
	id: win
	required property var modelData
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "transparent"
	exclusiveZone: 0
	visible: targetScreen && (Session.opened || view.shown)
	WlrLayershell.namespace: "bloom:session"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Session.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	SessionView {
		id: view
		width: win.width / win.uiScale
		height: win.height / win.uiScale
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		busy: Session.busy
		onActionChosen: id => Session.run(id)
		onDismissed: Session.hide()
	}

	Connections {
		target: Session
		function onOpenedChanged() {
			if (Session.opened) view.open();
			else view.close();
		}
	}
}
