import QtQuick
import Quickshell.Hyprland

// Keep menu and Add App input in the dock until the next click outside.
Item {
	id: root

	property var window: null
	property bool active: false
	signal cleared()

	HyprlandFocusGrab {
		active: root.active && root.window !== null
		windows: root.window ? [root.window] : []
		onCleared: root.cleared()
	}
}
