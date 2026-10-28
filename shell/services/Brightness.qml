pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/osd/osd.js" as Logic

// Read the active backlight through brightnessctl. Created only by the OSD
// module; no process runs while that module is disabled.
Singleton {
	id: root
	property var info: null
	readonly property bool available: root.info !== null
	readonly property string device: root.info?.device ?? ""
	readonly property int percent: root.info?.percent ?? -1
	property string error: ""
	property bool _monitorOk: true
	signal levelChanged(int percent)

	function refresh() {
		if (!scan.running && !write.running) scan.running = true;
	}
	function setPercent(value) {
		if (!root.available) return "backlight unavailable";
		if (!Number.isFinite(value) || value < 0 || value > 100) return "invalid brightness";
		if (write.running) return "brightness change in progress";
		write.command = ["brightnessctl", "-m", "-d", root.device, "set", Math.round(value) + "%"];
		write.running = true;
		return "ok";
	}

	Component.onCompleted: root.refresh()
	Timer { id: eventDebounce; interval: 150; onTriggered: root.refresh() }
	Timer { id: monitorRetry; interval: 30000; onTriggered: root._monitorOk = true }
	Process {
		id: monitor
		running: root._monitorOk
		command: ["udevadm", "monitor", "--kernel", "--subsystem-match=backlight"]
		stdout: SplitParser { onRead: line => { if (line.indexOf(" change ") >= 0) eventDebounce.restart(); } }
		onExited: { root._monitorOk = false; monitorRetry.restart(); }
	}
	Process {
		id: scan
		command: ["brightnessctl", "-m", "-c", "backlight", "info"]
		stdout: StdioCollector { id: scanOut }
		onExited: code => {
			const next = code === 0 ? Logic.parseBrightness(scanOut.text) : null;
			if (!next) { root.info = null; return; }
			const old = root.percent;
			root.info = next;
			if (old >= 0 && old !== next.percent) root.levelChanged(next.percent);
		}
	}
	Process {
		id: write
		onExited: code => {
			root.error = code !== 0 ? "Couldn't change brightness" : "";
			root.refresh();
		}
	}
}
