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
		const b = { available: true, ready: true, level: 50, charging: false, threshold: 20 };
		for (const k in props) b[k] = props[k];
		return b;
	}

	// Bloom fires once per crossing and re-arms on charging or recovery.
	function test_lowBatteryStep() {
		let r = Pulses.lowBatteryStep(true, battery({ level: 20 }));
		verify(r.fire, "at the threshold");
		verify(!r.armed);
		r = Pulses.lowBatteryStep(r.armed, battery({ level: 19 }));
		verify(!r.fire, "once per crossing");
		r = Pulses.lowBatteryStep(r.armed, battery({ level: 19, charging: true }));
		verify(!r.fire);
		verify(r.armed, "charging re-arms");
		r = Pulses.lowBatteryStep(false, battery({ level: 21 }));
		verify(r.armed, "recovering above the threshold re-arms");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 10, charging: true })).fire, "not while charging");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 10, ready: false })).fire, "not before UPower answers");
		verify(!Pulses.lowBatteryStep(true, battery({ level: 0, available: false })).fire, "no battery, no pulse");
		compare(Pulses.lowBatteryStep(false, battery({ level: 10, ready: false })).armed, false, "unknown keeps the state");
	}

	function test_workspacePulse() {
		verify(Pulses.workspacePulse(1, 2));
		verify(!Pulses.workspacePulse(2, 2), "the same workspace (its window list changed)");
		verify(!Pulses.workspacePulse(null, 2), "the workspace at login");
		verify(!Pulses.workspacePulse(2, null));
	}

	function s(props) {
		const o = { workspace: false, update: false, low: false, power: false, hovered: false, open: false };
		for (const k in props) o[k] = props[k];
		return o;
	}

	function test_activePulse() {
		compare(Pulses.activePulse(s({})), "");
		compare(Pulses.activePulse(s({ power: true })), "power");
		compare(Pulses.activePulse(s({ power: true, low: true })), "low");
		compare(Pulses.activePulse(s({ low: true, update: true })), "update");
		compare(Pulses.activePulse(s({ update: true, workspace: true })), "workspace");
		compare(Pulses.activePulse(s({ update: true, hovered: true })), "", "the status strip wins on hover");
		compare(Pulses.activePulse(s({ update: true, open: true })), "", "never over an open player");
	}

	function test_viewKey() {
		compare(Pulses.viewKey(""), "");
		compare(Pulses.viewKey("power"), "battery");
		compare(Pulses.viewKey("low"), "battery", "Bloom's one pulse-view: no swap between them");
		compare(Pulses.viewKey("update"), "update");
		compare(Pulses.viewKey("workspace"), "workspace");
	}

	function test_batteryLabel() {
		compare(Pulses.batteryLabel("low", { level: 15, charging: false }), "Low Battery • 15%");
		compare(Pulses.batteryLabel("power", { level: 80, charging: true }), "Charging • 80%");
		compare(Pulses.batteryLabel("power", { level: 80, charging: false }), "On Battery • 80%");
	}

	function test_workspaceLabel() {
		compare(Pulses.workspaceLabel({ id: 3, name: "3" }), "Workspace 3");
		compare(Pulses.workspaceLabel({ id: 4, name: "" }), "Workspace 4");
		compare(Pulses.workspaceLabel({ id: 5, name: "web" }), "web");
	}

	function test_pageDots() {
		compare(Pulses.pageDots({ id: 2, ids: [1, 2, 3] }), [1, 2, 3]);
		compare(Pulses.pageDots({ id: 1, ids: [1] }), [], "one workspace: nothing to place");
		compare(Pulses.pageDots({ id: 7, ids: [1, 2, 3, 4, 5, 6, 7] }), [], "more than 6 would crowd the row");
		compare(Pulses.pageDots({ id: 2, ids: [3, 1, 2] }), [1, 2, 3], "in order");
	}

	// Review focus 3: a short peek never cuts a longer one short.
	function test_peekNeverShortens() {
		compare(Pulses.peekUntil(1000, 0, 2000), 3000);
		compare(Pulses.peekUntil(1000, 7000, 2000), 7000, "an update peek still running");
		compare(Pulses.peekUntil(6000, 7000, 2000), 8000);
	}
}
