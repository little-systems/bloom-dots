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
	property string aiKey: ""
	property var startup: []
	property var vpns: []
	property var timezones: []
	property var layouts: []
	property var defaultChoices: ({})
	readonly property var installed: Apps.all()
	property string aiCheck: ""
	property string _wantSink: ""
	property string _wantSource: ""
	property string _wantPower: ""
	property var _checks: []
	property var _queue: []
	property int pendingSeconds: 0
	property var _monitorLines: []
	property var _rules: []
	property string _terminalBefore: ""

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
		for (const p of [monitorsProc, disksProc, infoProc, timeProc, updatesProc, optionsProc, startupProc, vpnProc, zonesProc, layoutsProc, choicesProc]) p.running = true;
		root._loadDefaults();
	}
	function setVolume(v) { Audio.setVolume(v); }
	function setBrightness(v) { Brightness.setPercent(v * 100); }
	function setSink(name) {
		root._wantSink = name;
		Pipewire.preferredDefaultAudioSink = root.sinks.find(n => n.name === name) ?? null;
		settleTimer.restart();
	}
	function setSource(name) {
		root._wantSource = name;
		Pipewire.preferredDefaultAudioSource = root.sources.find(n => n.name === name) ?? null;
		settleTimer.restart();
	}
	// The key goes to the tool on stdin, never in a command line.
	function setAiKey(key) {
		keyStore.pendingKey = key;
		keyStore.running = true;
	}
	function removeAiKey() {
		root._run(["secret-tool", "clear", "service", "bloom", "key", "gemini"], "Couldn't remove the key", () => { keyProbe.running = true; });
	}
	function checkAi() {
		root.aiCheck = "Checking…";
		keyCheck.running = true;
	}
	function setPowerMode(mode) {
		root._wantPower = mode;
		PowerProfiles.profile = mode === "power-saver" ? PowerProfile.PowerSaver : mode === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
		settleTimer.restart();
	}
	// The switch only moves when the read-back says so.
	function setNtp(on) {
		root._run(["timedatectl", "set-ntp", on ? "true" : "false"], "Couldn't change automatic time", () => { timeProc.running = true; });
	}
	function setAutostart(on) {
		root._run(["systemctl", "--user", on ? "enable" : "disable", "bloom-shell"], "Couldn't change Launch at Login", () => { autostartProc.running = true; });
	}
	function clearError() { root.lastError = ""; }
	function setStreamVolume(id, value) { Audio.setStreamVolume(id, value); }
	function setStartup(id, on) {
		root._run(["sh", root._query, "autostart-set", id, on ? "on" : "off"], "Couldn't change that startup app", () => { startupProc.running = true; });
	}
	function setTimezone(zone) {
		root._run(["timedatectl", "set-timezone", zone], "Couldn't change the time zone", () => { timeProc.running = true; });
	}
	function setVpn(name, on) {
		root._run(["nmcli", "connection", on ? "up" : "down", name], "Couldn't change " + name, () => { vpnProc.running = true; });
	}
	function setDefault(id, mime, desktopId) {
		root._run(["xdg-mime", "default", desktopId, mime], "Couldn't change the default app", () => root._loadDefaults());
	}
	function launch(id) { Apps.launch(id); }
	function uninstall(id) {
		uninstallProc.command = ["sh", root._query, "package-of", id.replace(/\.desktop$/, "")];
		uninstallProc.running = true;
	}
	// One look for everything: Background Opacity, here and in the shell.
	function setLook(opacity, translucent) {
		const windows = translucent ? Sys.windowOpacity(opacity) : 1;
		root.setHypr("decoration.active_opacity", windows);
		root.setHypr("decoration.inactive_opacity", windows);
		root._rules = Sys.lookRules(translucent);
		root._save();
		terminalLook.command = ["sh", Quickshell.shellPath("scripts/terminal-opacity.sh"), translucent ? String(opacity) : "restore", root._terminalLook];
		terminalLook.running = true;
		reloadTimer.restart();
	}
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
		const state = JSON.stringify({ hypr: root.hypr, monitors: root._monitorLines, rules: root._rules, terminalBefore: root._terminalBefore });
		Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" "$(dirname "$3")" && printf %s "$2" > "$1" && printf %s "$4" > "$3"', "sh",
			root._hyprPath, Sys.hyprFile(root.hypr, root._monitorLines.concat(root._rules)), root._hyprState, state]);
	}
	function _loadDefaults() {
		defaultsProc.command = ["sh", "-c", "for m in " + Sys.DEFAULTS.map(d => d.mime).join(" ") + "; do xdg-mime query default \"$m\"; done"];
		defaultsProc.running = true;
	}

	Component.onCompleted: {
		root.refresh();
		stateProc.running = true;
	}

	readonly property string _query: Quickshell.shellPath("scripts/settings-query.sh")
	Process {
		id: startupProc
		command: ["sh", root._query, "autostart-list"]
		stdout: StdioCollector { onStreamFinished: root.startup = Sys.records(text, ["id", "name", "state"]) }
	}
	Process {
		id: vpnProc
		command: ["sh", root._query, "vpn-list"]
		stdout: StdioCollector { onStreamFinished: root.vpns = Sys.records(text, ["name", "type", "active"]) }
	}
	Process {
		id: zonesProc
		command: ["timedatectl", "list-timezones"]
		stdout: StdioCollector { onStreamFinished: root.timezones = text.split("\n").filter(z => z) }
	}
	Process {
		id: layoutsProc
		command: ["localectl", "list-x11-keymap-layouts"]
		stdout: StdioCollector { onStreamFinished: root.layouts = text.split("\n").filter(l => l) }
	}
	Process {
		id: choicesProc
		command: ["sh", "-c", Sys.DEFAULTS.map(d => "echo \"#" + d.id + "\"; sh \"$0\" mime-apps " + d.mime).join("; "), root._query]
		stdout: StdioCollector {
			onStreamFinished: {
				const out = {};
				let current = "";
				text.split("\n").forEach(line => {
					if (line.startsWith("#")) {
						current = line.slice(1);
						out[current] = [];
					} else if (line.includes("\t")) {
						const [value, label] = line.split("\t");
						if (!out[current].some(o => o.value === value)) out[current].push({ value: value, label: label });
					}
				});
				root.defaultChoices = out;
			}
		}
	}
	Process {
		id: uninstallProc
		stdout: StdioCollector {
			onStreamFinished: {
				const name = text.trim();
				if (name) Quickshell.execDetached(["kitty", "-e", "sudo", "pacman", "-Rns", name]);
				else root.lastError = "That app isn't from a package pacman can remove";
			}
		}
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
	// Sound and power change asynchronously: judge them once they've had time.
	Timer {
		id: settleTimer
		interval: 1000
		onTriggered: {
			if (root._wantSink && root.sink !== root._wantSink) root.lastError = "The sound output didn't change";
			if (root._wantSource && root.source !== root._wantSource) root.lastError = "The microphone didn't change";
			if (root._wantPower && root.powerMode !== root._wantPower) root.lastError = "The power mode didn't change";
			root._wantSink = "";
			root._wantSource = "";
			root._wantPower = "";
		}
	}
	Process {
		id: keyProbe
		running: true
		command: ["sh", "-c", "secret-tool lookup service bloom key gemini >/dev/null 2>&1; echo $?"]
		stdout: StdioCollector {
			onStreamFinished: {
				const code = text.trim();
				root.aiKey = code === "0" ? "saved" : code === "1" ? "missing" : "unavailable";
			}
		}
	}
	Process {
		id: keyStore
		property string pendingKey: ""
		stdinEnabled: true
		command: ["secret-tool", "store", "--label=Bloom Gemini key", "service", "bloom", "key", "gemini"]
		onStarted: {
			keyStore.write(keyStore.pendingKey);
			keyStore.pendingKey = "";
			keyStore.stdinEnabled = false;
		}
		onExited: code => {
			keyStore.stdinEnabled = true;
			if (code !== 0) root.lastError = "Couldn't save the key to your keyring";
			keyProbe.running = true;
		}
	}
	Process {
		id: keyCheck
		command: ["python3", Quickshell.shellPath("scripts/assistant.py"), "--check"]
		stdout: StdioCollector {
			onStreamFinished: root.aiCheck = Assistant.checkText(text)
		}
	}
	readonly property string _terminalLook: Quickshell.env("HOME") + "/.local/state/quickshell/user/generated/terminal/kitty-transparency.conf"
	Process {
		id: terminalLook
		onExited: code => { if (code !== 0) root.lastError = "Couldn't change the terminal's opacity"; }
	}
	// Rules only take hold on a reload.
	Timer {
		id: reloadTimer
		interval: 600
		onTriggered: Quickshell.execDetached(["hyprctl", "reload"])
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
					root._rules = state.rules || [];
					root._terminalBefore = state.terminalBefore || "";
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
