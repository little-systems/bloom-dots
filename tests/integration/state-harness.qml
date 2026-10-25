import QtQuick
import Quickshell
import qs.services

// Test harness for StateFile, run by tests/integration/test_state.sh.
// Prints RESULT lines and exits 0 on success. Qt.exit only works once the
// config has loaded, hence the timers.
ShellRoot {
	id: root

	StateFile {
		id: corrupt
		name: "corrupt"
		defaultValue: ({ items: [] })
	}

	StateFile {
		id: fresh
		name: "fresh"
		defaultValue: []
	}

	Timer {
		interval: 300
		running: true
		onTriggered: {
			const okCorrupt = corrupt.loaded && JSON.stringify(corrupt.value) === JSON.stringify({ items: [] });
			const okFresh = fresh.loaded && JSON.stringify(fresh.value) === "[]";
			console.log(`RESULT corrupt-uses-default=${okCorrupt} missing-uses-default=${okFresh}`);
			fresh.save(["a", "b"]);
			finish.restart();
			if (!okCorrupt || !okFresh)
				Qt.exit(1);
		}
	}

	Timer {
		id: finish
		interval: 300
		onTriggered: Qt.exit(0)
	}
}
