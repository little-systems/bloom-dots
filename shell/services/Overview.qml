pragma Singleton
import QtQuick
import Quickshell
import "../modules/overview/overview.js" as Logic

// The workspace overview: open state, and acting on what it shows through
// the dock's Hyprland dispatch. Watches Hyprland only while open.
Singleton {
	id: root

	property bool opened: false
	readonly property var _focused: HyprState.monitors.find(m => m.focused) ?? HyprState.monitors[0] ?? null
	readonly property var monitor: root._focused ?? ({ x: 0, y: 0, width: 1920, height: 1080, scale: 1 })
	readonly property int activeWorkspace: root._focused?.activeWorkspace?.id ?? 1
	readonly property var clients: HyprState.clients.filter(c => c.mapped !== false && !c.hidden && c.monitor === (root._focused?.id ?? c.monitor))

	function show() { root.opened = true; }
	function hide() { root.opened = false; }
	function toggle() { root.opened = !root.opened; }
	onOpenedChanged: {
		HyprState.hold("overview", root.opened ? "event" : false);
		if (root.opened) HyprState.refresh();
	}

	function goToWorkspace(id) { root.hide(); Dock.switchWorkspace(id); return "ok"; }
	function goToWindow(address) { root.hide(); Dock.focusWindow(address); return "ok"; }
	// The overview stays open: the window just changes cells.
	function moveWindow(address, workspace) {
		const arg = Logic.moveArg(address, workspace);
		if (!arg) return "invalid";
		Dock.dispatchMove(arg, address);
		return "ok";
	}
}
