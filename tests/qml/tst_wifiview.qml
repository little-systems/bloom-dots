import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's Wi-Fi panel (WifiPanel.tsx, QuickPanel.css): header, empty states,
// rows with their sublines and lock badge, expanded actions with the
// password field, error text, and the footer.
Item {
	id: host
	width: 400
	height: 400

	readonly property var nets: [
		{ ssid: "Office", signal: 80, security: "wpa2", connected: true, saved: true },
		{ ssid: "Home", signal: 55, security: "wpa2", connected: false, saved: true },
		{ ssid: "Cafe", signal: 30, security: "wpa2", connected: false, saved: false },
		{ ssid: "Free", signal: 10, security: "open", connected: false, saved: false },
		{ ssid: "Corp", signal: 60, security: "enterprise", connected: false, saved: false }
	]

	Component {
		id: viewComponent
		WifiView { width: 350; height: 264; enabled: true; available: true; networks: host.nets }
	}

	TestCase {
		name: "WifiView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v);
			return v;
		}
		// Rows are built on the next frame.
		function part(v, name) {
			tryVerify(() => findChild(v, name) !== null, 1000, name);
			return findChild(v, name);
		}
		function click(v, name) {
			// Lists and positioners lay out on the next polish: let a frame
			// render before reading where things are.
			waitForRendering(host);
			const it = part(v, name);
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
		}
		// A row's main line (an expanded row's centre is its actions).
		function clickRow(v, ssid) {
			waitForRendering(host);
			const it = findChild(part(v, "row:" + ssid), "main");
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
		}
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}

		function test_header() {
			const v = make({ scanning: true });
			compare(findChild(part(v, "header"), "title").text, "Wi-Fi");
			const refresh = part(v, "refresh");
			compare(refresh.icon, "refresh-cw");
			verify(refresh.spinning, "spins while scanning");
			verify(!refresh.enabled, "no second scan while one runs");
			compare(part(v, "switch").checked, true);
			const back = spy(v, "back"), toggle = spy(v, "toggle");
			click(v, "back");
			click(v, "switch");
			compare([back.count, toggle.count], [1, 1]);
		}

		function test_emptyStates() {
			compare(findChild(part(make({ enabled: false }), "empty"), "label").text, "Wi-Fi is off");
			compare(findChild(part(make({ networks: [], scanning: true }), "empty"), "label").text, "Looking for networks…");
			compare(findChild(part(make({ networks: [], scanning: false }), "empty"), "label").text, "No networks found");
		}

		function test_rowsAndBadges() {
			const v = make({ busy: "Home" });
			const sub = ssid => findChild(part(v, "row:" + ssid), "sub").text;
			compare([sub("Office"), sub("Home"), sub("Cafe"), sub("Free")], ["Connected", "Connecting…", "Secured", "Open"]);
			compare(part(v, "row:Office").icon, "wifi");
			compare(part(v, "row:Home").icon, "wifi-high");
			compare(part(v, "row:Cafe").icon, "wifi-low");
			compare(part(v, "row:Free").icon, "wifi-zero");
			compare(part(v, "row:Cafe").badge, "lock");
			compare(part(v, "row:Free").badge, "");
			verify(part(v, "row:Office").active, "the connected network is active");
		}

		function test_newNetworkTakesAPassword() {
			const v = make();
			const connect = spy(v, "connectRequested");
			clickRow(v, "Cafe");
			verify(part(v, "row:Cafe").expanded);
			const field = part(v, "password");
			verify(!part(v, "connect").enabled, "Connect waits for a password");
			verify(!findChild(v, "forget"), "an unsaved network has nothing to forget");
			field.text = "hunter22";
			verify(part(v, "connect").enabled);
			click(v, "connect");
			compare(connect.count, 1);
			compare(Array.from(connect.signalArguments[0]), ["Cafe", "hunter22"]);
		}

		function test_savedNetworkConnectsAndForgets() {
			const v = make();
			const connect = spy(v, "connectRequested"), forget = spy(v, "forgetRequested");
			clickRow(v, "Home");
			verify(!findChild(v, "password"), "a saved network needs no password");
			click(v, "connect");
			compare(Array.from(connect.signalArguments[0]), ["Home", ""]);
			click(v, "forget");
			compare(Array.from(forget.signalArguments[0]), ["Home"]);
		}

		function test_connectedNetworkDisconnects() {
			const v = make();
			const disconnect = spy(v, "disconnectRequested");
			clickRow(v, "Office");
			verify(!findChild(v, "connect"));
			click(v, "disconnect");
			compare(Array.from(disconnect.signalArguments[0]), ["Office"]);
		}

		function test_rowsCollapseOneAnother() {
			const v = make();
			clickRow(v, "Cafe");
			clickRow(v, "Home");
			verify(!part(v, "row:Cafe").expanded);
			verify(part(v, "row:Home").expanded);
			clickRow(v, "Home");
			verify(!part(v, "row:Home").expanded, "a second click collapses");
		}

		// A work network with sign-in is for the settings tool, as Bloom
		// hands it to Windows Settings.
		function test_enterpriseGoesToSettings() {
			const v = make({ settingsAvailable: true, height: 360 });
			const open = spy(v, "openSettings");
			clickRow(v, "Corp");
			verify(!findChild(v, "password"));
			verify(!findChild(v, "connect"));
			compare(part(v, "note").text, "This network needs a sign-in your network settings handle.");
			click(v, "openSettingsButton");
			compare(open.count, 1);
		}

		function test_errorText() {
			const v = make();
			clickRow(v, "Cafe");
			v.error = { ssid: "Cafe", code: "wrong-password" };
			const e = part(v, "error:Cafe");
			compare(e.text, "Wrong password");
			compare(String(e.color), "#ff8a80");
			compare(e.font.pixelSize, 10);
		}

		// Bloom clears the error when a row opens or closes.
		function test_rowChangeClearsTheError() {
			const v = make({ error: { ssid: "Cafe", code: "timeout" } });
			const cleared = spy(v, "errorCleared");
			clickRow(v, "Home");
			verify(cleared.count >= 1);
		}

		// A saved network whose stored password stopped working asks for one.
		function test_savedNetworkWithAStalePasswordAsksForOne() {
			const v = make();
			clickRow(v, "Home");
			click(v, "connect");
			v.busy = "Home";
			v.busy = "";
			v.error = { ssid: "Home", code: "wrong-password" };
			verify(part(v, "password"), "the field appears");
		}

		// Bloom collapses the row once a connect succeeds.
		function test_successCollapses() {
			const v = make();
			clickRow(v, "Home");
			click(v, "connect");
			v.busy = "Home";
			v.busy = "";
			tryVerify(() => !part(v, "row:Home").expanded, 500, "collapsed once the change ends without an error");
		}

		// Bloom's field autofocuses, and focusing it pins the notch open.
		function test_passwordFieldPinsTheNotch() {
			const v = make();
			verify(!v.pinned);
			clickRow(v, "Cafe");
			verify(part(v, "password").focused, "the field takes focus");
			verify(v.pinned, "typing keeps the notch open");
			clickRow(v, "Cafe");
			verify(!v.pinned, "collapsing lets it close");
		}

		// Bloom's panel as Chromium lays it out (tools/bloom-audit/
		// record-panels.cjs; the .qp box at the pill's 12, 36), with Cafe
		// Guest (open) expanded.
		function test_matchesBloomsLayout() {
			const v = make({ height: 264, width: 326, networks: [
				{ ssid: "Phone", signal: 90, security: "wpa2", connected: true, saved: true },
				{ ssid: "Jio", signal: 62, security: "wpa2", connected: false, saved: true },
				{ ssid: "Cafe Guest", signal: 40, security: "open", connected: false, saved: false },
				{ ssid: "Office", signal: 20, security: "enterprise", connected: false, saved: false }] });
			clickRow(v, "Cafe Guest");
			waitForRendering(host);
			function at(item, x, y, w, h, what, tolerance) {
				const t = tolerance || 0.51;
				const p = item.mapToItem(v, 0, 0);
				fuzzyCompare(p.x, x, t, what + " x");
				fuzzyCompare(p.y, y, t, what + " y");
				if (w !== undefined) fuzzyCompare(item.width, w, t, what + " width");
				if (h !== undefined) fuzzyCompare(item.height, h, t, what + " height");
			}
			at(part(v, "header"), 12, 4, 302, 24, "header");
			at(part(v, "refresh"), 252, 4, 24, 24, "refresh");
			at(findChild(part(v, "switch"), "track"), 284, 7.5, 30, 17, "switch track");
			const row = name => part(v, "row:" + name);
			at(row("Phone"), 12, 34, 300, 35.6, "first row");
			at(findChild(row("Phone"), "icon"), 20, 39.8, 24, 24, "row icon");
			at(findChild(row("Phone"), "name"), 53, 39, undefined, undefined, "row name");
			at(findChild(row("Phone"), "sub"), 53, 52.8, undefined, undefined, "row sub");
			at(findChild(row("Phone"), "badge"), 293, 46.3, 11, 11, "lock badge");
			at(row("Jio"), 12, 71.6, 300, 35.6, "second row");
			at(row("Cafe Guest"), 12, 109.3, 300, 67.6, "expanded row");
			// Its width follows its text, which headless Chromium (the
			// reference) lays out on whole-pixel glyph advances.
			at(part(v, "connect"), 53, 144.9, 64, 24, "Connect", 1.5);
			at(row("Office"), 12, 178.9, 300, 35.6, "row after it");
		}

		function test_footer() {
			verify(!part(make({ settingsAvailable: false }), "footer").visible, "hidden without a settings tool");
			const v = make({ settingsAvailable: true });
			const footer = part(v, "footer");
			verify(footer.visible);
			compare(footer.text, "More Wi-Fi settings");
			const open = spy(v, "openSettings");
			click(v, "footer");
			compare(open.count, 1);
		}
	}
}
