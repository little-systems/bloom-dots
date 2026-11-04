//@ pragma UseQApplication
//@ pragma AppId bloom-settings
import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.services
import "settings"
import "common/render"
import "common"
import "common/tokens.js" as Tokens
import "services/settings.js" as Logic
import "modules/dock/extras.js" as Extras

// The settings app: its own process (`bloom ipc settings open`), so a crash
// here can't take the shell down. Both watch the same file, so a change here
// applies live. SettingsView is the pure part; this does the system work.
ShellRoot {
	id: app
	Binding { target: Fonts; property: "override"; value: Settings.values["bloom-font-family"] }
	Binding { target: Render; property: "uiScale"; value: Settings.values["bloom-scale"] }
	Binding { target: Render; property: "fontScale"; value: Settings.values["bloom-font-scale"] }

	Binding { target: Render; property: "reduceMotion"; value: Settings.values["bloom-reduce-motion"] }
	Binding {
		target: Render
		property: "animationStyle"
		value: Settings.values["bloom-animation-style"]
	}

	// What a reset leaves alone: which surfaces run, and the chosen wallpaper.
	readonly property var _keep: ["bloom-enabled-modules", "bloom-wallpaper", "bloom-wallpaper-dir", "bloom-device-looks"]
	property string version: ""
	property string exportLabel: "Export Settings"
	property string importLabel: "Import Settings"
	property var cityResults: []
	// Every drive, including the ones hidden from the dock: that's how they
	// come back.
	property var drives: []
	property string _cityQuery: ""

	// Bloom's city search: Open-Meteo's geocoder, debounced.
	function searchCity(text) {
		app._cityQuery = text.trim();
		if (app._cityQuery.length < 2) {
			app.cityResults = [];
			cityTimer.stop();
		} else {
			cityTimer.restart();
		}
	}
	function _fetchCities() {
		const query = app._cityQuery;
		const xhr = new XMLHttpRequest();
		xhr.onreadystatechange = () => {
			if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200 || query !== app._cityQuery) return;
			try {
				app.cityResults = (JSON.parse(xhr.responseText).results || []).slice(0, 5);
			} catch (e) {
				app.cityResults = [];
			}
		};
		xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=5&name=" + encodeURIComponent(query));
		xhr.send();
	}

	function run(argv) { Quickshell.execDetached(argv); }
	function reset() {
		const defaults = Logic.defaults();
		const changes = {};
		Logic.keys().filter(key => app._keep.indexOf(key) < 0).forEach(key => changes[key] = defaults[key]);
		app.saveError = "";
		Settings.setMany(changes, error => { app.saveError = error; if (error === "") app.run(["systemctl", "--user", "restart", "bloom-shell"]); });
	}
	function importFrom(text) {
		let parsed;
		try {
			parsed = JSON.parse(text);
		} catch (e) {
			app.importLabel = "Import Failed";
			return;
		}
		if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
			app.importLabel = "Import Failed";
			app.saveError = "Import must contain a settings object";
			return;
		}
		const changes = {};
		Logic.keys().filter(key => key in parsed && key !== "bloom-enabled-modules").forEach(key => changes[key] = parsed[key]);
		app.importLabel = "Importing…";
		Settings.setMany(changes, error => { app.saveError = error; app.importLabel = error === "" ? "Settings Imported" : "Import Failed"; });
	}

	SystemStore { id: store }
	// Settings.set reports a refused write; dropping that would show a change
	// that never happened.
	property string saveError: ""
	QtObject {
		id: checkedStore
		readonly property var values: Settings.values
		function set(key, value) { app.saveError = ""; Settings.set(key, value, error => app.saveError = error); }
	}

	OpeningMotion { id: appEntrance; initial: Render.macMotion ? 0 : 1; target: 1 }

	FloatingWindow {
		id: win
		readonly property real uiScale: Settings.values["bloom-scale"]
		title: "Bloom Settings"
		color: "transparent"
		// Match the owner's chosen window independently of font/UI scale, while
		// keeping it reachable when moved onto a smaller logical screen.
		readonly property int fixedWidth: Math.min(Tokens.settings.window.width, Math.max(320, (win.screen?.width || 1920) - 32))
		readonly property int fixedHeight: Math.min(Tokens.settings.window.height, Math.max(240, (win.screen?.height || 1080) - 32))
		implicitWidth: win.fixedWidth
		implicitHeight: win.fixedHeight
		minimumSize: Qt.size(win.fixedWidth, win.fixedHeight)
		maximumSize: minimumSize
		onClosed: Qt.quit()

		SettingsView {
			id: view
			objectName: "view"
			width: win.width / win.uiScale
			height: win.height / win.uiScale
			scale: win.uiScale
			transformOrigin: Item.TopLeft
			opacity: appEntrance.progress
			transform: [
				Scale { origin.x: view.width / 2; origin.y: view.height / 2; xScale: appEntrance.zoom; yScale: appEntrance.zoom },
				Translate { y: appEntrance.rise }
			]
			theme: Theme
			store: checkedStore
			saveError: app.saveError
			onErrorDismissed: app.saveError = ""
			autostart: store.autostart
			version: app.version
			exportLabel: app.exportLabel
			importLabel: app.importLabel
			onCloseRequested: Qt.quit()
			onDragRequested: win.startSystemMove()
			onAutostartToggled: enabled => store.setAutostart(enabled)
			onResetConfirmed: app.reset()
			onRestartRequested: app.run(["systemctl", "--user", "restart", "bloom-shell"])
			onQuitRequested: app.run(["systemctl", "--user", "stop", "bloom-shell"])
			onExportRequested: exportDialog.open()
			onImportRequested: importDialog.open()
			onColorRequested: colorDialog.open()
			cityResults: app.cityResults
			drives: app.drives
			sys: store
			tab: Quickshell.env("BLOOM_SETTINGS_TAB") || "display"
			net: Network
			bt: Bluetooth
			onCheatsheetRequested: app.run(["qs", "-c", "bloom", "ipc", "call", "cheatsheet", "toggle"])
			onCityQueried: text => app.searchCity(text)
			onAddFolderRequested: folderDialog.open()
		}
	}

	FileDialog {
		id: exportDialog
		fileMode: FileDialog.SaveFile
		currentFile: "file://" + Quickshell.env("HOME") + "/bloom-settings.json"
		onAccepted: {
			app.run(["cp", Settings.path, selectedFile.toString().replace("file://", "")]);
			app.exportLabel = "Settings Exported";
		}
	}
	FileDialog {
		id: importDialog
		fileMode: FileDialog.OpenFile
		nameFilters: ["JSON (*.json)"]
		onAccepted: {
			importFile.path = selectedFile.toString().replace("file://", "");
			importFile.running = true;
		}
	}
	Process {
		id: importFile
		property string path: ""
		command: ["cat", importFile.path]
		stdout: StdioCollector { onStreamFinished: app.importFrom(text) }
	}
	Process {
		running: true
		command: ["lsblk", "--json", "--bytes", "-o", "PATH,UUID,LABEL,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TYPE"]
		stdout: StdioCollector {
			onStreamFinished: app.drives = Extras.parseDrives(text, "[]").map(d => ({ id: d.uuid || "path:" + d.device, label: d.name || d.label || d.device }))
		}
	}
	Timer {
		id: cityTimer
		interval: 300
		onTriggered: app._fetchCities()
	}
	FolderDialog {
		id: folderDialog
		onAccepted: {
			const path = selectedFolder.toString().replace("file://", "");
			let list = [];
			try {
				list = JSON.parse(Settings.values["bloom-dock-extras-custom-folders"]);
			} catch (e) {}
			if (list.some(f => f.path === path)) return;
			checkedStore.set("bloom-dock-extras-custom-folders", JSON.stringify(list.concat([{ name: path.split("/").pop(), path: path }])));
		}
	}
	ColorDialog {
		id: colorDialog
		selectedColor: Settings.values["bloom-theme-color"]
		onAccepted: checkedStore.set("bloom-theme-color", String(selectedColor))
	}

	Process {
		running: true
		command: ["cat", Quickshell.shellPath("../VERSION")]
		stdout: StdioCollector { onStreamFinished: app.version = text.trim() }
	}

	IpcHandler {
		target: "settingsapp"
		function state(): string {
			return JSON.stringify({ tab: view.tab, autostart: store.autostart, version: app.version,
				width: win.width, height: win.height, fixedWidth: win.fixedWidth, fixedHeight: win.fixedHeight });
		}
		function tab(id: string): string { view.tab = id; return "ok"; }
	}
}
