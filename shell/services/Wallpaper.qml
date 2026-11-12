pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/wallpaper/wallpaper.js" as Logic
import "../modules/lock/lock.js" as Ii

// The wallpaper: which one, the picker, and the Adaptive accent. Until a
// wallpaper is chosen here, ii's stays in use, then Bloom's own.
Singleton {
	id: root

	readonly property string _own: Settings.values["bloom-wallpaper"]
	readonly property string _ii: Ii.wallpaperFrom(iiConfig.text())
	// Neither Bloom nor ii has one: Bloom's own, matching the theme.
	readonly property string path: root._own || root._ii
		|| Logic.localPath(Qt.resolvedUrl("../assets/" + Logic.defaultFor(Settings.values["bloom-theme-mode"])))
	readonly property real zoom: root._own || !root._ii ? 1 : Ii.wallpaperZoomFrom(iiConfig.text())
	readonly property bool video: Logic.isVideo(root.path)
	readonly property string defaultFolder: Quickshell.env("HOME") + "/Pictures/Wallpapers"
	readonly property string folder: Settings.values["bloom-wallpaper-dir"] || root.defaultFolder
	readonly property bool adaptive: Settings.values["bloom-theme-mode"] === "adaptive"

	property string accent: ""
	property bool opened: false
	property var items: []
	property bool _pickRandom: false
	property string error: ""
	readonly property bool loading: listing.running || validateFolder.running
	readonly property bool pickerRunning: picker.running
	function browse(kind) {
		if (picker.running || (kind !== "file" && kind !== "folder")) return;
		root.error = "";
		picker.kind = kind;
		picker.result = "";
		picker.command = ["sh", "-c", Logic.pickerScript, "sh", kind, root.folder];
		picker.running = true;
	}
	property string _listedFolder: ""
	property string _listingText: ""
	function refresh() {
		if (listing.running) return;
		if (!root.folder.startsWith("/")) { root.items = []; root.error = "Use an absolute wallpaper folder path."; return; }
		root.error = "";
		root._listedFolder = root.folder;
		root._listingText = "";
		listing.command = ["timeout", "30s", "find", "-L", root.folder, "-type", "f", "-print0"];
		listing.running = true;
	}
	function chooseFolder(path) {
		if (validateFolder.running) return;
		validateFolder.candidate = Logic.localPath(path).replace(/^~(?=\/|$)/, Quickshell.env("HOME"));
		if (!validateFolder.candidate.startsWith("/")) { root.error = "Use an absolute folder path, or start with ~/"; return; }
		validateFolder.running = true;
	}
	onFolderChanged: if (root.opened) root.refresh()

	function set(path) {
		if (!Logic.PICTURES.test(path) && !Logic.isVideo(path)) { root.error = "Choose a supported image or video file."; return root.error; }
		root.error = "";
		return Settings.set("bloom-wallpaper", path, error => { root.error = error; if (error === "") root.opened = false; });
	}
	function show() {
		root.opened = true;
		root.refresh();
	}
	function hide() { root.opened = false; }
	function toggle() { if (root.opened) root.hide(); else root.show(); }
	function random() {
		root._pickRandom = true;
		root.refresh();
	}
	function _refreshAccent() {
		if (!root.adaptive || root.path === "" || root.video) return;
		colors.running = false;
		colors.command = ["matugen", "image", root.path, "--dry-run", "--json", "hex", "--mode", "dark", "--source-color-index", "0"];
		colors.running = true;
	}
	function _adaptiveChanged() {
		if (root.adaptive) root._refreshAccent();
	}
	onPathChanged: root._refreshAccent()
	onAdaptiveChanged: root._adaptiveChanged()
	Component.onCompleted: root._adaptiveChanged()

	FileView {
		id: iiConfig
		path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/illogical-impulse/config.json"
		printErrors: false
	}
	Process {
		id: picker
		property string kind: "file"
		property string result: ""
		stdout: StdioCollector { onStreamFinished: picker.result = text.replace(/\r?\n$/, "") }
		onExited: code => Qt.callLater(() => {
			if (code === 0 && picker.result !== "") {
				if (picker.kind === "folder") root.chooseFolder(picker.result);
				else root.set(picker.result);
			} else if (code === 127) root.error = "A file picker is unavailable. Install kdialog, zenity or qarma; you can still type a folder path above.";
			else if (code !== 0 && code !== 1) root.error = "The file picker could not be opened. Your wallpaper was kept.";
		})
	}

	Process {
		id: validateFolder
		property string candidate: ""
		command: ["test", "-d", validateFolder.candidate]
		onExited: code => {
			if (code !== 0) { root.error = "Folder not found. Choose an existing folder."; return; }
			Settings.set("bloom-wallpaper-dir", validateFolder.candidate, error => { root.error = error; if (error === "") root.refresh(); });
		}
	}
	Process {
		id: listing
		stdout: StdioCollector { onStreamFinished: root._listingText = text }
		stderr: StdioCollector {}
		onExited: code => Qt.callLater(() => {
			if (root._listedFolder !== root.folder) { root.refresh(); return; }
			root.items = Logic.parseList(root._listingText);
			if (code !== 0) root.error = "Some wallpapers could not be read. Check the folder and its permissions.";
			if (root._pickRandom) {
				root._pickRandom = false;
				const next = Logic.pickOther(root.items, root.path, Math.random());
				if (next) root.set(next);
			}
		})
	}
	Process {
		id: colors
		stdout: StdioCollector {
			onStreamFinished: {
				const accent = Logic.accentFrom(text);
				if (accent) root.accent = accent;
			}
		}
	}
}
