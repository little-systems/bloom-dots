import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/screens.js" as Screens

// The picker on the focused screen: a full-screen layer, mapped only while it
// shows, that takes the keyboard.
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
	visible: targetScreen && (Wallpaper.opened || view.shown)
	WlrLayershell.namespace: "bloom:wallpaper-picker"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Wallpaper.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	PickerView {
		id: view
		width: win.width / win.uiScale
		height: win.height / win.uiScale
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		accent: Theme.accent
		items: Wallpaper.items
		current: Wallpaper.path
		onChosen: path => Wallpaper.set(path)
		onDismissed: Wallpaper.hide()
	}

	Connections {
		target: Wallpaper
		function onOpenedChanged() {
			if (Wallpaper.opened) view.open();
			else view.close();
		}
	}
}
