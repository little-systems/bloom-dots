import QtQuick
import Quickshell.Hyprland
import "dock.js" as Dock

// This screen's Hyprland workspaces for the dock's segment, in its own file
// so the Hyprland module is only touched under Hyprland (as HyprEvents.qml).
Item {
	id: root

	// Set by DockWindow on load (a required property can't be met by a plain `source`).
	property var screen: null
	readonly property var monitor: root.screen ? Hyprland.monitorFor(root.screen) : null
	readonly property var workspace: Dock.workspaceState(root.monitor?.activeWorkspace ?? null, Hyprland.workspaces.values, root.monitor)

	// This monitor's workspaces as { id, name }, for the dock's segment.
	readonly property var workspaces: Hyprland.workspaces.values
		.filter(w => w.monitor === root.monitor)
		.map(w => ({ id: w.id, name: w.name }))
}
