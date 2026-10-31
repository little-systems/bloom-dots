import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
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
	property var _monitorLines: []

	readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
	readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)
	readonly property string sink: Pipewire.defaultAudioSink?.name ?? ""
	readonly property string source: Pipewire.defaultAudioSource?.name ?? ""
	readonly property real volume: Audio.volume
	readonly property var mixer: Audio.mixerRows
	readonly property bool brightnessAvailable: Brightness.available
	readonly property real brightness: Brightness.percent / 100
	readonly property string powerMode: Battery.powerMode
	readonly property bool batteryAvailable: Battery.available
	readonly property int batteryLevel: Battery.level

	readonly property string _hyprPath: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/hypr/custom/bloom-settings.lua"
	readonly property string _hyprState: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/bloom/hypr-settings.json"

	function refresh() {
		for (const p of [monitorsProc, disksProc, infoProc, timeProc, updatesProc]) p.running = true;
		root._loadDefaults();
	}
	function setVolume(v) { Audio.setVolume(v); }
	function setBrightness(v) { Brightness.setPercent(v * 100); }
	function setSink(name) { Pipewire.preferredDefaultAudioSink = root.sinks.find(n => n.name === name) ?? null; }
	function setSource(name) { Pipewire.preferredDefaultAudioSource = root.sources.find(n => n.name === name) ?? null; }
	function setPowerMode(mode) { Quickshell.execDetached(["powerprofilesctl", "set", mode]); }
	function setNtp(on) {
		Quickshell.execDetached(["timedatectl", "set-ntp", on ? "true" : "false"]);
		root.ntp = on;
	}
	function setDefault(mime, desktopId) { Quickshell.execDetached(["xdg-mime", "default", desktopId, mime]); }
	function runUpdates() { Quickshell.execDetached(["kitty", "-e", "sudo", "pacman", "-Syu"]); }
	function setHypr(path, value) {
		root.hypr = Sys.withOption(root.hypr, path, value);
		Quickshell.execDetached(["hyprctl", "eval", Sys.hyprConfig(Sys.withOption({}, path, value))]);
		root._save();
	}
	function setMonitor(monitor, mode, scale) {
		const line = Sys.monitorLine(monitor, mode, scale);
		root._monitorLines = root._monitorLines.filter(l => l.indexOf('"' + monitor.name + '"') < 0).concat([line]);
		Quickshell.execDetached(["hyprctl", "eval", line]);
		root._save();
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
		command: ["sh", "-c", "hostname; uname -r; grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; awk '/MemTotal/{printf \"%.1f GB\", $2/1048576}' /proc/meminfo"]
		stdout: StdioCollector {
			onStreamFinished: {
				const lines = text.split("\n").map(l => l.trim());
				root.hostname = lines[0] || "";
				root.kernel = lines[1] || "";
				root.cpu = lines[2] || "";
				root.memory = lines[3] || "";
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
		command: ["sh", "-c", "${BLOOM_CHECKUPDATES:-checkupdates} | wc -l"]
		stdout: StdioCollector { onStreamFinished: root.updates = Number(text.trim()) }
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
