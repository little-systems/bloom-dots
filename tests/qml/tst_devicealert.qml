import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's device alert (App.tsx .device-alert, App.css): in a 330 x 76 pill
// with 12 px side padding, the alert's own padding 0 18 0 14 and gap 12.
Item {
	id: host
	width: 400
	height: 200

	DeviceAlert {
		id: alert
		width: 330
		height: 76
		textColor: "#f0f0f0"
		textMuted: "#909090"
		alert: ({ id: "/a", name: "AirPods Pro", art: "stem-buds", status: "Connected", connected: true, wired: false, bluetooth: true, battery: 72, buds: null, runId: 1 })
	}

	DeviceAlert {
		id: buds
		y: 100
		width: 330
		height: 76
		alert: ({ id: "/b", name: "Galaxy Buds", art: "round-buds", status: "Connected", connected: true, wired: false, bluetooth: true, battery: null, buds: { left: 80, right: 15 }, runId: 2 })
	}

	SignalSpy { id: clicks; target: alert; signalName: "clicked" }

	TestCase {
		name: "DeviceAlert"
		when: windowShown

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function at(item, root) {
			return item.mapToItem(root || alert, 0, 0);
		}

		function test_art() {
			const art = part(alert, "alertArt");
			compare(art.width, 60);
			compare(at(art).x, 26);
			compare(at(art).y, 8);
			compare(art.art, "stem-buds");
			compare(art.phase, "play");
			compare(art.runId, 1);
		}

		function test_text() {
			const name = part(alert, "alertName");
			compare(name.text, "AirPods Pro");
			compare(name.pixelSize, 13.5);
			compare(name.font.weight, Font.DemiBold);
			compare(name.color, Qt.color("#f0f0f0"));
			compare(at(name).x, 26 + 60 + 12);
			const status = part(alert, "alertStatus");
			compare(status.text, "Connected");
			compare(status.font.pixelSize, 12);
			compare(status.color, Qt.color("#909090"));
			// The name and status centred together, 2 px apart.
			fuzzyCompare(at(status).y - (at(name).y + name.height), 2, 0.01);
		}

		function test_ring() {
			const ring = part(alert, "alertRing");
			verify(ring.visible);
			compare(ring.width, 28);
			compare(ring.level, 72);
			// Flush with the right padding (330 - 12 - 18).
			compare(at(ring).x + 28, 300);
			compare(at(ring).y, 24);
		}

		function test_noRingWhenDisconnectedOrUnknown() {
			alert.alert = Object.assign({}, alert.alert, { connected: false, status: "Disconnected" });
			verify(!part(alert, "alertRing").visible);
			compare(part(alert, "alertArt").phase, "leave");
			alert.alert = Object.assign({}, alert.alert, { connected: true, status: "Connected", battery: null });
			verify(!part(alert, "alertRing").visible);
			alert.alert = Object.assign({}, alert.alert, { battery: 72 });
		}

		function test_budRings() {
			const row = part(buds, "alertBuds");
			verify(row.visible);
			verify(!part(buds, "alertRing").visible);
			const left = part(row, "bud-left");
			const right = part(row, "bud-right");
			compare(at(right, buds).x - at(left, buds).x, 28 + 7);
			compare(at(right, buds).x + 28, 300);
			compare(part(left, "budLabel").text, "L");
			compare(part(left, "budLabel").font.pixelSize, 9);
			compare(part(right, "ring").low, true, "15 % is low");
		}

		function test_click() {
			mouseClick(alert, 160, 38);
			compare(clicks.count, 1);
			compare(part(alert, "pointer").cursorShape, Qt.PointingHandCursor);
		}

		function test_fadesIn() {
			const fresh = createTemporaryObject(Qt.createComponent("../../shell/modules/notch/DeviceAlert.qml"), host, { width: 330, height: 76 });
			fresh.alert = alert.alert;
			verify(fresh.contentOpacity < 0.5);
			tryCompare(fresh, "contentOpacity", 1, 500);
		}
	}
}
