import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's device art (src/devices/DeviceArt.tsx): each drawing's connect
// ("play") or disconnect ("leave") animation runs once and holds its last
// frame; `still` draws the end of the connect animation without playing it.
Item {
	id: host
	width: 300
	height: 120

	DeviceArt { id: playing; x: 20; y: 30; art: "stem-buds"; phase: "play" }
	DeviceArt { id: leaving; x: 120; y: 30; art: "mouse"; phase: "leave" }
	DeviceArt { id: still; x: 220; y: 30; art: "keyboard"; still: true }

	TestCase {
		name: "DeviceArt"
		when: windowShown

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function test_box() {
			// 60 px, as Bloom's alert draws it; the recording's 20 px margin
			// for glows hangs outside the box.
			compare(playing.width, 60);
			compare(playing.height, 60);
			const anim = part(playing, "animation");
			compare(anim.width, 100);
			compare(anim.x, -20);
			compare(anim.y, -20);
		}

		function test_playsOnceAndHolds() {
			const anim = part(playing, "animation");
			tryVerify(() => anim.status === Image.Ready, 3000);
			verify(anim.frameCount > 10, `frames ${anim.frameCount}`);
			compare(anim.source.toString().split("/").pop(), "stem-buds-play.webp");
			tryVerify(() => !anim.playing, 4000, "stops after one run");
			compare(anim.currentFrame, anim.frameCount - 1, "holds the last frame");
		}

		// The WebP runs for 2.11 s including its last frame's 390 ms.
		// DeviceArt stops upon reaching that frame and holds it indefinitely,
		// so playing ends after 1.72 s. Allow timer scheduling overhead.
		function test_playsInRealTime() {
			const anim = part(playing, "animation");
			tryVerify(() => !anim.playing, 4000);
			const frames = {};
			const record = () => frames[anim.currentFrame] = Date.now();
			anim.currentFrameChanged.connect(record);
			try {
				const t0 = Date.now();
				playing.runId++;
				tryVerify(() => !anim.playing, 5000);
				const ms = Date.now() - t0;
				verify(ms > 1550 && ms < 2400, `took ${ms} ms; final frame arrives at 1720 ms`);
				// The two preceding frames hold for 530 and 110 ms. Checking
				// these catches playback advancing once per display refresh.
				const last = anim.frameCount - 1;
				verify(frames[last - 1] - frames[last - 2] >= 450, "recorded 530 ms hold");
				verify(frames[last] - frames[last - 1] >= 70, "recorded 110 ms hold");
			} finally { anim.currentFrameChanged.disconnect(record); }
		}

		function test_leavePlaysTheDisconnect() {
			const anim = part(leaving, "animation");
			compare(anim.source.toString().split("/").pop(), "mouse-leave.webp");
			tryVerify(() => !anim.playing, 4000);
		}

		function test_runIdReplays() {
			const anim = part(playing, "animation");
			tryVerify(() => !anim.playing, 4000);
			playing.runId++;
			verify(anim.playing, "a new run plays again");
			verify(anim.currentFrame < anim.frameCount - 1);
			tryVerify(() => !anim.playing, 4000);
		}

		function test_still() {
			const image = part(still, "stillImage");
			compare(image.source.toString().split("/").pop(), "keyboard.png");
			verify(image.visible);
			verify(!findChild(still, "animation") || !findChild(still, "animation").visible);
		}

		function test_noFramesAtRest() {
			tryVerify(() => !part(playing, "animation").playing && !part(leaving, "animation").playing, 4000);
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
			compare(framesIn(1000), 0);
		}
	}
}
