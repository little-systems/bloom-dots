//@ pragma UseQApplication
//@ pragma AppId bloom-settings
import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.services
import "settings"
import "common/render"
import "common/tokens.js" as Tokens
import "services/settings.js" as Logic
import "modules/dock/extras.js" as Extras

// The settings app: its own process (`bloom ipc settings open`), so a crash
// here can't take the shell down. Both watch the same file, so a change here
// applies live. SettingsView is the pure part; this does the system work.
ShellRoot {
	id: app

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
		Logic.keys().filter(key => app._keep.indexOf(key) < 0).forEach(key => Settings.set(key, defaults[key]));
		app.run(["systemctl", "--user", "restart", "bloom-shell"]);
	}
	function importFrom(text) {
		let parsed;
		try {
			parsed = JSON.parse(text);
		} catch (e) {
			app.importLabel = "Import Failed";
			return;
		}
		Logic.keys().filter(key => key in parsed && key !== "bloom-enabled-modules").forEach(key => Settings.set(key, parsed[key]));
		app.importLabel = "Settings Imported";
	}

	SystemStore { id: store }
	readonly property var _look: [Settings.values["bloom-theme-opacity"], Settings.values["bloom-translucent-apps"]]
	property bool _lookArmed: false
	on_LookChanged: if (app._lookArmed) lookTimer.restart()
	Timer {
		id: lookTimer
		interval: 300
		onTriggered: store.setLook(Settings.values["bloom-theme-opacity"], Settings.values["bloom-translucent-apps"])
	}
	// Armed after the first read, so opening Settings changes nothing.
	Timer {
		interval: 800
		running: true
		onTriggered: app._lookArmed = true
	}

	// Settings.set reports a refused write; dropping that would show a change
	// that never happened.
	property string saveError: ""
	QtObject {
		id: checkedStore
		readonly property var values: Settings.values
		function set(key, value) { app.saveError = Settings.set(key, value) || ""; }
	}

	FloatingWindow {
		id: win
		readonly property real uiScale: Settings.values["bloom-scale"]
		title: "Bloom Settings"
		color: "transparent"
		implicitWidth: Tokens.settings.window.width
		implicitHeight: Tokens.settings.window.height
		minimumSize: Qt.size(Tokens.settings.window.minWidth * win.uiScale, Tokens.settings.window.minHeight * win.uiScale)
		onClosed: Qt.quit()

		SettingsView {
			id: view
			objectName: "view"
			width: win.width / win.uiScale
			height: win.height / win.uiScale
			scale: win.uiScale
			transformOrigin: Item.TopLeft
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
			Settings.set("bloom-dock-extras-custom-folders", JSON.stringify(list.concat([{ name: path.split("/").pop(), path: path }])));
		}
	}
	ColorDialog {
		id: colorDialog
		selectedColor: Settings.values["bloom-theme-color"]
		onAccepted: Settings.set("bloom-theme-color", String(selectedColor))
	}

	Process {
		running: true
		command: ["cat", Quickshell.shellPath("../VERSION")]
		stdout: StdioCollector { onStreamFinished: app.version = text.trim() }
	}

	IpcHandler {
		target: "settingsapp"
		function state(): string {
			return JSON.stringify({ tab: view.tab, autostart: store.autostart, version: app.version, width: win.implicitWidth });
		}
		function tab(id: string): string { view.tab = id; return "ok"; }
	}
}
