import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.services
import "system.js" as Sys

// What the system pages read and change. Only this file runs system tools, so
// the pages stay pure and the tests can stand in for it. Anything that needs
// root goes through the tool's own polkit prompt; nothing here takes a password.
Scope {
	id: root

	property var monitors: []
	property var disks: []
	property string hostname: ""
	property string kernel: ""
	property string cpu: ""
	property string memory: ""
	property string timezone: ""
	property bool ntp: false
	property int updates: -1
	property var defaults: ({})
	property var hypr: ({})
	property var hyprLive: ({})
	property var pendingDisplay: null
	// Only what was read back counts: false until the first read says otherwise.
	property bool hyprLoaded: false
	property bool autostart: false
	property bool autostartLoaded: false
	property string lastError: ""
	property var _checks: []
	property var _queue: []
	property int pendingSeconds: 0
	property var _monitorLines: []

	readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
	readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
	readonly property string sink: Pipewire.defaultAudioSink?.name ?? ""
	readonly property string source: Pipewire.defaultAudioSource?.name ?? ""
	readonly property real volume: Audio.volume
	readonly property var mixer: Audio.mixerRows
	readonly property bool brightnessAvailable: Brightness.available
	readonly property real brightness: Brightness.percent / 100
	readonly property string powerMode: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
		: PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"
	readonly property bool batteryAvailable: Battery.available
	readonly property int batteryLevel: Battery.level

	readonly property string _hyprPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/custom/bloom-settings.lua"
	readonly property string _hyprState: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/bloom/hypr-settings.json"

	function refresh() {
		for (const p of [monitorsProc, disksProc, infoProc, timeProc, updatesProc, optionsProc]) p.running = true;
		root._loadDefaults();
	}
	function setVolume(v) { Audio.setVolume(v); }
	function setBrightness(v) { Brightness.setPercent(v * 100); }
	function setSink(name) { Pipewire.preferredDefaultAudioSink = root.sinks.find(n => n.name === name) ?? null; }
	function setSource(name) { Pipewire.preferredDefaultAudioSource = root.sources.find(n => n.name === name) ?? null; }
	function setPowerMode(mode) {
		PowerProfiles.profile = mode === "power-saver" ? PowerProfile.PowerSaver : mode === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
	}
	// The switch only moves when the read-back says so.
	function setNtp(on) {
		root._run(["timedatectl", "set-ntp", on ? "true" : "false"], "Couldn't change automatic time", () => { timeProc.running = true; });
	}
	function setAutostart(on) {
		root._run(["systemctl", "--user", on ? "enable" : "disable", "bloom-shell"], "Couldn't change Launch at Login", () => { autostartProc.running = true; });
	}
	function clearError() { root.lastError = ""; }
	// One at a time, in order, so a failure belongs to the change that caused it.
	function _run(argv, failure, after) {
		root._queue = root._queue.concat([{ argv: argv, failure: failure, after: after }]);
		root._next();
	}
	function _next() {
		if (actionProc.running || root._queue.length === 0) return;
		actionProc.job = root._queue[0];
		root._queue = root._queue.slice(1);
		actionProc.command = actionProc.job.argv;
		actionProc.running = true;
	}
	function runUpdates() { Quickshell.execDetached(["kitty", "-e", "sudo", "pacman", "-Syu"]); }
	// Shown at once for the slider's sake, kept only if Hyprland reads it back.
	function setHypr(path, value) {
		root.hypr = Sys.withOption(root.hypr, path, value);
		root._checks = root._checks.filter(c => c.path !== path).concat([{ path: path, value: value }]);
		Quickshell.execDetached(["hyprctl", "eval", Sys.hyprConfig(Sys.withOption({}, path, value))]);
		verifyTimer.restart();
	}
	function _settle() {
		const failed = root._checks.filter(c => !Sys.sameValue(root.hyprLive[c.path], c.value));
		root._checks = [];
		if (failed.length) {
			failed.forEach(c => { root.hypr = Sys.withoutOption(root.hypr, c.path); });
			root.lastError = "Hyprland didn't accept that change: " + failed.map(c => c.path).join(", ");
		}
		root._save();
	}
	// Tried first, saved only on Keep: an unusable mode reverts by itself.
	function setMonitor(monitor, mode, scale) {
		if (root.pendingDisplay === null) {
			root.pendingDisplay = { name: monitor.name, line: Sys.monitorLine(monitor, Sys.currentMode(monitor), monitor.scale) };
		}
		const line = Sys.monitorLine(monitor, mode, scale);
		root.pendingDisplay = Object.assign({}, root.pendingDisplay, { next: line, mode: mode, scale: Number(scale) });
		root.pendingSeconds = 15;
		pendingTimer.restart();
		Quickshell.execDetached(["hyprctl", "eval", line]);
		displayCheck.restart();
	}
	function keepDisplay() {
		const pending = root.pendingDisplay;
		pendingTimer.stop();
		root.pendingDisplay = null;
		root._monitorLines = root._monitorLines.filter(l => l.indexOf('"' + pending.name + '"') < 0).concat([pending.next]);
		root._save();
	}
	function revertDisplay() {
		const pending = root.pendingDisplay;
		pendingTimer.stop();
		root.pendingDisplay = null;
		Quickshell.execDetached(["hyprctl", "eval", pending.line]);
		monitorsProc.running = true;
	}
	function _save() {
		const state = JSON.stringify({ hypr: root.hypr, monitors: root._monitorLines });
		Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" "$(dirname "$3")" && printf %s "$2" > "$1" && printf %s "$4" > "$3"', "sh",
			root._hyprPath, Sys.hyprFile(root.hypr, root._monitorLines), root._hyprState, state]);
	}
	function _loadDefaults() {
		defaultsProc.command = ["sh", "-c", "for m in " + Sys.DEFAULTS.map(d => d.mime).join(" ") + "; do xdg-mime query default \"$m\"; done"];
		defaultsProc.running = true;
	}

	Component.onCompleted: {
		root.refresh();
		stateProc.running = true;
	}

	Process {
		id: actionProc
		property var job: null
		onExited: code => {
			if (code !== 0) root.lastError = actionProc.job.failure;
			if (actionProc.job.after) actionProc.job.after();
			Qt.callLater(root._next);
		}
	}
	Process {
		id: autostartProc
		running: true
		command: ["systemctl", "--user", "is-enabled", "bloom-shell"]
		stdout: StdioCollector {
			onStreamFinished: {
				root.autostart = text.trim() === "enabled";
				root.autostartLoaded = true;
			}
		}
	}
	Timer {
		id: verifyTimer
		interval: 300
		onTriggered: optionsProc.running = true
	}
	Timer {
		id: displayCheck
		interval: 500
		onTriggered: monitorsProc.running = true
	}
	Timer {
		id: pendingTimer
		interval: 1000
		repeat: true
		onTriggered: {
			root.pendingSeconds--;
			if (root.pendingSeconds <= 0) root.revertDisplay();
		}
	}
	Process {
		id: optionsProc
		command: ["sh", "-c", "for o in " + Sys.OPTIONS.join(" ") + "; do printf '%s|' \"$o\"; hyprctl getoption \"$(printf %s \"$o\" | tr . :)\" | head -1; done"]
		stdout: StdioCollector {
			onStreamFinished: {
				root.hyprLive = Sys.parseOptions(text);
				root.hyprLoaded = Object.keys(root.hyprLive).length > 0;
				if (root._checks.length) root._settle();
			}
		}
	}
	Process {
		id: stateProc
		command: ["cat", root._hyprState]
		stdout: StdioCollector {
			onStreamFinished: {
				try {
					const state = JSON.parse(text);
					root.hypr = state.hypr || {};
					root._monitorLines = state.monitors || [];
				} catch (e) {}
			}
		}
	}
	Process {
		id: monitorsProc
		command: ["hyprctl", "monitors", "-j"]
		stdout: StdioCollector {
			onStreamFinished: {
				try { root.monitors = JSON.parse(text); } catch (e) { root.monitors = []; }
				const p = root.pendingDisplay;
				const m = p && p.mode ? root.monitors.find(x => x.name === p.name) : null;
				if (m && (Sys.currentMode(m) !== p.mode || Math.abs(m.scale - p.scale) > 0.01)) {
					root.lastError = "That display mode didn't apply, so it was put back";
					root.revertDisplay();
				}
			}
		}
	}
	Process {
		id: disksProc
		command: ["df", "-B1", "--output=target,size,used"]
		stdout: StdioCollector { onStreamFinished: root.disks = Sys.parseDisks(text) }
	}
	Process {
		id: infoProc
		command: ["sh", "-c", "echo hostname=$(cat /etc/hostname 2>/dev/null); echo kernel=$(uname -r); echo cpu=$(sed -n 's/^model name[^:]*: //p' /proc/cpuinfo | head -1); awk '/MemTotal/{printf \"memory=%.1f GB\\n\", $2/1048576}' /proc/meminfo"]
		stdout: StdioCollector {
			onStreamFinished: {
				const info = Sys.parseInfo(text);
				root.hostname = info.hostname;
				root.kernel = info.kernel;
				root.cpu = info.cpu;
				root.memory = info.memory;
			}
		}
	}
	Process {
		id: timeProc
		command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP", "--value"]
		stdout: StdioCollector {
			onStreamFinished: {
				const lines = text.split("\n");
				root.timezone = lines[0] || "";
				root.ntp = lines[1] === "yes";
			}
		}
	}
	Process {
		id: updatesProc
		command: ["sh", "-c", "${BLOOM_CHECKUPDATES:-checkupdates} 2>/dev/null; echo exit=$?"]
		stdout: StdioCollector { onStreamFinished: root.updates = Sys.parseUpdates(text) }
	}
	Process {
		id: defaultsProc
		stdout: StdioCollector {
			onStreamFinished: {
				const lines = text.split("\n");
				const next = {};
				Sys.DEFAULTS.forEach((d, i) => { next[d.id] = lines[i] || ""; });
				root.defaults = next;
			}
		}
	}
}
