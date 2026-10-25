pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland windows and monitors (hyprctl -j) for features that react to them,
// like the smart notch. Refreshes only while something holds the service: on
// Hyprland events, and once a second because moving a floating window sends
// no event. Outside Hyprland it stays empty and quiet.
Singleton {
	id: root

	readonly property bool available: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "") !== ""
	property var clients: []
	property var monitors: []

	property var _holders: ({})
	readonly property bool active: root.available && Object.keys(root._holders).length > 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
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

	onActiveChanged: if (root.active) root.refresh()

	Timer {
		interval: 1000
		repeat: true
		running: root.active
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
		active: root.active
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
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.clients = JSON.parse(text);
				} catch (e) {
					console.warn("bloom hypr: could not read clients");
				}
			}
		}
	}

	Process {
		id: monitorsProc
		command: ["hyprctl", "-j", "monitors"]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					root.monitors = JSON.parse(text);
				} catch (e) {
					console.warn("bloom hypr: could not read monitors");
				}
			}
		}
	}
}
