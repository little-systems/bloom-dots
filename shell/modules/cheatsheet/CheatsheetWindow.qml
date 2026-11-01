import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/screens.js" as Screens

// The cheatsheet on the focused screen: a full-screen layer, mapped only while
// it shows, that takes the keyboard.
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
	exclusiveZone: -1
	visible: targetScreen && (Cheatsheet.opened || view.shown)
	WlrLayershell.namespace: "bloom:cheatsheet"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Cheatsheet.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	CheatsheetView {
		id: view
		width: win.width / win.uiScale
		height: win.height / win.uiScale
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		groups: Cheatsheet.groups
		onDismissed: Cheatsheet.hide()
	}

	Connections {
		target: Cheatsheet
		function onOpenedChanged() {
			if (Cheatsheet.opened) view.open();
			else view.close();
		}
	}
}
