import QtQuick
import QtTest
import "../../shell/modules/notch/pulses.js" as Pulses

TestCase {
	name: "PulseRules"

	function test_powerPulse() {
		verify(Pulses.powerPulse(false, true), "plugged in");
		verify(Pulses.powerPulse(true, false), "unplugged");
		verify(!Pulses.powerPulse(true, true));
		verify(!Pulses.powerPulse(null, true), "the first reading is not a change");
	}

	function battery(props) {
		const b = { available: true, ready: true, level: 50, pluggedIn: false, threshold: 20 };
		for (const k in props) b[k] = props[k];
		return b;
	}

	// Bloom fires once per crossing and re-arms on plugging in or recovery.
	function test_lowBatteryStep() {
		let r = Pulses.lowBatteryStep(true, battery({ level: 20 }));
		verify(r.fire, "at the threshold");
		verify(!r.armed);
		r = Pulses.lowBatteryStep(r.armed, battery({ level: 19 }));
		verify(!r.fire, "once per crossing");
		r = Pulses.lowBatteryStep(r.armed, battery({ level: 19, pluggedIn: true }));
		verify(!r.fire);
		verify(r.armed, "plugging in re-arms");
		r = Pulses.lowBatteryStep(false, battery({ level: 21 }));
		verify(r.armed, "recovering above the threshold re-arms");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 10, pluggedIn: true })).fire, "not while plugged in");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 10, ready: false })).fire, "not before UPower answers");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 0, available: false })).fire, "no battery, no pulse");
		compare(Pulses.lowBatteryStep(false, battery({ level: 10, ready: false })).armed, false, "unknown keeps the state");
	}

	function s(props) {
		const o = { update: false, low: false, power: false, hovered: false, open: false };
		for (const k in props) o[k] = props[k];
		return o;
	}

	function test_activePulse() {
		compare(Pulses.activePulse(s({})), "");
		compare(Pulses.activePulse(s({ power: true })), "power");
		compare(Pulses.activePulse(s({ power: true, low: true })), "low");
		compare(Pulses.activePulse(s({ low: true, update: true })), "update");
		compare(Pulses.activePulse(s({ update: true, hovered: true })), "", "the status strip wins on hover");
		compare(Pulses.activePulse(s({ update: true, open: true })), "", "never over an open player");
	}

	function test_viewKey() {
		compare(Pulses.viewKey(""), "");
		compare(Pulses.viewKey("power"), "battery");
		compare(Pulses.viewKey("low"), "battery", "Bloom's one pulse-view: no swap between them");
		compare(Pulses.viewKey("update"), "update");
	}

	function test_batteryLabel() {
		compare(Pulses.batteryLabel("low", { level: 15, pluggedIn: false }), "Low Battery • 15%");
		compare(Pulses.batteryLabel("power", { level: 80, pluggedIn: true }), "Charging • 80%");
		compare(Pulses.batteryLabel("power", { level: 100, pluggedIn: true, charging: false }), "Charging • 100%", "full on the charger is still plugged in");
		compare(Pulses.batteryLabel("power", { level: 80, pluggedIn: false }), "On Battery • 80%");
	}

	// Review focus 3: a short peek never cuts a longer one short.
	function test_peekNeverShortens() {
		compare(Pulses.peekUntil(1000, 0, 2000), 3000);
		compare(Pulses.peekUntil(1000, 7000, 2000), 7000, "an update peek still running");
		compare(Pulses.peekUntil(6000, 7000, 2000), 8000);
	}
}
