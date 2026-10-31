import QtQuick
import Quickshell
import qs.services

ShellRoot {
	readonly property var _dock: Dock
	property var expected: ["class:second", "class:first"]
	Timer {
		interval: 300; running: true
		onTriggered: {
			HyprState.clients = [
				{ class: "first", address: "0x1", title: "First", mapped: true, hidden: false },
				{ class: "second", address: "0x2", title: "Second", mapped: true, hidden: false }
			];
			if (Quickshell.env("BLOOM_DOCK_ORDER_CHECK") !== "1") {
				const result = Dock.reorderRunning(expected);
				if (result !== "ok") { console.log(result); Qt.exit(1); return; }
			}
			check.restart();
		}
	}
	Timer {
		id: check; interval: 150
		onTriggered: {
			const got = Dock.items.unpinned.map(i => i.id);
			const same = JSON.stringify(got) === JSON.stringify(expected);
			console.log("RESULT dock-order=" + JSON.stringify(got));
			Qt.exit(same ? 0 : 1);
		}
	}
}
