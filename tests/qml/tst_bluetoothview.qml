import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's Bluetooth panel (BluetoothPanel.tsx): paired devices with their
// actions and "Looks like" chips, the "Add a device" view that pairs nearby
// devices with the agent's passkey prompts, error text and the footer.
Item {
	id: host
	width: 400
	height: 420

	readonly property var paired: [
		{ path: "/a", name: "Buds", kind: "audio", connected: true, battery: 80 },
		{ path: "/k", name: "Keys", kind: "keyboard", connected: true, battery: null },
		{ path: "/m", name: "Mouse", kind: "mouse", connected: false, battery: null }
	]
	readonly property var nearbyDevices: [
		{ path: "/p", name: "Phone", kind: "phone" },
		{ path: "/s", name: "Speaker", kind: "audio" }
	]

	Component {
		id: viewComponent
		BluetoothView { width: 350; height: 360; enabled: true; available: true; devices: host.paired; nearby: host.nearbyDevices }
	}

	TestCase {
		name: "BluetoothView"
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
			waitForRendering(host);
			const it = part(v, name);
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
		}
		function clickRow(v, id) {
			waitForRendering(host);
			const it = findChild(part(v, "row:" + id), "main");
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
		}
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}
		function args(s, i) { return Array.from(s.signalArguments[i]); }

		function test_header() {
			const v = make();
			compare(findChild(part(v, "header"), "title").text, "Bluetooth");
			compare(part(v, "add").icon, "plus");
			compare(part(v, "switch").checked, true);
			const back = spy(v, "back"), toggle = spy(v, "toggle");
			click(v, "back");
			click(v, "switch");
			compare([back.count, toggle.count], [1, 1]);
			verify(!part(make({ enabled: false }), "add").enabled, "nothing to add with the radio off");
		}

		function test_emptyStates() {
			compare(findChild(part(make({ enabled: false }), "empty"), "label").text, "Bluetooth is off");
			const v = make({ devices: [] });
			compare(findChild(part(v, "empty"), "label").text, "No paired devices");
			const discover = spy(v, "discover");
			click(v, "addDevice");
			verify(v.adding, "Add device opens the add view");
			compare(args(discover, 0), [true]);
		}

		function test_rows() {
			const v = make({ busy: "/m" });
			const sub = id => findChild(part(v, "row:" + id), "sub").text;
			compare([sub("/a"), sub("/k"), sub("/m")], ["Connected · 80%", "Connected", "Connecting…"]);
			compare(part(v, "row:/a").icon, "headphones");
			compare(part(v, "row:/k").icon, "keyboard");
			compare(part(v, "row:/m").icon, "mouse");
			verify(part(v, "row:/a").active);
			verify(!part(v, "row:/m").active);
			v.busy = "/a";
			compare(sub("/a"), "Disconnecting…");
			v.busy = "";
			compare(sub("/m"), "Not connected");
		}

		function test_connectDisconnectRemove() {
			const v = make();
			const connect = spy(v, "connectRequested"), remove = spy(v, "removeRequested");
			clickRow(v, "/m");
			click(v, "connect");
			compare(args(connect, 0), ["/m", true]);
			click(v, "remove");
			compare(args(remove, 0), ["/m"]);
			clickRow(v, "/k");
			verify(!findChild(v, "connect"));
			click(v, "disconnect");
			compare(args(connect, 1), ["/k", false]);
		}

		// An audio device's "Looks like" chips; picking Bloom's own guess clears the pick.
		function test_looksLike() {
			const v = make({ looks: ({ Buds: "speaker" }) });
			const chosen = spy(v, "lookChosen");
			clickRow(v, "/a");
			verify(part(v, "look-speaker").on, "the pick shows");
			verify(!part(v, "look-headphones").on);
			click(v, "look-neckband");
			compare(args(chosen, 0), ["Buds", "neckband"]);
			const guess = v.guessFor(host.paired[0]);
			click(v, "look-" + guess);
			compare(args(chosen, 1), ["Buds", ""]);
			clickRow(v, "/k");
			verify(!findChild(v, "look-speaker"), "only audio devices have looks");
		}

		function test_addViewHeaderAndBack() {
			const v = make();
			const discover = spy(v, "discover"), back = spy(v, "back");
			click(v, "add");
			compare(findChild(part(v, "header"), "title").text, "Add a device");
			verify(!findChild(v, "add") || !findChild(v, "add").visible, "no add button while adding");
			click(v, "back");
			verify(!v.adding, "back leaves the add view");
			compare(back.count, 0, "and stays in the panel");
			compare(discover.count, 2);
			compare(args(discover, 1), [false]);
		}

		function test_lookingForDevices() {
			const v = make({ nearby: [] });
			click(v, "add");
			const empty = part(v, "empty");
			compare(findChild(empty, "label").text, "Looking for devices. Make sure yours is in pairing mode.");
			compare(findChild(empty, "glyph").name, "loader-circle");
		}

		// The session couldn't run: say so rather than spin for ever.
		function test_lookingFailed() {
			const v = make({ nearby: [], lookFailed: true });
			click(v, "add");
			const empty = part(v, "empty");
			compare(findChild(empty, "label").text, "Couldn't look for devices");
			compare(findChild(empty, "glyph").visible, false);
		}

		// BlueZ refreshes the list several times a second while it looks: a
		// new array must keep the rows and where the list is scrolled to.
		function test_refreshKeepsTheScroll() {
			const many = extra => Array.from({ length: 14 + extra }, (_, i) => ({ path: "/d" + i, name: "Device " + i, kind: "phone" }));
			const v = make({ nearby: many(0), height: 264 });
			click(v, "add");
			waitForRendering(host);
			const list = part(v, "nearbyList");
			const view = part(list, "view");
			const row = part(v, "row:/d0");
			const p = list.mapToItem(host, 100, 60);
			mouseWheel(host, p.x, p.y, 0, -240);
			tryVerify(() => view.contentY > 50, 1000, "the wheel scrolls");
			tryVerify(() => Math.abs(view.contentY - 200) < 0.2, 2000, "glide settles before refresh");
			const y = view.contentY;
			v.nearby = many(0);
			v.nearby = many(1);
			waitForRendering(host);
			// ListView rounds a fractional glide position when it lays out a new row.
			fuzzyCompare(view.contentY, y, 1, "still scrolled");
			compare(part(v, "row:/d0"), row, "the same row, not a rebuilt one");
			verify(findChild(v, "row:/d14"), "the new device joined");
			v.nearby = many(0).slice(1);
			waitForRendering(host);
			verify(!findChild(v, "row:/d0"), "a device that left is gone");
			compare(part(v, "row:/d6").name, "Device 6");
		}

		// Bloom's handleWheel leaves .qp-list alone: a short list still
		// keeps the wheel from switching panels.
		function test_listOwnsTheWheel() {
			let reached = 0;
			const catcher = createTemporaryQmlObject("import QtQuick; WheelHandler { target: null }", host);
			catcher.wheel.connect(() => reached++);
			const v = make({ height: 264 });
			const list = part(v, "list");
			part(v, "row:/m");
			const p = list.mapToItem(host, 100, 20);
			mouseWheel(host, p.x, p.y, 0, -120);
			wait(50);
			compare(reached, 0);
			compare(v.scrollY, 0, "nothing to scroll");
		}

		// .qp-list::-webkit-scrollbar: 4 px, once the list overflows.
		function test_scrollbar() {
			const short = make({ height: 264 });
			part(short, "row:/m");
			verify(!part(short, "list").overflowing);
			short.visible = false;
			const v = make({ height: 264, devices: Array.from({ length: 14 }, (_, i) => ({ path: "/d" + i, name: "D" + i, kind: "phone", connected: false, battery: null })) });
			const list = part(v, "list");
			tryVerify(() => list.overflowing, 500);
			const bar = part(list, "scrollbar");
			verify(bar.visible);
			compare(bar.width, 4);
			fuzzyCompare(part(v, "row:/d0").width, list.width - 4 - 2, 0.01);
		}

		function test_pairing() {
			const v = make();
			const pair = spy(v, "pairRequested");
			click(v, "add");
			compare(findChild(part(v, "row:/p"), "sub").text, "Click to pair");
			clickRow(v, "/p");
			compare(args(pair, 0), ["/p"]);
			v.pairing = "/p";
			const row = part(v, "row:/p");
			compare(findChild(row, "sub").text, "Pairing…");
			compare(row.badge, "loader-circle");
			verify(row.badgeSpinning);
			verify(!part(v, "row:/s").clickable, "one pairing at a time");
			verify(v.pinned, "pairing keeps the notch open");
		}

		function test_confirmPrompt() {
			const v = make();
			const respond = spy(v, "respond");
			click(v, "add");
			v.pairing = "/p";
			v.prompt = { id: "/p", kind: "confirm", pin: "123456" };
			verify(part(v, "promptNote").text.indexOf("123456") >= 0);
			verify(part(v, "promptNote").text.startsWith("Does the device show"));
			click(v, "yes");
			compare(args(respond, 0), [true, ""]);
			v.prompt = { id: "/p", kind: "confirm", pin: "123456" };
			click(v, "no");
			compare(args(respond, 1), [false, ""]);
		}

		function test_displayPrompt() {
			const v = make();
			click(v, "add");
			v.pairing = "/p";
			v.prompt = { id: "/p", kind: "display", pin: "004521" };
			const note = part(v, "promptNote");
			verify(note.text.indexOf("004521") >= 0);
			verify(note.text.startsWith("Type "));
			verify(note.text.indexOf("then press Enter on it.") > 0);
		}

		function test_providePrompt() {
			const v = make();
			const respond = spy(v, "respond");
			click(v, "add");
			v.pairing = "/p";
			v.prompt = { id: "/p", kind: "provide", pin: null };
			compare(part(v, "pin").placeholder, "PIN shown on the device");
			verify(!part(v, "pairButton").enabled, "Pair waits for a PIN");
			part(v, "pin").text = "1234";
			click(v, "pairButton");
			compare(args(respond, 0), [true, "1234"]);
			v.prompt = { id: "/p", kind: "provide", pin: null };
			click(v, "cancel");
			compare(args(respond, 1), [false, ""]);
		}

		// Bloom leaves the add view once a device pairs.
		function test_pairedLeavesTheAddView() {
			const v = make();
			const discover = spy(v, "discover");
			click(v, "add");
			clickRow(v, "/p");
			v.pairing = "/p";
			v.pairing = "";
			tryVerify(() => !v.adding, 500, "back to the paired list");
			compare(args(discover, discover.count - 1), [false]);
		}

		function test_failedPairingStaysWithItsError() {
			const v = make();
			click(v, "add");
			clickRow(v, "/p");
			v.pairing = "/p";
			v.error = { id: "/p", code: "timeout" };
			v.pairing = "";
			wait(50);
			verify(v.adding, "a failure stays in the add view");
			const e = part(v, "error:/p");
			compare(e.text, "The device didn't answer in time");
			compare(String(e.color), "#ff8a80");
		}

		// Bloom's panel as Chromium lays it out (tools/bloom-audit/
		// record-panels.cjs; the .qp box at the pill's 12, 36), AirPods Pro
		// expanded: "Looks like" and five chips over two lines, then the buttons.
		function test_matchesBloomsLayout() {
			const v = make({ width: 326, height: 264, devices: [
				{ path: "/a", name: "AirPods Pro", kind: "audio", connected: true, battery: 72 },
				{ path: "/m", name: "MX Master 3", kind: "mouse", connected: true, battery: 15 }] });
			clickRow(v, "/a");
			waitForRendering(host);
			function at(item, x, y, w, h, what, tolerance) {
				const t = tolerance || 0.51;
				const p = item.mapToItem(v, 0, 0);
				fuzzyCompare(p.x, x, t, what + " x");
				fuzzyCompare(p.y, y, t, what + " y");
				if (w !== undefined) fuzzyCompare(item.width, w, t, what + " width");
				if (h !== undefined) fuzzyCompare(item.height, h, t, what + " height");
			}
			at(part(v, "add"), 252, 4, 24, 24, "add");
			at(part(v, "row:/a"), 12, 34, 300, 117.6, "expanded row");
			at(part(v, "looksNote"), 53, 73.6, undefined, undefined, "Looks like");
			verify(part(v, "look-stem-buds").on, "Bloom's guess for AirPods Pro");
			// Chip boxes follow their text. The reference is headless Chromium,
			// which rounds every glyph advance to a whole pixel; Chromium on
			// Windows and the shell don't (same font: tst_fonts). At 10 px that
			// is up to ~1.5 px a word, so text-placed boxes get 2 px (3 for the
			// third chip on a line, which carries two words of it).
			at(part(v, "look-headphones"), 103, 69.6, 79, 20, "Headphones chip", 2);
			at(part(v, "look-round-buds"), 186, 69.6, 58, 20, "Earbuds chip", 2);
			at(part(v, "look-stem-buds"), 53, 93.6, 71, 20, "Stem buds chip (second line)", 2);
			at(part(v, "look-neckband"), 128, 93.6, 68, 20, "Neckband chip", 2);
			at(part(v, "look-speaker"), 200, 93.6, 59, 20, "Speaker chip", 3);
			at(part(v, "disconnect"), 53, 119.6, 79, 24, "Disconnect", 2);
			at(part(v, "remove"), 138, 119.6, 64, 24, "Remove", 2);
			at(part(v, "row:/m"), 12, 153.6, 300, 35.6, "next row");
		}

		function test_footer() {
			verify(!part(make({ settingsAvailable: false }), "footer").visible);
			const v = make({ settingsAvailable: true });
			compare(part(v, "footer").text, "More Bluetooth settings");
			const open = spy(v, "openSettings");
			click(v, "footer");
			compare(open.count, 1);
		}
	}
}
