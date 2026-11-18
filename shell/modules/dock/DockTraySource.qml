import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.services

// This adapter exists only while the `tray` module is enabled. It keeps Qt
// handles out of the pure matching rules and clears them on teardown. Each
// item's menu is opened here so its entries can be listed as "App options".
Item {
	id: root
	visible: false
	property int serial: 0
	property var _seen: []
	Instantiator {
		id: menus
		model: SystemTray.items
		delegate: QsMenuOpener {
			required property var modelData
			menu: modelData.menu
		}
	}
	readonly property var snapshot: {
		const openers = [];
		for (let i = 0; i < menus.count; i++)
			openers.push(menus.objectAt(i));
		return SystemTray.items.values.map(item => {
			const opener = openers.find(o => o && o.modelData === item);
			return {
				item: item, id: item.id, title: item.title, icon: item.icon,
				status: item.status, category: item.category, onlyMenu: item.onlyMenu, hasMenu: item.hasMenu,
				menu: opener && item.hasMenu ? Array.from(opener.children.values) : []
			};
		});
	}

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
