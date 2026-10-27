pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dock/extras.js" as Logic

// Dock extras use structured lsblk/GIO output and argv-only processes. This
// service does no work while the extras position is off.
Singleton {
	id: root
	property var drives: []
	property var folders: []
	property int trashItems: 0
	property var _dirs: ({})
	property var _existing: ({})
	property var _folderQueue: []
	property var _checkQueue: []
	property string _currentFolder: ""
	property string _currentCheck: ""
	property string toast: ""
	property int toastSerial: 0
	property bool _monitorOk: true
	readonly property bool busy: actionProc.running
	readonly property bool active: Settings.values["bloom-dock-extras-position"] !== "off"
	readonly property var items: {
		if (!root.active) return [];
		let out = root.folders;
		if (Settings.values["bloom-dock-extras-drives"]) out = root.drives.concat(out);
		if (Settings.values["bloom-dock-extras-recycle-bin"])
			out = out.concat([{ key: "trash", kind: "trash", name: "Trash", path: "trash:///", icon: "user-trash", count: root.trashItems }]);
		return out;
	}

	function _notice(message) { root.toast = message; root.toastSerial++; }
	function refresh() {
		if (!root.active) return;
		if (Settings.values["bloom-dock-extras-drives"] && !driveScan.running) driveScan.running = true;
		if (Settings.values["bloom-dock-extras-recycle-bin"] && !trashScan.running) trashScan.running = true;
		root._scanFolders();
	}
	function _scanFolders() {
		const ids = (Settings.values["bloom-dock-extras-folders"] || "").split(",")
			.map(x => x.trim().toLowerCase()).filter(x => Logic.FOLDERS.indexOf(x) >= 0);
		root._folderQueue = ids;
		root._dirs = {};
		root._nextFolder();
	}
	function _nextFolder() {
		if (folderScan.running) return;
		if (root._folderQueue.length === 0) { root._checkFolders(); return; }
		root._currentFolder = root._folderQueue[0];
		root._folderQueue = root._folderQueue.slice(1);
		folderScan.command = ["xdg-user-dir", root._currentFolder.toUpperCase()];
		folderScan.running = true;
	}
	function _checkFolders() {
		const possible = Logic.folderEntries(Settings.values["bloom-dock-extras-folders"],
			Settings.values["bloom-dock-extras-custom-folders"], root._dirs,
			Quickshell.env("HOME") || "", _ => true);
		root._checkQueue = possible.map(f => f.path);
		root._existing = {};
		root._nextCheck();
	}
	function _nextCheck() {
		if (folderCheck.running) return;
		if (root._checkQueue.length === 0) {
			root.folders = Logic.folderEntries(Settings.values["bloom-dock-extras-folders"],
				Settings.values["bloom-dock-extras-custom-folders"], root._dirs,
				Quickshell.env("HOME") || "", path => !!root._existing[path]);
			return;
		}
		root._currentCheck = root._checkQueue[0];
		root._checkQueue = root._checkQueue.slice(1);
		folderCheck.command = ["gio", "info", "-a", "standard::type", root._currentCheck];
		folderCheck.running = true;
	}

	function action(key, verb) {
		if (!root.active) return "extras off";
		const item = root.items.find(x => x.key === key);
		if (!item) return "no such extra";
		if (item.kind === "drive") {
			const argv = Logic.driveAction(root.drives, key, verb);
			if (!argv) return "drive unavailable";
			root._run(argv, { kind: "drive", key: key, verb: verb, device: item.device, stage: argv[1] });
			return "ok";
		}
		if (verb === "open") {
			root._run(["gio", "open", item.path], { kind: "open" });
			return "ok";
		}
		return "unsupported action";
	}
	function emptyTrash(confirmed) {
		if (!confirmed || !root.active || !Settings.values["bloom-dock-extras-recycle-bin"]) return "confirmation required";
		root._run(["gio", "trash", "--empty"], { kind: "empty" });
		return "ok";
	}
	function _run(argv, job) {
		if (actionProc.running) { root._notice("Another dock action is still running"); return; }
		root._job = job;
		actionProc.command = argv;
		actionProc.running = true;
	}
	property var _job: null

	onActiveChanged: {
		if (root.active) { root._monitorOk = true; root.refresh(); }
		else { root.drives = []; root.folders = []; root._folderQueue = []; root._checkQueue = []; }
	}
	Connections {
		target: Settings
		function onSettingChanged(key) {
			if (root.active && key.startsWith("bloom-dock-extras-")) root.refresh();
		}
	}
	Timer { interval: 30000; repeat: true; running: root.active; onTriggered: root.refresh() }
	Timer { id: debounce; interval: 300; onTriggered: root.refresh() }
	Timer { id: monitorRetry; interval: 30000; onTriggered: if (root.active) root._monitorOk = true }
	Process {
		id: monitor
		running: root.active && root._monitorOk && Settings.values["bloom-dock-extras-drives"]
		command: ["udisksctl", "monitor"]
		stdout: SplitParser { onRead: _ => debounce.restart() }
		onExited: if (root.active) { root._monitorOk = false; monitorRetry.restart(); debounce.restart(); }
	}
	Process {
		id: driveScan
		command: ["lsblk", "--json", "--bytes", "-o", "PATH,UUID,LABEL,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TYPE"]
		stdout: StdioCollector { id: driveOut }
		onExited: code => {
			if (code !== 0) return;
			const parsed = Logic.parseDrives(driveOut.text, Settings.values["bloom-dock-extras-hidden-drives"]);
			if (parsed !== null) root.drives = parsed;
		}
	}
	Process {
		id: folderScan
		stdout: StdioCollector { id: folderOut }
		onExited: code => {
			if (code === 0) root._dirs[root._currentFolder] = folderOut.text.trim();
			root._nextFolder();
		}
	}
	Process {
		id: folderCheck
		stdout: StdioCollector { id: checkOut }
		onExited: code => {
			if (code === 0 && checkOut.text.indexOf("standard::type: directory") >= 0)
				root._existing[root._currentCheck] = true;
			root._nextCheck();
		}
	}
	Process {
		id: trashScan
		command: ["gio", "info", "-a", "trash::item-count", "trash:///"]
		stdout: StdioCollector { id: trashOut }
		onExited: code => {
			const count = code === 0 ? Logic.trashCount(trashOut.text) : null;
			if (count !== null) root.trashItems = count;
		}
	}
	Process {
		id: actionProc
		stdout: StdioCollector { id: actionOut }
		onExited: code => {
			const job = root._job;
			root._job = null;
			if (code !== 0) {
				root._notice(job && job.kind === "drive" && job.verb === "eject" ? "Couldn't safely eject the drive" : "Dock action failed");
				return;
			}
			if (job && job.kind === "drive" && job.verb === "open" && job.stage === "mount") {
				const m = /\s+at\s+(\/[^\n]+?)(?:\.|\n|$)/.exec(actionOut.text);
				if (m) root._run(["gio", "open", m[1]], { kind: "open" });
			} else if (job && job.kind === "drive" && job.verb === "eject" && job.stage === "unmount") {
				const still = root.drives.find(x => x.key === job.key && x.device === job.device);
				if (still) root._run(["udisksctl", "power-off", "-b", job.device], { kind: "power-off" });
			}
			root.refresh();
		}
	}
}
