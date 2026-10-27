import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
	property int phase: 0
	FileView { id: marker; path: Quickshell.env("BLOOM_TEST_DRIVE_MARKER"); blockWrites: true }
	Timer {
		interval: 100
		repeat: true
		running: true
		onTriggered: {
			const items = DockExtras.items;
			if (phase === 0 && items.some(x => x.key === "drive:USB") && items.some(x => x.kind === "folder")) {
				console.log("RESULT items=" + items.map(x => x.key).join(","));
				console.log("RESULT missing=" + DockExtras.action("drive:missing", "open"));
				console.log("RESULT no-confirm=" + DockExtras.emptyTrash(false));
				marker.setText("drive removed");
				console.log("RESULT stale=" + DockExtras.action("drive:STALE", "open"));
				phase = 1;
			} else if (phase === 1 && !DockExtras.busy) {
				console.log("RESULT stale-toast=" + DockExtras.toast);
				console.log("RESULT open=" + DockExtras.action("drive:USB", "open"));
				phase = 2;
			} else if (phase === 2 && !DockExtras.busy) {
				console.log("RESULT mount=" + DockExtras.action("drive:USB2", "open"));
				phase = 3;
			} else if (phase === 3 && !DockExtras.busy) {
				console.log("RESULT eject=" + DockExtras.action("drive:USB", "eject"));
				phase = 4;
			} else if (phase === 4 && !DockExtras.busy) {
				console.log("RESULT empty=" + DockExtras.emptyTrash(true));
				phase = 5;
			} else if (phase === 5 && !DockExtras.busy) {
				console.log("RESULT done");
				Qt.exit(0);
			}
		}
	}
	Timer { interval: 7000; running: true; onTriggered: { console.log("RESULT timeout"); Qt.exit(1); } }
}
