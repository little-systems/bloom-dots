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
		"bloom-show-update-indicator": true, "bloom-reduce-motion": false, "bloom-ai-model": "gemini-2.5-flash",
		"bloom-osd-timeout": 2000, "bloom-volume-protection-enabled": false, "bloom-volume-max-jump": 10, "bloom-volume-max-level": 99,
		"bloom-notifications-dnd": false, "bloom-notifications-timeout": 7000, "bloom-notifications-history-limit": 200,
		"bloom-media-visualizer-enabled": true, "bloom-media-album-art-enabled": true, "bloom-time-format-24h": false, "bloom-low-power": "off",
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

	QtObject {
		id: fakeSys
		property var monitors: [{ name: "eDP-1", description: "Panel", width: 1920, height: 1080, refreshRate: 60.05, scale: 1, x: 0, y: 0, availableModes: ["1920x1080@60.05Hz", "1280x720@60.00Hz"] }]
		property var disks: [{ path: "/", size: 2e11, used: 1e11 }]
		property var hypr: ({})
		property string aiKey: "missing"
		property string aiCheck: ""
		function setAiKey(k) { calls.push(["key", k]); }
		function removeAiKey() {}
		function checkAi() {}
		property bool hyprLoaded: true
		property string lastError: ""
		function clearError() { lastError = ""; }
		property var hyprLive: ({ "general.gaps_in": 9 })
		property var pendingDisplay: null
		property int pendingSeconds: 15
		function keepDisplay() { calls.push(["keep"]); pendingDisplay = null; }
		function revertDisplay() { calls.push(["revert"]); pendingDisplay = null; }
		property var calls: []
		property var sinks: [{ name: "a", description: "Speakers" }]
		property var sources: []
		property string sink: "a"
		property string source: ""
		property real volume: 0.5
		property bool brightnessAvailable: true
		property real brightness: 0.5
		property string powerMode: "balanced"
		property bool batteryAvailable: false
		property int batteryLevel: 0
		property string hostname: "box"
		property string cpu: "CPU"
		property string memory: "8 GB"
		property string kernel: "7.0"
		property string timezone: "Asia/Kolkata"
		property bool ntp: true
		property int updates: 3
		property var defaults: ({ browser: "org.mozilla.firefox.desktop" })
		function setHypr(path, value) { calls.push(["hypr", path, value]); }
		function setMonitor(m, mode, scale) { calls.push(["monitor", m.name, mode, scale]); }
		function setPowerMode(mode) { calls.push(["power", mode]); }
		function setNtp(on) { calls.push(["ntp", on]); }
		function runUpdates() { calls.push(["updates"]); }
		function setVolume(v) {}
		function setBrightness(v) {}
		function setSink(n) {}
		function setSource(n) {}
	}
	QtObject {
		id: fakeNet
		property bool loaded: true
		property bool available: true
		property bool wifiEnabled: true
		property bool connected: true
		property string ssid: "Home"
		property bool scanning: false
		property string busy: ""
		property var lastError: null
		property var networks: [
			{ ssid: "Home", signal: 80, security: "wpa2", connected: true, saved: true },
			{ ssid: "Cafe", signal: 30, security: "wpa2", connected: false, saved: false }
		]
		property var calls: []
		function clearError() { lastError = null; }
		property var holds: []
		function hold(k, w) { holds.push(w); }
		function refresh(r) { calls.push(["refresh"]); }
		function setWifi(on) { calls.push(["wifi", on]); }
		function connect(s, p) { calls.push(["connect", s, p]); }
		function disconnect(s) { calls.push(["disconnect", s]); }
		function forget(s) { calls.push(["forget", s]); }
	}
	QtObject {
		id: fakeBt
		property bool loaded: true
		property string error: ""
		property bool available: true
		property bool powered: true
		property bool discovering: false
		property string busy: ""
		property string pairing: ""
		property var prompt: null
		property var lastError: null
		property var paired: [{ path: "/a", name: "Buds", connected: false, icon: "audio-headset" }]
		property var nearby: [{ path: "/b", name: "Mouse", icon: "input-mouse" }]
		property var calls: []
		property var holds: []
		function clearError() {}
		function hold(k, w) { holds.push(w); }
		function discover(w) { calls.push(["discover", w]); }
		function setPowered(on) {}
		function setConnected(p, w) { calls.push(["connected", p, w]); }
		function unpair(p) { calls.push(["unpair", p]); }
		function pair(p) { calls.push(["pair", p]); }
		function respond(a, pin) { calls.push(["respond", a, pin]); }
	}
	Component {
		id: viewComponent
		SettingsView { width: 740; height: 560; store: fakeStore; version: "0.1.0"; sys: fakeSys; net: fakeNet; bt: fakeBt }
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
			v.tab = "appearance";
			compare(part(v, "heading").text, "Appearance");
			compare(part(v, "copy").text, "Make every surface feel at home on your desktop.");
		}

		// Bloom's boxes as Chromium lays them out (tools/bloom-audit/
		// record-settings.cjs at zoom 1.25, divided back).
		function test_matchesBloomsLayout() {
			const v = make();
			waitForRendering(host);
			function at(item, x, y, w, h, what) {
				const p = item.mapToItem(v, 0, 0);
				fuzzyCompare(p.x, x, 1, what + " x");
				fuzzyCompare(p.y, y, 1, what + " y");
				if (w !== undefined) fuzzyCompare(item.width, w, 1, what + " width");
				if (h !== undefined) fuzzyCompare(item.height, h, 0.6, what + " height");
			}
			at(part(v, "tab:display"), 8.8, 142.8, 153.2, 36, "first tab");
			at(part(v, "tab:sound"), 8.8, 182.8, 153.2, 36, "second tab");
			at(part(v, "close"), 699.2, 16.8, 22, 22, "close");
			at(part(v, "heading"), 194.8, 62.8, undefined, 28.6, "heading");
			at(part(v, "copy"), 194.8, 94.4, undefined, 16.8, "copy");
			at(part(v, "featurePreview"), 192.8, 129.2, 524.4, 52.6, "preview");
			at(part(v, "row:Launch at Login"), 193.8, 221.6, 522.8, undefined, "first row");
			compare(part(v, "row:Launch at Login").height, 50.8);
			const t = part(v, "time24").mapToItem(v, 0, 0);
			fuzzyCompare(t.x, 660.4, 1, "toggle x");
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
			part(v, "page").contentY = 300;
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
			part(v, "page").contentY = 300;
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
			waitForRendering(host);
			part(v, "page").contentY = field.mapToItem(part(v, "page").contentItem, 0, 0).y - 120;
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

		function test_previewFoldsAndStartsClosed() {
			const v = make();
			verify(!part(v, "previewStage").visible);
			click(v, "preview:fold");
			verify(part(v, "previewStage").visible);
			compare(part(v, "previewStage").height, 150);
			compare(part(v, "previewCaption").text, "12-hour time · Launch at login off · Update available: dot on");
		}

		function test_noPreviewOnAbout() {
			verify(!part(make("about"), "featurePreview").visible);
		}

		function test_settingJumpsToItsScene() {
			const v = make();
			click(v, "preview:fold");
			fakeStore.set("bloom-low-battery-threshold", 30);
			tryCompare(part(v, "featurePreview"), "feature", "battery");
			tryVerify(() => findChild(v, "previewBattery") !== null, 1000, "battery pill");
			compare(findChild(v, "previewBattery").text, "Low Battery · 15%");
			fakeStore.set("bloom-low-battery-threshold", 10);
			tryCompare(findChild(v, "previewBattery"), "text", "On Battery · 15%");
		}

		function test_clockFollowsTheFormat() {
			const v = make();
			click(v, "preview:fold");
			tryVerify(() => findChild(v, "previewClock") !== null, 1000, "clock");
			compare(findChild(v, "previewClock").text, "3:42 PM");
			fakeStore.set("bloom-time-format-24h", true);
			compare(findChild(v, "previewClock").text, "15:42");
		}

		function test_notchScenes() {
			const v = make("notch");
			click(v, "preview:fold");
			tryVerify(() => findChild(v, "previewPill") !== null, 1000, "pill");
			compare(findChild(v, "previewPill").targetWidth, 300);
			click(v, "scene:device");
			tryCompare(part(v, "featurePreview"), "feature", "device");
			tryVerify(() => { const p = findChild(v, "previewPill"); return p && p.targetWidth === 330; }, 1000, "device width");
			click(v, "scene:music");
			tryVerify(() => { const p = findChild(v, "previewPill"); return p && p.targetWidth === 340; }, 1000, "open player");
			compare(part(v, "previewStage").height, 190);
			click(v, "previewPlayerToggle");
			tryVerify(() => { const p = findChild(v, "previewPill"); return p && p.targetWidth === 230; }, 1000, "collapsed");
		}

		function test_dockPreviewFollowsSettings() {
			const v = make("dock");
			v.apps = [{ name: "Files", icon: "" }];
			click(v, "preview:fold");
			tryVerify(() => findChild(v, "dockTile:Files") !== null, 1000, "app tile");
			verify(findChild(v, "dockTile:Trash") !== null, "extras on the left");
			fakeStore.set("bloom-enabled-modules", []);
			tryVerify(() => { const t = findChild(v, "previewDockOff"); return t && t.visible; }, 1000, "off");
		}

		function test_overlayPreview() {
			const v = make("overlays");
			click(v, "preview:fold");
			tryVerify(() => { const e = findChild(v, "previewEdge"); return e && e.visible; }, 1000, "edge marker");
			fakeStore.set("bloom-volume-hud-enabled", false);
			tryVerify(() => { const t = findChild(v, "previewHudOff"); return t && t.visible; }, 1000, "off");
			compare(findChild(v, "previewHudOff").text, "Volume HUD is off");
		}

		function test_systemPagesShowInTheSidebar() {
			const v = make();
			click(v, "tab:display");
			compare(part(v, "heading").text, "Display");
			verify(!part(v, "featurePreview").visible);
			verify(part(v, "page:display").visible);
		}

		function test_displayChangesGoThroughTheStore() {
			fakeSys.calls = [];
			const v = make("display");
			click(v, "mode:eDP-1");
			click(v, "option:1280x720@60.00Hz");
			compare(fakeSys.calls, [["monitor", "eDP-1", "1280x720@60.00Hz", 1]]);
		}

		function test_windowsPageWritesHyprland() {
			fakeSys.calls = [];
			const v = make("hyprland");
			click(v, "animations");
			compare(fakeSys.calls, [["hypr", "animations.enabled", false]]);
		}

		function test_updatesCountsAndRuns() {
			fakeSys.calls = [];
			const v = make("updates");
			compare(findChild(part(v, "runUpdates"), "label").text, "3 Updates Available");
			click(v, "runUpdates");
			compare(fakeSys.calls, [["updates"]]);
		}

		// Leaving a tall system page left its height behind, pushing Bloom's
		// tabs and the connection panels down the page.
		function test_noGapAfterLeavingASystemPage() {
			const v = make("hyprland");
			waitForRendering(host);
			v.tab = "general";
			waitForRendering(host);
			const preview = part(v, "featurePreview"), row = part(v, "row:Launch at Login");
			const gap = row.mapToItem(v, 0, 0).y - (preview.mapToItem(v, 0, 0).y + preview.height);
			fuzzyCompare(gap, 40, 3, "only the group label sits between them");
		}

		function test_tabReachesControls() {
			const v = make();
			waitForRendering(host);
			part(v, "time24").forceActiveFocus();
			keyClick(Qt.Key_Space);
			compare(fakeStore.values["bloom-time-format-24h"], true);
			keyClick(Qt.Key_Tab);
			verify(!part(v, "time24").activeFocus, "tab moves on");
		}

		function test_sliderKeys() {
			const v = make();
			part(v, "battery").forceActiveFocus();
			keyClick(Qt.Key_Right);
			compare(fakeStore.values["bloom-low-battery-threshold"], 25);
			keyClick(Qt.Key_Home);
			compare(fakeStore.values["bloom-low-battery-threshold"], 5);
			keyClick(Qt.Key_End);
			compare(fakeStore.values["bloom-low-battery-threshold"], 50);
		}

		function test_selectKeys() {
			const v = make("appearance");
			part(v, "themeMode").forceActiveFocus();
			keyClick(Qt.Key_Return);
			verify(part(v, "selectPopup").visible);
			keyClick(Qt.Key_Down);
			keyClick(Qt.Key_Return);
			compare(fakeStore.values["bloom-theme-mode"], "light");
			verify(part(v, "themeMode").activeFocus, "focus comes back");
			keyClick(Qt.Key_Return);
			keyClick(Qt.Key_Escape);
			verify(!part(v, "selectPopup").visible);
		}

		function test_pageShortcuts() {
			const v = make("display");
			waitForRendering(host);
			v.forceActiveFocus();
			keyClick(Qt.Key_PageDown, Qt.ControlModifier);
			compare(v.tab, "sound");
			keyClick(Qt.Key_PageUp, Qt.ControlModifier);
			compare(v.tab, "display");
		}

		function test_actionRowFromTheKeyboard() {
			const v = make();
			const restart = spy(v, "restartRequested");
			part(v, "restart").forceActiveFocus();
			keyClick(Qt.Key_Return);
			compare(restart.count, 1);
		}

		function test_controlsHaveNames() {
			const v = make();
			compare(part(v, "time24").accessibleName, "24-Hour Time");
			compare(part(v, "battery").accessibleName, "Low Battery Alert");
		}

		function test_displayChangeAsksToKeep() {
			fakeSys.calls = [];
			const v = make("display");
			verify(!part(v, "keepDisplay").visible);
			fakeSys.pendingDisplay = { name: "eDP-1" };
			verify(part(v, "keepDisplay").visible);
			compare(part(v, "keepCountdown").text, "Reverting in 15 seconds");
			click(v, "displayRevert");
			compare(fakeSys.calls, [["revert"]]);
			verify(!part(v, "keepDisplay").visible);
		}

		function test_pagesShowLiveValues() {
			const v = make("hyprland");
			compare(part(v, "gapsIn").value, 9);
			compare(findChild(part(v, "row:Inner Gaps"), "desc").text, "9 px between windows");
		}

		function test_volumeProtectionRows() {
			const v = make("overlays");
			verify(!part(v, "maxJump").visible);
			fakeStore.set("bloom-volume-protection-enabled", true);
			verify(part(v, "maxJump").visible);
		}

		function test_networkConnectsWithAPassword() {
			fakeNet.calls = [];
			const v = make("network");
			click(v, "net:Cafe");
			const field = part(v, "password:Cafe");
			verify(field.visible);
			field.text = "secret";
			click(v, "netConnect:Cafe");
			compare(fakeNet.calls[fakeNet.calls.length - 1], ["connect", "Cafe", "secret"]);
		}

		function test_networkDisconnects() {
			fakeNet.calls = [];
			const v = make("network");
			click(v, "net:Home");
			click(v, "netDisconnect:Home");
			compare(fakeNet.calls[fakeNet.calls.length - 1], ["disconnect", "Home"]);
		}

		function test_bluetoothPageActs() {
			fakeBt.calls = [];
			const v = make("bluetooth");
			click(v, "device:Buds");
			click(v, "deviceConnect:Buds");
			// The last test's page stops discovery as it goes.
			const calls = () => fakeBt.calls.filter(c => c[0] !== "discover");
			compare(calls()[0], ["connected", "/a", true]);
			click(v, "nearby:Mouse");
			compare(calls()[1], ["pair", "/b"]);
		}

		function test_pairingConfirm() {
			fakeBt.calls = [];
			const v = make("bluetooth");
			fakeBt.pairing = "/b";
			fakeBt.prompt = { kind: "confirm", pin: "123456" };
			compare(part(v, "pairPrompt").text, "Does the device show 123456?");
			click(v, "pairYes");
			compare(fakeBt.calls.filter(c => c[0] !== "discover")[0][0], "respond");
			fakeBt.pairing = "";
			fakeBt.prompt = null;
		}

		// The same page object serves both tabs.
		function test_movingToBluetoothStartsWatchingIt() {
			const v = make("network");
			fakeBt.holds = [];
			fakeNet.holds = [];
			v.tab = "bluetooth";
			compare(fakeNet.holds, [false]);
			compare(fakeBt.holds, [true]);
		}

		function test_notYetKnownIsNotAbsent() {
			const v = make("bluetooth");
			fakeBt.loaded = false;
			fakeBt.available = false;
			compare(findChild(part(v, "row:Bluetooth"), "desc").text, "Checking…");
			verify(!part(v, "bluetooth").enabled);
			fakeBt.loaded = true;
			compare(findChild(part(v, "row:Bluetooth"), "desc").text, "No Bluetooth adapter found");
			fakeBt.available = true;
		}

		function test_noInventedHyprlandValues() {
			const v = make("hyprland");
			fakeSys.hyprLoaded = false;
			verify(part(v, "hyprNotice").visible);
			verify(!part(v, "gapsIn").enabled);
			verify(!part(v, "animations").enabled);
			fakeSys.hyprLoaded = true;
			verify(part(v, "gapsIn").enabled);
		}

		function test_failuresAreShown() {
			const v = make();
			verify(!part(v, "errorBanner").visible);
			fakeSys.lastError = "Couldn't change automatic time";
			verify(part(v, "errorBanner").visible);
			compare(part(v, "errorText").text, "Couldn't change automatic time");
			fakeSys.lastError = "";
			v.saveError = "bloom-scale: too big";
			compare(part(v, "errorText").text, "bloom-scale: too big");
		}

		function test_ntpWaitsForTheSystem() {
			fakeSys.calls = [];
			fakeSys.ntp = false;
			const v = make("time");
			click(v, "ntp");
			compare(fakeSys.calls, [["ntp", true]]);
			verify(!part(v, "ntp").checked, "stays until the read-back says otherwise");
		}

		function test_aiKeySavesAndClears() {
			fakeSys.calls = [];
			const v = make("ai");
			compare(findChild(part(v, "aiKeyRow"), "desc").text, "Not set");
			const field = part(v, "aiKey");
			field.text = "  k3y  ";
			click(v, "aiSave");
			compare(fakeSys.calls, [["key", "k3y"]]);
			compare(field.text, "", "the key doesn't stay on screen");
		}

		function test_aiKeyIsHidden() {
			const v = make("ai");
			verify(part(v, "aiKey").secret);
		}

		function test_closeSignals() {
			const v = make();
			const closed = spy(v, "closeRequested");
			click(v, "close");
			compare(closed.count, 1);
		}
	}
}
