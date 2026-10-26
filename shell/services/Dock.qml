pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dock/dock.js" as Logic

// The dock's apps (Bloom Dock.tsx): pins from $XDG_STATE_HOME/bloom/dock.json
// and the running windows Hyprland reports, grouped by app. Every screen's
// dock shows the same items (spec D8).
Singleton {
	id: root

	readonly property var pinned: pins.value.pinned ?? []
	property var _order: []
	readonly property var groups: Logic.groupWindows(HyprState.clients, cls => Logic.identity(cls, root._idFor(cls)))
	readonly property var items: {
		Apps.revision; // re-resolve names and icons as desktop entries load
		return Logic.buildItems(root.pinned, root.groups, root._order, id => Apps.info(id));
	}

	function _idFor(cls) {
		Apps.revision;
		return Apps.idForClass(cls);
	}

	onGroupsChanged: {
		const next = Logic.nextOrder(root._order, root.groups.map(g => g.id));
		if (JSON.stringify(next) !== JSON.stringify(root._order))
			root._order = next;
	}

	function pin(id) {
		if (root.pinned.indexOf(id) >= 0)
			return "already pinned";
		if (!Apps.exists(id))
			return "unknown app";
		pins.save({ pinned: root.pinned.concat([id]) });
		return "ok";
	}

	function unpin(id) {
		if (root.pinned.indexOf(id) < 0)
			return "not pinned";
		pins.save({ pinned: root.pinned.filter(p => p !== id) });
		return "ok";
	}

	function _item(id) {
		return root.items.pinned.concat(root.items.unpinned).find(i => i.id === id) ?? null;
	}

	function activate(id) {
		const item = root._item(id);
		if (!item)
			return "no such app";
		const active = HyprState.clients.reduce((best, c) => best === null || c.focusHistoryID < best.focusHistoryID ? c : best, null);
		const action = Logic.clickAction(item, active ? active.address : "");
		if (action.kind === "launch")
			return Apps.launch(id) ? "ok" : "cannot launch";
		if (action.kind === "focus")
			root._focus(action.address);
		return "ok";
	}

	function newInstance(id) {
		return Apps.launch(id) ? "ok" : "cannot launch";
	}

	function activateSlot(n) {
		const item = root.items.pinned[n - 1];
		return item ? root.activate(item.id) : `no app in slot ${n}`;
	}

	function _focus(address) {
		const arg = Logic.focusArg(address);
		if (!arg || focusProc.running)
			return;
		focusProc.command = ["hyprctl", "dispatch", arg];
		focusProc.running = true;
	}

	Process { id: focusProc }

	StateFile {
		id: pins
		name: "dock"
		defaultValue: ({ pinned: [] })
	}
}
