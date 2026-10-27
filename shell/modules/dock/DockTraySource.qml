import QtQuick
import Quickshell.Services.SystemTray
import qs.services

// This adapter exists only while the `tray` module is enabled. It keeps Qt
// handles out of the pure matching rules and clears them on teardown.
Item {
	id: root
	visible: false
	property int serial: 0
	property var _seen: []
	readonly property var snapshot: SystemTray.items.values.map(item => ({
		item: item, id: item.id, title: item.title, icon: item.icon,
		status: item.status, category: item.category, onlyMenu: item.onlyMenu, hasMenu: item.hasMenu
	}))

	function sync() {
		const previous = root._seen;
		const next = root.snapshot.map(p => {
			const old = previous.find(x => x.item === p.item);
			return Object.assign({ key: old ? old.key : "sni-" + (++root.serial) }, p);
		});
		root._seen = next;
		Dock.setTrayItems(next);
	}
	onSnapshotChanged: root.sync()
	Component.onCompleted: root.sync()
	Component.onDestruction: Dock.setTrayItems([])
}
