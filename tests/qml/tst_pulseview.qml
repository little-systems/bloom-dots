import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 400
	height: 100

	// Black, so only the bolt's own white counts in pixel checks.
	Rectangle {
		anchors.fill: parent
		color: "black"
	}

	Component {
		id: viewComponent
		PulseView {
			width: 176
			height: 36
			battery: ({ level: 80, charging: true, pluggedIn: true, threshold: 20 })
		}
	}

	TestCase {
		name: "PulseView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		function label(v, key) {
			return findChild(findChild(v, "pulse-" + key), "pulse-label").text;
		}

		// AnimatePresence mode="wait": the normal row leaves before a pulse enters.
		function test_waitsForTheExit() {
			const v = make();
			compare(v.shownKey, "");
			compare(v.standardOpacity, 1);
			v.kind = "power";
			compare(v.shownKey, "", "still leaving");
			tryCompare(v, "shownKey", "battery", 600);
			tryCompare(v, "standardOpacity", 0, 300);
			compare(label(v, "battery"), "Charging • 80%");
			v.kind = "";
			tryCompare(v, "shownKey", "", 600);
			tryCompare(v, "standardOpacity", 1, 600);
		}

		function test_lowAndPowerShareOneView() {
			const v = make({ kind: "power" });
			tryCompare(v, "shownKey", "battery", 600);
			v.battery = { level: 15, charging: false, pluggedIn: false, threshold: 20 };
			v.kind = "low";
			compare(v.shownKey, "battery", "no swap");
			compare(label(v, "battery"), "Low Battery • 15%");
			compare(findChild(findChild(v, "pulse-battery"), "pulse-label").color, Qt.color("#FF453A"));
		}

		function test_updateViewAndArrow() {
			const v = make({ kind: "update" });
			tryCompare(v, "shownKey", "update", 600);
			compare(label(v, "update"), "Update Available");
			compare(findChild(findChild(v, "pulse-update"), "pulse-label").color, Qt.color("#32D74B"));
			v.kind = "power";
			v.updateAvailable = true;
			tryCompare(v, "shownKey", "battery", 900);
			// Visible once the entering pulse is above opacity 0.
			tryCompare(findChild(findChild(v, "pulse-battery"), "update-arrow"), "visible", true, 600, "Bloom shows the arrow beside the battery");
		}


		// The charging bolt (a Shape) appears when charging starts, which is
		// exactly when the charging pulse shows; it must draw inside the pulse.
		function test_boltDrawsWhenChargingStarts() {
			const v = make({ kind: "power", textColor: "#ff00ff", battery: { level: 80, charging: false, pluggedIn: false, threshold: 20 } });
			tryCompare(v, "shownKey", "battery", 600);
			v.battery = { level: 80, charging: true, pluggedIn: true, threshold: 20 };
			wait(700);
			const img = grabImage(host);
			let white = 0;
			for (let x = 0; x < v.width; x++)
				for (let y = 0; y < v.height; y++) {
					const c = img.pixel(x, y);
					if (c.r > 0.9 && c.g > 0.9 && c.b > 0.9)
						white++;
				}
			verify(white >= 4, `the white bolt is drawn (${white} white pixels)`);
		}

		// The leaving view keeps what it showed (Bloom's exiting element is frozen).
		function test_lowLabelHoldsWhileLeaving() {
			const v = make({ kind: "low", battery: { level: 12, charging: false, pluggedIn: false, threshold: 20 } });
			tryCompare(v, "shownKey", "battery", 600);
			v.kind = "";
			wait(50);
			compare(label(v, "battery"), "Low Battery • 12%");
			compare(findChild(findChild(v, "pulse-battery"), "pulse-label").color, Qt.color("#FF453A"));
		}

		// A key that flips back while leaving finishes the exit first, then
		// settles on what is wanted now.
		function test_flipWhileLeaving() {
			const v = make({ kind: "update" });
			tryCompare(v, "shownKey", "update", 600);
			v.kind = "";
			v.kind = "update";
			compare(v.shownKey, "update");
			tryCompare(findChild(v, "pulse-update"), "opacity", 1, 1200, "back in after the exit finished");
			compare(v.shownKey, "update");
		}
	}
}
