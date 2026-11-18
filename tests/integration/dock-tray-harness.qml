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
			const first = Dock.trayEntries[0];
			if (!root.seen && first && Dock.trayOwners.length > 0 && first.menu.length > 0) {
				console.log("RESULT tray=" + Dock.trayEntries.map(x => x.id).join(","));
				root.seen = true;
				const key = first.key;
				console.log("RESULT owner=" + (Dock.trayOwners[0].pid > 0 && Dock.trayOwners[0].service.indexOf("BloomTest") >= 0));
				const target = Dock.menuTarget("tray:" + key);
				console.log("RESULT entries=" + target.entries.map(e => e.separator ? "|" : e.text + (e.enabled ? "" : "(off)")).join(","));
				console.log("RESULT unobserved-hidden=" + (Dock.trayOnly.length === 0));
				console.log("RESULT activate=" + Dock.trayActivate(key, null, 0, 0));
				console.log("RESULT secondary=" + Dock.traySecondary(key));
				console.log("RESULT entry=" + Dock.trayMenuEntry(key, 0));
			} else if (root.seen && !root.passive && (first?.status === "Passive" || first?.status === 0)) {
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
