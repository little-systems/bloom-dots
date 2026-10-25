import QtQuick
import Quickshell.Hyprland

// Hyprland's event stream, in its own file so the Hyprland module is only
// touched under Hyprland (using it elsewhere logs a warning).
Item {
	id: root

	signal changed()

	Connections {
		target: Hyprland
		function onRawEvent(event) {
			if (["openlayer", "closelayer", "screencast"].indexOf(event.name) < 0)
				root.changed();
		}
	}
}
