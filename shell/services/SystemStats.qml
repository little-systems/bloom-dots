pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "stats.js" as Logic

// CPU, RAM, free disk and network speed for the status widgets. Read every
// 3 s as Bloom does, but only while something holds the service (a status
// strip showing a stats widget), so a hidden widget costs nothing.
Singleton {
	id: root

	property int cpu: 0
	property real ram: 0
	property int disk: 0
	property int up: 0
	property int down: 0

	property var _holders: ({})
	readonly property bool active: Object.keys(root._holders).length > 0
	property var _prev: null
	property real _prevAt: 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	function _sample() {
		if (!proc.running)
			proc.running = true;
	}

	// Deltas across a pause would average the whole pause, so start fresh.
	onActiveChanged: if (!active) root._prev = null

	Timer {
		interval: 3000
		repeat: true
		triggeredOnStart: true
		running: root.active
		onTriggered: root._sample()
	}

	// CPU and network need two samples; take the second one soon after the
	// first instead of showing 0 for 3 s.
	Timer {
		id: followUp
		interval: 500
		onTriggered: root._sample()
	}

	Process {
		id: proc
		command: ["sh", "-c", "cat /proc/stat; echo ---; cat /proc/meminfo; echo ---; cat /proc/net/dev; echo ---; df -B1 --output=avail / | tail -n 1"]
		stdout: StdioCollector {
			onStreamFinished: {
				const cur = Logic.parse(text);
				if (!cur) {
					console.warn("bloom stats: could not read system counters");
					return;
				}
				const now = Date.now();
				const first = root._prev === null;
				root.cpu = Logic.cpuPercent(first ? null : root._prev.cpu, cur.cpu);
				root.ram = Logic.ramPercent(cur.mem);
				root.disk = Logic.diskGB(cur.diskAvail);
				const speed = Logic.netSpeed(first ? null : root._prev.net, cur.net, (now - root._prevAt) / 1000);
				root.up = speed[0];
				root.down = speed[1];
				root._prev = cur;
				root._prevAt = now;
				if (first && root.active)
					followUp.restart();
			}
		}
	}
}
