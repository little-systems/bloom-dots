pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dock/dock.js" as Logic
import "../modules/dock/tray.js" as Tray
import "../common/paths.js" as Paths

// The dock's apps (Bloom Dock.tsx): pins from $XDG_STATE_HOME/bloom/dock.json
// and the running windows Hyprland reports, grouped by app. Every screen's
// dock shows the same items (spec D8).
Singleton {
	id: root

	readonly property var pinned: Logic.pinsOf(pins.value)
	readonly property var icons: Logic.iconsOf(pins.value)
	property string toast: ""
	property int toastSerial: 0
	readonly property string _iconDir: Paths.stateDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME")) + "/dock-icons"
	property var _order: []
	property var trayEntries: []
	readonly property var traySelection: {
		Apps.revision;
		const projections = root.trayEntries.map(e => ({ key: e.key, id: e.id, title: e.title,
			icon: e.icon, status: e.status, category: e.category, onlyMenu: e.onlyMenu, hasMenu: e.hasMenu }));
		return Tray.selectTray(projections, Apps.desktopIdentities(), root.groups.map(g => g.id), root.pinned);
	}
	readonly property var trayOnly: root.traySelection.separate
	function setTrayItems(entries) { root.trayEntries = entries || []; }
	readonly property var groups: Logic.groupWindows(HyprState.clients, cls => Logic.identity(cls, root._idFor(cls)))
	readonly property var items: {
		Apps.revision; // re-resolve names and icons as desktop entries load
		const built = Logic.buildItems(root.pinned, root.groups, root._order,
			id => Object.assign(Apps.info(id), root.icons[id] ? { icon: "file://" + root.icons[id] } : {}));
		for (const item of built.pinned.concat(built.unpinned))
			item.hasTray = !!root.traySelection.merged[item.id]?.length;
		return built;
	}

	function _idFor(cls) {
		Apps.revision;
		return Apps.idForClass(cls);
	}

	onGroupsChanged: {
		const remembered = Logic.orderOf(pins.value);
		const next = Logic.nextOrder(remembered.concat(root._order.filter(id => !remembered.includes(id))), root.groups.map(g => g.id));
		if (JSON.stringify(next) !== JSON.stringify(root._order))
			root._order = next;
	}

	function pin(id) {
		if (root.pinned.indexOf(id) >= 0)
			return "already pinned";
		if (!Apps.exists(id))
			return "unknown app";
		root._save(root.pinned.concat([id]), root.icons);
		return "ok";
	}

	function unpin(id) {
		if (root.pinned.indexOf(id) < 0)
			return "not pinned";
		const icons = Object.assign({}, root.icons);
		const path = icons[id];
		delete icons[id];
		root._save(root.pinned.filter(p => p !== id), icons);
		root._removeCopy(path);
		return "ok";
	}

	function _save(pinned, icons) {
		pins.save(Object.assign({}, pins.value, { pinned: pinned, icons: icons }));
	}

	function _toast(message) {
		root.toast = message;
		root.toastSerial++;
	}
	function notify(message) { root._toast(message); }

	function reorder(ids) {
		const same = Array.isArray(ids) && ids.length === root.pinned.length
			&& ids.every(id => root.pinned.indexOf(id) >= 0)
			&& new Set(ids).size === ids.length;
		if (!same)
			return "order must list the pinned apps";
		root._save(ids, root.icons);
		return "ok";
	}

	function reorderRunning(ids) {
		const current = root.items.unpinned.map(i => i.id);
		if (!Array.isArray(ids) || ids.length !== current.length || new Set(ids).size !== ids.length || ids.some(id => !current.includes(id)))
			return "order must list the running apps";
		const remembered = Logic.orderOf(pins.value).filter(id => !ids.includes(id));
		pins.save(Object.assign({}, pins.value, { order: ids.concat(remembered) }));
		return "ok";
	}
	function pinAt(id, index) {
		if (!Apps.exists(id)) { root.notify("This app has no desktop entry to pin"); return "unknown app"; }
		const next = root.pinned.filter(p => p !== id);
		next.splice(Math.max(0, Math.min(next.length, index)), 0, id);
		root._save(next, root.icons);
		return "ok";
	}

	function setIcon(id, path) {
		if (root.pinned.indexOf(id) < 0)
			return "not pinned";
		const file = Logic.iconFile(id, path);
		if (!file)
			return "unsupported type";
		const tagged = Logic.iconFile(id, path, Date.now().toString(36));
		iconCopy.target = { id: id, dest: root._iconDir + "/" + tagged };
		iconCopy.command = ["sh", "-c", 'mkdir -p "$1" && cp -f -- "$2" "$3"', "sh", root._iconDir, path, iconCopy.target.dest];
		iconCopy.running = true;
		return "ok";
	}

	function resetIcon(id) {
		const path = root.icons[id];
		if (!path)
			return "no custom icon";
		const icons = Object.assign({}, root.icons);
		delete icons[id];
		root._save(root.pinned, icons);
		root._removeCopy(path);
		return "ok";
	}

	// Only Bloom's own copies are ever deleted (dock.json can be hand-edited).
	function _removeCopy(path) {
		if (!Logic.ownsIconPath(root._iconDir, path))
			return;
		const rm = rmComponent.createObject(root, { command: ["rm", "-f", "--", path] });
		rm.running = true;
	}

	function pickIcon(id) {
		if (picker.running)
			return;
		picker.forId = id;
		picker.running = true;
	}

	function _item(id) {
		return root.items.pinned.concat(root.items.unpinned).find(i => i.id === id) ?? null;
	}

	function activate(id) {
		const item = root._item(id);
		if (!item)
			return "no such app";
		const action = Logic.clickAction(item, Logic.activeAddress(HyprState.clients, HyprState.monitors));
		if (action.kind === "launch")
			return Apps.launch(id) ? "ok" : "cannot launch";
		if (action.kind === "focus")
			root._dispatch(Logic.focusArg(action.address), action.address);
		return "ok";
	}

	function newInstance(id) {
		return Apps.launch(id) ? "ok" : "cannot launch";
	}

	function activateSlot(n) {
		const item = root.items.pinned[n - 1];
		return item ? root.activate(item.id) : `no app in slot ${n}`;
	}

	function closeWindows(id) {
		const item = root._item(id);
		for (const w of item ? item.windows : [])
			root._dispatch('hl.dsp.window.close({ window = "address:' + w.address + '" })', w.address);
	}

	function focusWindow(address) {
		if (!root.groups.some(g => g.windows.some(w => w.address === address))) return "no such window";
		root._dispatch(Logic.focusArg(address), address);
		return "ok";
	}

	function closeWindow(address) {
		if (!root.groups.some(g => g.windows.some(w => w.address === address))) return "no such window";
		root._dispatch('hl.dsp.window.close({ window = "address:' + address + '" })', address);
		return "ok";
	}

	// The overview's window moves, through the same queue.
	function dispatchMove(arg, address) { root._dispatch(arg, address); }

	function switchWorkspace(wsId) {
		if (wsId > 0)
			root._dispatch("hl.dsp.focus({ workspace = " + Math.floor(wsId) + " })", "0x0");
	}

	function switchWorkspaceNamed(name) {
		if (/^[A-Za-z0-9 _.-]+$/.test(name))
			root._dispatch('hl.dsp.focus({ workspace = "name:' + name + '" })', "0x0");
	}

	function stepWorkspace(dir, cells) {
		const i = cells.findIndex(c => c.active);
		const next = cells[Math.max(0, Math.min(cells.length - 1, i + dir))];
		if (next && !next.active)
			next.id > 0 ? root.switchWorkspace(next.id) : root.switchWorkspaceNamed(next.tip);
	}

	// Shows the dock for `ms` (the Command Center's System Tray button: tray
	// apps live in the dock here).
	signal revealRequested(int ms)
	function reveal(ms) { root.revealRequested(ms); }

	function restartShell() { Apps.run(["systemctl", "--user", "restart", "bloom-shell"], "bloom-restart"); }
	function quitShell() { Apps.run(["systemctl", "--user", "stop", "bloom-shell"], "bloom-quit"); }

	function menuTarget(id) {
		if (id.startsWith("tray:")) {
			const key = id.slice(5);
			const entry = root.trayEntries.find(e => e.key === key);
			return { kind: "tray", trayKey: key, hasMenu: !!entry?.hasMenu };
		}
		const item = root._item(id);
		return {
			kind: "app", id: id, pinned: root.pinned.indexOf(id) >= 0, pinnable: Apps.exists(id),
			running: !!item && item.windows.length > 0, windows: item ? item.windows.length : 0,
			hasCustomIcon: !!root.icons[id], actions: Apps.actions(id),
			trays: root.traySelection.merged[id] || []
		};
	}

	function _trayItem(key) { return root.trayEntries.find(e => e.key === key)?.item || null; }
	function trayActivate(key, window, x, y) {
		const item = root._trayItem(key);
		if (!item) return "tray item gone";
		if (item.onlyMenu && item.hasMenu) item.display(window, x, y);
		else item.activate();
		return "ok";
	}
	function traySecondary(key) {
		const item = root._trayItem(key);
		if (!item) return "tray item gone";
		item.secondaryActivate();
		return "ok";
	}
	function trayMenu(key, window, x, y) {
		const item = root._trayItem(key);
		if (!item || !item.hasMenu) return "no tray menu";
		item.display(window, x, y);
		return "ok";
	}

	function runMenu(id, key) {
		if (key === "pin") root.pin(id);
		else if (key === "unpin") root.unpin(id);
		else if (key === "change-icon") root.pickIcon(id);
		else if (key === "reset-icon") root.resetIcon(id);
		else if (key === "new-window") root.newInstance(id);
		else if (key === "close") root.closeWindows(id);
		else if (key === "restart") root.restartShell();
		else if (key === "quit") root.quitShell();
		else if (key.startsWith("action:")) Apps.runAction(id, parseInt(key.slice(7)));
	}

	property var _queue: []
	function _dispatch(arg, address) {
		if (!/^0x[0-9a-f]+$/.test(address) || !arg)
			return;
		root._queue = root._queue.concat([arg]);
		if (!dispatcher.running)
			root._next();
	}
	function _next() {
		if (root._queue.length === 0)
			return;
		dispatcher.command = ["hyprctl", "dispatch", root._queue[0]];
		root._queue = root._queue.slice(1);
		dispatcher.running = true;
	}

	Process { id: dispatcher; onExited: root._next() }
	Process {
		id: iconCopy
		property var target: null
		onExited: code => {
			if (code !== 0 || !root.pinned.includes(iconCopy.target.id)) {
				root._toast("Couldn't use that image");
				root._removeCopy(iconCopy.target.dest);
				return;
			}
			// Saved only once Qt can load it; a broken file keeps the old icon.
			iconProbe.target = iconCopy.target;
			iconProbe.source = "file://" + iconCopy.target.dest;
		}
	}

	Image {
		id: iconProbe
		property var target: null
		visible: false
		asynchronous: true
		cache: false
		sourceSize: Qt.size(64, 64)
		onStatusChanged: {
			const t = iconProbe.target;
			// Read before clearing: clearing the source resets the status to Null.
			const status = iconProbe.status;
			if (!t || status === Image.Loading || status === Image.Null)
				return;
			iconProbe.target = null;
			iconProbe.source = "";
			if (status === Image.Error || !root.pinned.includes(t.id)) {
				root._toast("Couldn't use that image");
				root._removeCopy(t.dest);
				return;
			}
			const icons = Object.assign({}, root.icons);
			const previous = icons[t.id];
			icons[t.id] = t.dest;
			root._save(root.pinned, icons);
			if (previous && previous !== t.dest)
				root._removeCopy(previous);
		}
	}

	Component {
		id: rmComponent
		Process { onExited: destroy() }
	}
	Process {
		id: picker
		property string forId: ""
		command: ["sh", "-c", Logic.pickerScript]
		stdout: StdioCollector { id: picked }
		onExited: code => {
			if (code === 127) root._toast("Install kdialog or zenity to choose icons");
			else if (code === 0 && picked.text.trim() !== "") {
				const r = root.setIcon(picker.forId, picked.text.trim());
				if (r === "unsupported type") root._toast("Couldn't use that image");
			}
		}
	}

	StateFile {
		id: pins
		name: "dock"
		defaultValue: ({ pinned: [], order: [] })
		onValueChanged: root._order = Logic.nextOrder(Logic.orderOf(pins.value), root.groups.map(g => g.id))
	}
}
