import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/screens.js" as Screens
import "wallpaper.js" as Logic

// The picker on the focused screen: a full-screen layer, mapped only while it
// shows, that takes the keyboard.
PanelWindow {
	id: win
	required property var modelData
	readonly property real uiScale: Settings.values["bloom-scale"]
	function chooseFile() { Wallpaper.browse("file"); }
	function chooseFolder() { Wallpaper.browse("folder"); }
	readonly property bool dialogOpen: Wallpaper.pickerRunning
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "transparent"
	// Keep the full-screen picker aligned to the output, even with fixed panels.
	exclusiveZone: -1
	visible: targetScreen && !win.dialogOpen && (Wallpaper.opened || view.shown)
	WlrLayershell.namespace: "bloom:wallpaper-picker"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Wallpaper.opened && !win.dialogOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
		folder: Wallpaper.folder
		defaultFolder: Wallpaper.defaultFolder
		error: Wallpaper.error
		loading: Wallpaper.loading
		onBrowseFolderRequested: win.chooseFolder()
		onBrowseFileRequested: win.chooseFile()
		onFolderRequested: path => Wallpaper.chooseFolder(path)
		onRefreshRequested: Wallpaper.refresh()
		onChosen: path => Wallpaper.set(path)
		onDismissed: Wallpaper.hide()
	}

	Connections {
		target: Wallpaper
		function onPickerRunningChanged() { if (!Wallpaper.pickerRunning && Wallpaper.opened) view.forceActiveFocus(); }
		function onOpenedChanged() {
			if (Wallpaper.opened) view.open();
			else view.close();
		}
	}
}
