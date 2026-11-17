pragma Singleton
import QtQuick
import Quickshell
import "../modules/onboarding/onboarding.js" as Logic

// The first-run guide (docs/specs round 3, C): a fresh install writes
// onboarding.json pending; the shell opens the guide once, and closing it
// (finished, skipped or Escape) marks it completed. Replay with open().
Singleton {
	id: root

	property bool opened: false
	// The surface the guide is introducing ("island" or "dock"); its window
	// shows it even in Smart or Peek mode while this is set.
	property string reveal: ""
	readonly property bool pending: state.loaded && Logic.pending(JSON.stringify(state.value))
	property bool _offered: false

	function open() { root.opened = true; }
	function close() {
		root.opened = false;
		root.reveal = "";
		if (root.pending)
			state.save({ completed: true });
	}

	StateFile {
		id: state
		name: "onboarding"
		defaultValue: ({ completed: true })
		validate: v => v !== null && typeof v === "object" && typeof v.completed === "boolean" ? v : undefined
		maxBytes: 1024
		onLoadedChanged: {
			if (loaded && root.pending && !root._offered) {
				root._offered = true;
				root.opened = true;
			}
		}
	}
}
