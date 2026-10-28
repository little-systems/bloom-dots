import QtQuick
import QtTest
import "../../shell/modules/osd/osd.js" as OSD

TestCase {
	name: "OSDRules"

	function test_suddenVolumeIncreaseIsRejected() {
		compare(OSD.protectVolume(0.40, 0.58, { enabled: true, maxJump: 10, maxLevel: 99 }, true),
			{ value: 0.40, blocked: true, reason: "jump" });
		compare(OSD.protectVolume(0.40, 0.45, { enabled: true, maxJump: 10, maxLevel: 99 }, true),
			{ value: 0.45, blocked: false, reason: "" });
	}

	function test_maximumAndInitialObservation() {
		const options = { enabled: true, maxJump: 10, maxLevel: 99 };
		compare(OSD.protectVolume(0.95, 1.0, options, true),
			{ value: 0.95, blocked: true, reason: "maximum" });
		compare(OSD.protectVolume(1.2, 1.22, options, true),
			{ value: 0.99, blocked: true, reason: "maximum" });
		compare(OSD.protectVolume(0, 1.5, options, false),
			{ value: 1.5, blocked: false, reason: "" }, "startup or sink replacement never writes a corrective volume");
		compare(OSD.protectVolume(0.4, 1.2, { enabled: false, maxJump: 10, maxLevel: 99 }, true),
			{ value: 1.2, blocked: false, reason: "" });
	}

	function test_brightnessPercentAndEdgeGeometry() {
		compare(OSD.brightnessPercent(0, 1666), 0);
		compare(OSD.brightnessPercent(833, 1666), 50);
		compare(OSD.brightnessPercent(1666, 1666), 100);
		compare(OSD.brightnessPercent(833, 0), null);
		compare(OSD.edgePill("left", 1920, 1080, 1.3), { x: 0, y: 412.6, width: 54.6, height: 254.8 });
		compare(OSD.edgePill("right", 1920, 1080, 1), { x: 1878, y: 442, width: 42, height: 196 });
	}

	function test_brightnessctlOutputIsValidated() {
		compare(OSD.parseBrightness("intel_backlight,backlight,833,50%,1666\n"),
			{ device: "intel_backlight", current: 833, maximum: 1666, percent: 50 });
		compare(OSD.parseBrightness("input2::capslock,leds,1,100%,1"), null);
		compare(OSD.parseBrightness("bad;name,backlight,833,50%,1666"), null);
		compare(OSD.parseBrightness("intel_backlight,backlight,833,50%,0"), null);
	}

	function test_mixerUsesPipewireNodeIdentity() {
		const nodes = [
			{ id: 8, isStream: true, isSink: true, ready: true, properties: { "application.name": "Music" }, audio: { volume: 0.25, muted: false } },
			{ id: 9, isStream: true, isSink: true, ready: true, properties: { "application.name": "Music" }, audio: { volume: 0.7, muted: true } },
			{ id: 10, isStream: false, isSink: true, ready: true, audio: { volume: 0.5 } },
			{ id: 11, isStream: true, isSink: false, ready: true, audio: { volume: 0.5 } }
		];
		compare(OSD.mixerRows(nodes), [
			{ id: 8, name: "Music", volume: 0.25, muted: false },
			{ id: 9, name: "Music", volume: 0.7, muted: true }
		]);
	}
}
