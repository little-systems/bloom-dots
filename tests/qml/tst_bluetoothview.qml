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
		function part(v, name) {
			const it = findChild(v, name);
			verify(it, name);
			return it;
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
