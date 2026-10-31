import QtQuick
import QtTest
import "../../shell/settings"

Item {
	id: host
	width: 740
	height: 560

	QtObject {
		id: fakeStore
		property var values: ({})
		property var sets: []
		function set(key, value) {
			const next = Object.assign({}, values);
			next[key] = value;
			values = next;
			sets.push([key, value]);
		}
	}
	readonly property var defaults: ({
		"bloom-show-update-indicator": true, "bloom-time-format-24h": false, "bloom-low-power": "off",
		"bloom-low-battery-threshold": 20, "bloom-theme-mode": "dark", "bloom-theme-color": "#007aff",
		"bloom-theme-opacity": 0.8, "bloom-theme-saturation": 0.5, "bloom-theme-brightness": 0.15, "bloom-scale": 1.1,
		"bloom-volume-hud-enabled": true, "bloom-volume-edge-enabled": true,
		"bloom-brightness-hud-enabled": true, "bloom-brightness-edge-enabled": true,
		"bloom-notch-mode": "fixed", "bloom-notch-edge-delay": 200, "bloom-calendar-enabled": true,
		"bloom-notch-command-center-enabled": false, "bloom-notch-devices-enabled": false, "bloom-notch-panel-memory": true,
		"bloom-notch-default-panel": "calendar", "bloom-music-mode-enabled": true, "bloom-music-compact-notch": true,
		"bloom-media-layout": "classic", "bloom-media-ambience-enabled": true, "bloom-media-compact-glow-enabled": true,
		"bloom-shelf-persist": false, "bloom-weather-enabled": true, "bloom-weather-city": "", "bloom-temp-unit": "celsius",
		"bloom-status-widgets": { left: ["weather"], right: ["battery"] },
		"bloom-enabled-modules": ["dock"], "bloom-dock-mode": "smart", "bloom-dock-edge-delay": 200,
		"bloom-dock-preview-enabled": true, "bloom-dock-icon-only": false, "bloom-dock-separator-enabled": true,
		"bloom-dock-workspaces-enabled": true, "bloom-dock-win-number-enabled": true, "bloom-dock-adaptive": false,
		"bloom-dock-extras-position": "left", "bloom-dock-extras-drives": true, "bloom-dock-extras-hidden-drives": "[]",
		"bloom-dock-extras-recycle-bin": true, "bloom-dock-extras-folders": "downloads", "bloom-dock-extras-custom-folders": "[{\"name\":\"Code\",\"path\":\"/code\"}]"
	})

	Component {
		id: viewComponent
		SettingsView { width: 740; height: 560; store: fakeStore; version: "0.1.0" }
	}

	TestCase {
		name: "SettingsView"
		when: windowShown

		function make(tab) {
			fakeStore.values = Object.assign({}, host.defaults);
			fakeStore.sets = [];
			const v = createTemporaryObject(viewComponent, host, { tab: tab || "general" });
			verify(v);
			return v;
		}
		function part(v, name) {
			tryVerify(() => findChild(v, name) !== null, 1000, name);
			return findChild(v, name);
		}
		function click(v, name) {
			waitForRendering(host);
			const it = part(v, name);
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
		}
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}

		function test_headingFollowsTheTab() {
			const v = make();
			compare(part(v, "heading").text, "General");
			click(v, "tab:appearance");
			compare(v.tab, "appearance");
			compare(part(v, "heading").text, "Appearance");
			compare(part(v, "copy").text, "Make every surface feel at home on your desktop.");
		}

		// Bloom's boxes, from Settings.css.
		function test_layout() {
			const v = make();
			waitForRendering(host);
			const tab = part(v, "tab:general"), p = tab.mapToItem(v, 0, 0);
			compare(p.x, 8);
			compare(tab.width, 153);
			compare(tab.height, 36);
			const close = part(v, "close"), c = close.mapToItem(v, 0, 0);
			compare([c.x, c.y, close.width], [700, 16, 22]);
		}

		function test_toggleWrites() {
			const v = make();
			click(v, "time24");
			compare(fakeStore.sets, [["bloom-time-format-24h", true]]);
			verify(part(v, "time24").checked);
		}

		function test_sliderSnapsToSteps() {
			const v = make();
			const s = part(v, "battery");
			waitForRendering(host);
			const p = s.mapToItem(host, s.width, s.height / 2);
			mouseClick(host, p.x - 1, p.y);
			compare(fakeStore.sets, [["bloom-low-battery-threshold", 50]]);
			compare(part(v, "row:Low Battery Alert") !== null, true);
			compare(findChild(part(v, "row:Low Battery Alert"), "desc").text, "Trigger at 50%");
		}

		function test_selectPicks() {
			const v = make("appearance");
			click(v, "themeMode");
			click(v, "option:custom");
			compare(fakeStore.sets, [["bloom-theme-mode", "custom"]]);
			compare(part(v, "selectLabel").text, "Custom Color");
			verify(!part(v, "selectPopup").visible);
			verify(part(v, "color").visible, "custom mode shows its colour");
		}

		function test_scaleButtonsStopAtTheEnds() {
			const v = make("appearance");
			click(v, "scale:up");
			click(v, "scale:up");
			compare(fakeStore.values["bloom-scale"], 1.3);
			click(v, "scale:up");
			compare(fakeStore.sets.length, 2);
		}

		function test_edgeRowsFollowTheirHud() {
			const v = make("overlays");
			verify(part(v, "volumeEdge").visible);
			click(v, "volume");
			compare(fakeStore.values["bloom-volume-hud-enabled"], false);
			verify(!part(v, "volumeEdge").visible);
		}

		function test_actionsSignal() {
			const v = make();
			const restart = spy(v, "restartRequested"), quit = spy(v, "quitRequested");
			click(v, "restart");
			part(v, "page").contentY = 400;
			click(v, "quit");
			compare([restart.count, quit.count], [1, 1]);
		}

		function test_about() {
			const v = make("about");
			compare(part(v, "version").text, "Version 0.1.0");
			const exported = spy(v, "exportRequested"), imported = spy(v, "importRequested");
			click(v, "export");
			click(v, "import");
			compare([exported.count, imported.count], [1, 1]);
		}

		function test_resetAsksFirst() {
			const v = make();
			const confirmed = spy(v, "resetConfirmed");
			click(v, "reset");
			verify(part(v, "confirm").visible);
			click(v, "confirmCancel");
			verify(!part(v, "confirm").visible);
			compare(confirmed.count, 0);
			click(v, "reset");
			click(v, "confirmOk");
			compare(confirmed.count, 1);
		}

		function test_lastPanelCantTurnOff() {
			const v = make("notch");
			verify(!part(v, "calendar").enabled, "the only panel on stays on");
		}

		function test_notchRowsFollowTheirSettings() {
			const v = make("notch");
			verify(!part(v, "notchPeek").visible);
			verify(!part(v, "defaultPanel").visible);
			fakeStore.set("bloom-notch-mode", "peek");
			fakeStore.set("bloom-notch-panel-memory", false);
			verify(part(v, "notchPeek").visible);
			verify(part(v, "defaultPanel").visible);
		}

		function test_citySearch() {
			const v = make("notch");
			const queried = spy(v, "cityQueried");
			const field = part(v, "city");
			field.forceActiveFocus();
			part(v, "page").contentY = 360;
			keyClick("P");
			compare(queried.count, 1);
			v.cityResults = [{ name: "Pune", country: "India", latitude: 18.5, longitude: 73.8 }];
			click(v, "cityResult:Pune");
			compare(fakeStore.values["bloom-weather-city"], "Pune");
			compare(fakeStore.values["bloom-weather-lat"], 18.5);
			compare(fakeStore.values["bloom-weather-lon"], 73.8);
		}

		function test_dockToggleEditsTheModules() {
			const v = make("dock");
			verify(part(v, "dockRows").visible);
			click(v, "dock");
			compare(fakeStore.values["bloom-enabled-modules"], []);
			verify(!part(v, "dockRows").visible);
		}

		function test_dockExtrasChips() {
			const v = make("dock");
			v.drives = [{ id: "sda1", label: "Data" }];
			const d = part(v, "disclosure:Manage dock extras");
			d.open = true;
			part(v, "page").contentY = 420;
			click(v, "folder:documents");
			compare(fakeStore.values["bloom-dock-extras-folders"], "downloads,documents");
			click(v, "drive:sda1");
			compare(fakeStore.values["bloom-dock-extras-hidden-drives"], '["sda1"]');
			part(v, "page").contentY = 600;
			click(v, "removeFolder:/code");
			compare(fakeStore.values["bloom-dock-extras-custom-folders"], "[]");
		}

		function test_widgetButtons() {
			const v = make("notch");
			part(v, "disclosure:Choose status widgets").open = true;
			part(v, "page").contentY = 900;
			click(v, "pill:weather:swap");
			compare(fakeStore.values["bloom-status-widgets"], { left: [], right: ["battery", "weather"] });
			click(v, "pill:weather:x");
			compare(fakeStore.values["bloom-status-widgets"], { left: [], right: ["battery"] });
		}

		function test_widgetDragBetweenZones() {
			const v = make("notch");
			part(v, "disclosure:Choose status widgets").open = true;
			waitForRendering(host);
			const page = part(v, "page");
			page.contentY = page.contentHeight - page.height;
			waitForRendering(host);
			const pill = part(v, "pill:cpu"), zone = part(v, "zone:left");
			const from = pill.mapToItem(host, pill.width / 2, pill.height / 2);
			const to = zone.mapToItem(host, zone.width - 30, zone.height / 2);
			mousePress(host, from.x, from.y);
			for (let i = 1; i <= 6; i++) {
				mouseMove(host, from.x + (to.x - from.x) * i / 6, from.y + (to.y - from.y) * i / 6);
				wait(20);
			}
			verify(part(v, "dragGhost").visible, "the pill follows the pointer");
			mouseRelease(host, to.x, to.y);
			compare(fakeStore.values["bloom-status-widgets"].left, ["weather", "cpu"]);
		}

		function test_closeSignals() {
			const v = make();
			const closed = spy(v, "closeRequested");
			click(v, "close");
			compare(closed.count, 1);
		}
	}
}
