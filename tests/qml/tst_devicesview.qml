import QtQuick
import QtTest
import "../../shell/modules/notch"
import "../../shell/services/devices.js" as Devices

// Bloom's battery hub (components/ConnectedDevicesPanel.tsx, QuickPanel.css .bh-*).
Item {
	id: host
	width: 400
	height: 400

	QtObject {
		id: colours
		property color text: "#f0f0f0"
		property color textMuted: "#909090"
		property color groupBg: "#202020"
		property color border: "#404040"
		property color bgExpanded: "#080808"
		property color scrollbarThumb: "#303030"
	}

	readonly property var sample: Devices.entries(
		{ present: true, level: 73, charging: true, secondsToFull: 0 },
		[
			{ path: "/buds", name: "AirPods Pro", connected: true, kind: "audio", battery: null, buds: { left: 80, right: 15 } },
			{ path: "/mouse", name: "A mouse with a name far too long for its row in the panel", connected: true, kind: "mouse", battery: 55, buds: {} },
			{ path: "/pad", name: "Pad", connected: true, kind: "gamepad", battery: null, buds: {} }
		],
		[], {})

	// The panel's content box: 350 less 12 px each side, under the clock strip.
	DevicesView {
		id: view
		theme: colours
		width: 326
		height: 264
		threshold: 20
		entries: host.sample
		pcStatus: "Charging"
	}

	DevicesView {
		id: empty
		x: 0
		y: 300
		theme: colours
		width: 326
		height: 100
		entries: []
	}

	SignalSpy { id: looks; target: view; signalName: "lookChosen" }

	TestCase {
		name: "DevicesView"
		when: windowShown

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function at(item) {
			return item.mapToItem(view, 0, 0);
		}

		function centre(item) {
			return item.mapToItem(host, item.width / 2, item.height / 2);
		}

		function cleanup() {
			mouseMove(host, 395, 395);
			wait(100);
		}

		function test_header() {
			const icon = part(view, "titleIcon");
			compare(icon.width, 22);
			compare(icon.radius, 11);
			compare(icon.color, colours.groupBg);
			compare(at(icon).y, 4);
			const title = part(view, "title");
			compare(title.text, "Connected devices");
			compare(title.font.pixelSize, 12);
			compare(title.font.weight, Font.DemiBold);
			// 22 px icon + 4 px margin + 4 px gap.
			compare(at(title).x, 30);
		}

		function test_groups() {
			// The right bud at 15% puts the AirPods under "Needs charging".
			compare(part(view, "group-low").title, "Needs charging");
			const title = part(part(view, "group-low"), "groupTitle");
			compare(title.text, "NEEDS CHARGING");
			compare(title.pixelSize, 9.5);
			compare(title.color, Qt.color("#ff453a"));
			compare(at(title).x, 8);
			const pc = part(part(view, "group-pc"), "groupTitle");
			compare(pc.text, "THIS PC");
			compare(pc.color, colours.textMuted);
			verify(findChild(view, "group-accessories"));
			// The list starts 6 px under the 22 px header.
			compare(at(part(view, "group-low")).y, 4 + 22 + 6);
		}

		function test_rowLayout() {
			const row = part(view, "row-pc");
			compare(row.height, 4 + 30 + 4);
			const art = part(row, "art");
			compare(art.width, 30);
			compare(at(art).x - at(row).x, 8);
			compare(part(row, "pcGlyph").name, "laptop");
			compare(part(row, "pcGlyph").size, 18);
			const name = part(row, "name");
			compare(name.text, "This PC");
			compare(name.font.pixelSize, 11);
			compare(at(name).x - at(row).x, 8 + 30 + 9);
			compare(part(row, "sub").text, "Charging");
			compare(part(row, "sub").pixelSize, 9.5);
		}

		function test_meter() {
			const row = part(view, "row-pc");
			const meter = part(row, "meter-0");
			compare(meter.width, 40);
			// Flush with the row's right padding.
			compare(at(meter).x + 40, at(row).x + row.width - 8);
			const value = part(meter, "value");
			compare(value.text, "73%");
			compare(value.pixelSize, 10.5);
			verify(part(meter, "bolt").visible, "charging shows the bolt");
			compare(part(meter, "bolt").size, 9);
			const bar = part(meter, "bar");
			compare(bar.height, 3);
			compare(bar.radius, 2);
			compare(part(meter, "fill").color, Qt.color("#32d74b"));
			tryCompare(part(meter, "fill"), "width", 40 * 0.73, 1000);
		}

		function test_budsAndLow() {
			const row = part(view, "row-/buds");
			compare(part(row, "sub").text, "Each bud and the case");
			const left = part(row, "meter-0");
			const right = part(row, "meter-1");
			compare(part(left, "label").text, "L");
			compare(part(right, "label").text, "R");
			compare(part(right, "value").color, Qt.color("#ff453a"));
			compare(part(right, "fill").color, Qt.color("#ff453a"));
			compare(part(left, "value").color, colours.text);
			// gap 8 between meters.
			compare(at(right).x - at(left).x, 48);
		}

		function test_unknownBattery() {
			const row = part(view, "row-/pad");
			const unknown = part(row, "unknown");
			compare(unknown.text, "No battery info");
			compare(unknown.pixelSize, 9.5);
			compare(unknown.color, colours.textMuted);
		}

		function test_longNameElides() {
			const row = part(view, "row-/mouse");
			verify(part(row, "name").truncated);
			verify(at(part(row, "name")).x + part(row, "name").width <= at(part(row, "meter-0")).x - 9);
		}

		function test_rowHover() {
			const row = part(view, "row-pc");
			const p = centre(row);
			mouseMove(host, p.x, p.y);
			compare(part(row, "rowBackground").color, colours.groupBg);
		}

		function test_audioRowOpensLooks() {
			const row = part(view, "row-/buds");
			compare(part(row, "pointer").cursorShape, Qt.PointingHandCursor);
			verify(!findChild(part(view, "row-pc"), "pointer"), "only audio rows are buttons");
			mouseClick(part(row, "rowBackground"));
			const chips = part(row, "looks");
			verify(chips.visible);
			compare(at(chips).x - at(row).x, 47);
			compare(part(row, "itemBackground").color, colours.groupBg);
			const stem = part(chips, "look-stem-buds");
			compare(stem.on, true, "AirPods guess stem buds");
			mouseClick(part(chips, "look-neckband"));
			compare(looks.count, 1);
			compare(looks.signalArguments[0][0], "AirPods Pro");
			compare(looks.signalArguments[0][1], "neckband");
			mouseClick(stem);
			compare(looks.signalArguments[1][1], "", "picking the guess clears the pick");
			mouseClick(part(row, "rowBackground"));
			tryVerify(() => !findChild(row, "looks"), 1000, "closing drops the choice");
		}

		function test_emptyState() {
			compare(part(empty, "label").text, "No devices connected");
		}

		function test_panelHeight() {
			// 36 strip + 4 + 22 header + 6 + the list + 8, as Bloom measures it.
			compare(view.panelHeight, 36 + 4 + 22 + 6 + part(view, "list").height + 8);
			compare(empty.panelHeight, 36 + 4 + 22 + 6 + 72 + 8);
		}
	}
}
