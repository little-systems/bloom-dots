import QtQuick
import Quickshell.Hyprland

// This screen's Hyprland workspace for the workspace pulse, in its own file
// so the Hyprland module is only touched under Hyprland (as HyprEvents.qml).
Item {
	id: root

	// Set by NotchWindow on load (a required property can't be met by a plain `source`).
	property var screen: null
	readonly property var monitor: root.screen ? Hyprland.monitorFor(root.screen) : null
	readonly property var workspace: {
		const ws = root.monitor?.activeWorkspace;
		if (!ws || ws.id <= 0)
			return null;
		const ids = Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === root.monitor).map(w => w.id);
		if (ids.indexOf(ws.id) < 0)
			ids.push(ws.id);
		return { id: ws.id, name: ws.name, ids: ids };
	}
}
