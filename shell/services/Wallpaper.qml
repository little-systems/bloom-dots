pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/wallpaper/wallpaper.js" as Logic
import "../modules/lock/lock.js" as Ii

// The wallpaper: which one, the picker, and the Adaptive accent. Until a
// wallpaper is chosen here, ii's stays in use.
Singleton {
	id: root

	readonly property string _own: Settings.values["bloom-wallpaper"]
	readonly property string path: root._own || Ii.wallpaperFrom(iiConfig.text())
	readonly property real zoom: root._own ? 1 : Ii.wallpaperZoomFrom(iiConfig.text())
	readonly property bool video: Logic.isVideo(root.path)
	readonly property string folder: Settings.values["bloom-wallpaper-dir"] || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
	readonly property bool adaptive: Settings.values["bloom-theme-mode"] === "adaptive"

	property string accent: ""
	property bool opened: false
	property var items: []
	property bool _pickRandom: false
	readonly property string _themeScript: Quickshell.shellPath("scripts/adaptive-theme.sh")

	function set(path) {
		Settings.set("bloom-wallpaper", path);
		root.opened = false;
	}
	function show() {
		root.opened = true;
		if (!listing.running) listing.running = true;
	}
	function hide() { root.opened = false; }
	function toggle() { if (root.opened) root.hide(); else root.show(); }
	function random() {
		root._pickRandom = true;
		if (!listing.running) listing.running = true;
	}
	function _refreshAccent() {
		if (!root.adaptive || root.path === "" || root.video) return;
		colors.running = false;
		colors.command = ["matugen", "image", root.path, "--dry-run", "--json", "hex", "--mode", "dark", "--source-color-index", "0"];
		colors.running = true;
		Quickshell.execDetached(["bash", root._themeScript, "apply", root.path]);
	}
	function _adaptiveChanged() {
		if (root.adaptive) root._refreshAccent();
		else Quickshell.execDetached(["bash", root._themeScript, "restore"]);
	}
	onPathChanged: root._refreshAccent()
	onAdaptiveChanged: root._adaptiveChanged()
	// A stale backup means Adaptive ended while the shell was off.
	Component.onCompleted: root._adaptiveChanged()

	FileView {
		id: iiConfig
		path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/illogical-impulse/config.json"
		printErrors: false
	}
	Process {
		id: listing
		command: ["find", root.folder, "-maxdepth", "1", "-type", "f"]
		stdout: StdioCollector {
			onStreamFinished: {
				root.items = Logic.parseList(text);
				if (root._pickRandom) {
					root._pickRandom = false;
					const next = Logic.pickOther(root.items, root.path, Math.random());
					if (next) root.set(next);
				}
			}
		}
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
