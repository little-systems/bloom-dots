pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../common/i18n"
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

	function open() {
		root._sampleSent = false;
		root.opened = true;
	}

	// Owner: the notifications page posts one real notification, so the corner
	// has something to show; once per tour, however often the page is shown.
	property bool _sampleSent: false
	function pageShown(kind) {
		if (kind !== "notifications" || root._sampleSent) return;
		root._sampleSent = true;
		sample.command = ["timeout", "-k", "1s", "5s", "notify-send", "-a", "Bloom",
			I18n.t("linux.onboarding.sampleTitle"), I18n.t("linux.onboarding.sampleBody")];
		sample.running = true;
	}
	Process { id: sample }
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
	}

	// Offered once per shell start, however early the state file loads.
	function _offer() {
		if (root.pending && !root._offered) {
			root._offered = true;
			root.opened = true;
		}
	}
	onPendingChanged: root._offer()
	Component.onCompleted: root._offer()
}
