import QtQuick
import QtTest
import "../../shell/services/battery.js" as Battery
import "../../shell/modules/notch"

Item {
	id: host
	width: 80
	height: 20

	Rectangle { anchors.fill: parent; color: "black" }
	BatteryIcon { id: charging; level: 50; charging: true; threshold: 20 }
	BatteryIcon { id: low; x: 30; level: 15; threshold: 20; color: "white" }

	TestCase {
		name: "Battery"
		when: windowShown

		function base(props) {
			const d = { level: 80, charging: false, pluggedIn: false, secondsLeft: 0, secondsToFull: 0, healthPercent: null, powerMode: "", energySaver: false };
			for (const k in props) d[k] = props[k];
			return d;
		}

		// Bloom batteryTooltip.ts, line for line.
		function test_tooltipLines() {
			compare(Battery.tooltip(base({ level: 100, pluggedIn: true })), "Fully charged (100%)");
			compare(Battery.tooltip(base({ level: 60, pluggedIn: true, charging: true, secondsToFull: 2700 })),
				"60% available (plugged in, charging)\nAbout 45 min until full");
			compare(Battery.tooltip(base({ level: 60, pluggedIn: true })), "60% available (plugged in, not charging)");
			compare(Battery.tooltip(base({ level: 42, secondsLeft: 11520 })), "3 hr 12 min (42%) remaining");
			compare(Battery.tooltip(base({ level: 42 })), "42% remaining");
			compare(Battery.tooltip(base({ level: 42, powerMode: "Balanced", energySaver: true, healthPercent: 87 })),
				"42% remaining\nPower mode: Balanced\nEnergy saver is on\nBattery health: 87% of original capacity");
		}

		function test_formatDuration() {
			compare(Battery.formatDuration(20), "1 min");
			compare(Battery.formatDuration(3600), "1 hr");
			compare(Battery.formatDuration(11520), "3 hr 12 min");
		}

		function test_fillKind() {
			compare(Battery.fillKind(15, true, 20), "charging");
			compare(Battery.fillKind(20, false, 20), "low");
			compare(Battery.fillKind(21, false, 20), "normal");
		}

		function test_iconFillColours() {
			const img = grabImage(host);
			// Sample the fill left of the charging bolt to avoid antialiasing.
			verify(Qt.colorEqual(img.pixel(4, 7), "#32d74b"), `charging fill ${img.pixel(4, 7)}`);
			verify(Qt.colorEqual(img.pixel(30 + 4, 7), "#ff453a"), `low fill ${img.pixel(30 + 4, 7)}`);
			compare(charging.implicitWidth, 20);
			compare(charging.implicitHeight, 14);
		}
	}
}
