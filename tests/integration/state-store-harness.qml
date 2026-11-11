import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// External edits, schema checks, byte budgets and backup retention for
// StateFile, run by tests/integration/test_state.sh. Prints RESULT lines.
ShellRoot {
	id: root

	property int externalSignals: 0
	property string phase: ""

	StateFile {
		id: watched
		name: "watched"
		defaultValue: ({ n: 0 })
		onExternallyChanged: root.externalSignals++
	}

	StateFile {
		id: shaped
		name: "shaped"
		defaultValue: ({ items: [] })
		validate: v => Array.isArray(v?.items) ? v : undefined
	}

	StateFile {
		id: big
		name: "big"
		defaultValue: ({})
		maxBytes: 64
	}

	StateFile {
		id: budget
		name: "budget"
		defaultValue: ({})
		maxBytes: 64
	}

	StateFile {
		id: pruned
		name: "pruned"
		defaultValue: ({})
	}

	Process {
		id: editor
		// Another program replaces the file while Bloom is running.
		command: ["sh", "-c", "printf '{\"n\": 2}\\n' > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"", "sh", watched.path]
		onExited: afterEdit.start()
	}

	Timer {
		interval: 400
		running: true
		onTriggered: {
			const okLoaded = watched.loaded && watched.value.n === 1;
			const okShape = shaped.loaded && JSON.stringify(shaped.value) === JSON.stringify({ items: [] }) && shaped.errorKind === "invalid";
			const okBig = big.loaded && JSON.stringify(big.value) === "{}" && big.errorKind === "too-large";
			const okBudget = budget.save({ text: "x".repeat(100) }) === false && budget.errorKind === "too-large"
				&& budget.value.small === 1;
			console.log(`RESULT watched-loaded=${okLoaded} invalid-shape-uses-default=${okShape} oversized-file-uses-default=${okBig} oversized-save-refused=${okBudget}`);
			watched.save({ n: 1, own: true });
			ownWrite.start();
		}
	}

	Timer {
		id: ownWrite
		interval: 400
		onTriggered: {
			console.log(`RESULT own-write-not-external=${root.externalSignals === 0}`);
			editor.running = true;
		}
	}

	Timer {
		id: afterEdit
		interval: 600
		onTriggered: {
			const ok = watched.value.n === 2 && root.externalSignals === 1;
			console.log(`RESULT external-edit-adopted=${ok}`);
			watched.save({ n: 3 });
			finish.start();
		}
	}

	Timer {
		id: finish
		interval: 400
		onTriggered: Qt.exit(0)
	}
}
