pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "media.js" as Logic

// Five visualizer levels from cava (PipeWire input), only while something
// holds the service and media is playing. `available` is false without cava,
// and the notch then draws no visualizer at all.
Singleton {
	id: root

	readonly property var idle: [0.18, 0.18, 0.18, 0.18, 0.18]
	property var levels: root.idle
	property bool available: false
	property var _holders: ({})
	readonly property bool _running: root.available && Object.keys(root._holders).length > 0 && Media.isPlaying

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	on_RunningChanged: if (!root._running) root.levels = root.idle

	Process {
		running: true
		command: ["sh", "-c", "command -v cava"]
		onExited: code => root.available = code === 0
	}

	Process {
		running: root._running
		command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]
		stdout: SplitParser {
			onRead: line => {
				const v = Logic.parseCava(line);
				if (v)
					root.levels = v;
			}
		}
	}
}
