import QtQuick
import Quickshell
import qs.services

// Test harness for Settings, run by tests/integration/test_settings_durable.sh.
// Reads settings.json in the same instant Settings.set returns: "ok" must mean
// the value is already on disk. Exits 0 when every write was durable.
ShellRoot {
	function readNow(path) {
		const xhr = new XMLHttpRequest();
		xhr.open("GET", "file://" + path, false);
		xhr.send();
		return xhr.responseText;
	}

	Timer {
		interval: 300
		running: true
		onTriggered: {
			let durable = 0;
			const modes = ["light", "dark", "custom", "light", "dark"];
			for (const m of modes) {
				const err = Settings.set("bloom-theme-mode", m);
				let onDisk = "";
				try {
					onDisk = JSON.parse(readNow(Settings.path))["bloom-theme-mode"];
				} catch (e) {
					onDisk = "unreadable";
				}
				if (err === "" && onDisk === m)
					durable++;
				else
					console.log(`RESULT not durable: set ${m} (${err || "ok"}), disk has ${onDisk}`);
			}
			console.log(`RESULT durable=${durable}/${modes.length}`);
			Qt.exit(durable === modes.length ? 0 : 1);
		}
	}
}
