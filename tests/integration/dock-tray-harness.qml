import QtQuick
import Quickshell
import qs.services
import "modules/dock"

ShellRoot {
	id: root
	property bool seen: false
	property bool passive: false
	Loader { id: source; active: true; sourceComponent: DockTraySource {} }
	Timer {
		interval: 100
		repeat: true
		running: true
		onTriggered: {
			if (!root.seen && Dock.trayEntries.length > 0) {
				console.log("RESULT tray=" + Dock.trayEntries.map(x => x.id).join(","));
				root.seen = true;
				const key = Dock.trayEntries[0].key;
				console.log("RESULT activate=" + Dock.trayActivate(key, null, 0, 0));
				console.log("RESULT secondary=" + Dock.traySecondary(key));
			} else if (root.seen && !root.passive && Dock.trayOnly.length === 0) {
				console.log("RESULT passive-hidden");
				root.passive = true;
				source.active = false;
			} else if (root.passive && Dock.trayEntries.length === 0) {
				console.log("RESULT cleared");
				let displays = [];
				const fakeMenu = { hasMenu: true, onlyMenu: true, display: (window, x, y) => displays.push(x + "," + y) };
				Dock.setTrayItems([{ key: "menu-seam", item: fakeMenu }]);
				console.log("RESULT menu=" + Dock.trayMenu("menu-seam", null, 12, 34));
				console.log("RESULT only-menu=" + Dock.trayActivate("menu-seam", null, 56, 78));
				console.log("RESULT displays=" + displays.join(";"));
				Dock.setTrayItems([]);
				Qt.exit(0);
			}
		}
	}
	Timer { interval: 8000; running: true; onTriggered: { console.log("RESULT timeout"); Qt.exit(1); } }
}
