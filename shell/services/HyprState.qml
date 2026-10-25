pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland windows and monitors (hyprctl -j) for features that react to them:
// the smart notch's overlap and every notch's fullscreen check. A holder asks
// for "events" (refresh on Hyprland events, no polling) or "poll" (also once
// a second, because moving a floating window sends no event). Outside
// Hyprland it stays empty; if hyprctl stops answering (a stale signature
// after Hyprland restarts) it warns once and retries quietly every 30 s.
Singleton {
	id: root

	readonly property bool available: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""
	property var clients: []
	property var monitors: []

	// key -> "poll" | "events"
	property var _holders: ({})
	property bool _failing: false
	property bool _warned: false
	readonly property bool active: root.available && Object.keys(root._holders).length > 0
	readonly property bool _polling: root.active && Object.keys(root._holders).some(k => root._holders[k] === "poll")

	// `need` is "poll", "events", or "" to release.
	function hold(key, need) {
		const next = Object.assign({}, root._holders);
		if (need)
			next[key] = need;
		else
			delete next[key];
		root._holders = next;
	}

	function refresh() {
		if (!clientsProc.running)
			clientsProc.running = true;
		if (!monitorsProc.running)
			monitorsProc.running = true;
	}

	function _ok() {
		root._failing = false;
		root._warned = false;
	}

	function _fail() {
		if (!root._warned)
			console.warn("bloom hypr: hyprctl is not answering; treating windows as not overlapping and retrying every 30 s");
		root._warned = true;
		root._failing = true;
		root.clients = [];
		root.monitors = [];
	}

	onActiveChanged: if (root.active) root.refresh()

	Timer {
		interval: root._failing ? 30000 : 1000
		repeat: true
		running: root._failing ? root.active : root._polling
		onTriggered: root.refresh()
	}

	Timer {
		id: soon
		interval: 100
		onTriggered: root.refresh()
	}

	// Hyprland events, only while held (see HyprEvents.qml for why it's separate).
	Loader {
		id: events
		active: root.active && !root._failing
		source: "HyprEvents.qml"
	}

	Connections {
		target: events.item
		ignoreUnknownSignals: true
		function onChanged() { soon.restart(); }
	}

	Process {
		id: clientsProc
		command: ["hyprctl", "-j", "clients"]
		onExited: code => { if (code !== 0) root._fail(); }
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.clients = JSON.parse(text);
					root._ok();
				} catch (e) {
					root._fail();
				}
			}
		}
	}

	Process {
		id: monitorsProc
		command: ["hyprctl", "-j", "monitors"]
		onExited: code => { if (code !== 0) root._fail(); }
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.monitors = JSON.parse(text);
				} catch (e) {
					root._fail();
				}
			}
		}
	}
}
