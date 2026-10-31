import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/screens.js" as Screens

// The launcher on the focused screen: a full-screen layer, mapped only while
// it shows, that takes the keyboard. The view binds the Launcher service.
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
	visible: targetScreen && (Launcher.opened || view.shown)
	WlrLayershell.namespace: "bloom:launcher"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Launcher.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	LauncherView {
		id: view
		width: win.width / win.uiScale
		height: win.height / win.uiScale
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		results: Launcher.results
		onQueryEdited: text => Launcher.setQuery(text)
		onChosen: item => Launcher.accept(item)
		onDismissed: Launcher.hide()
	}

	Connections {
		target: Launcher
		function onOpenedChanged() {
			if (Launcher.opened) view.open();
			else view.close();
		}
	}
}
