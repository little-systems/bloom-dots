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

	// Saves as soon as a corrupt file has loaded, racing the .bak move.
	StateFile {
		id: racy
		name: "racy"
		defaultValue: []
		onLoadedChanged: if (loaded) save(["saved"])
	}

	// Saves before the existing file has loaded; the save must win.
	StateFile {
		id: early
		name: "early"
		defaultValue: ({})
		Component.onCompleted: save({ fresh: 1 })
	}

	Timer {
		interval: 300
		running: true
		onTriggered: {
			const okCorrupt = corrupt.loaded && JSON.stringify(corrupt.value) === JSON.stringify({ items: [] });
			const okFresh = fresh.loaded && JSON.stringify(fresh.value) === "[]";
			const okEarly = early.loaded && JSON.stringify(early.value) === JSON.stringify({ fresh: 1 });
			console.log(`RESULT corrupt-uses-default=${okCorrupt} missing-uses-default=${okFresh} early-save-wins=${okEarly}`);
			fresh.save(["a", "b"]);
			finish.restart();
			if (!okCorrupt || !okFresh || !okEarly)
				Qt.exit(1);
		}
	}

	Timer {
		id: finish
		interval: 300
		onTriggered: Qt.exit(0)
	}
}
