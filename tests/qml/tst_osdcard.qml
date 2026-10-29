import QtQuick
import QtTest
import "../../shell/modules/osd"

// Bloom's volume and brightness HUDs (Overlay.tsx VolumeNotch,
// BrightnessNotch, MixerTile; Overlay.css), drawn at 1x: the window scales.
Item {
	id: host
	width: 500
	height: 300

	QtObject {
		id: colours
		property color text: "#f0f0f0"
		property color textMuted: "#909090"
		property color bg: "#101010"
		property color border: "#404040"
		property color groupBg: "#202020"
	}

	OsdCard {
		id: volume
		edge: "left"
		y: 50
		theme: colours
		value: 0.45
		sessions: [
			{ id: 1, name: "Firefox", icon: "", volume: 0.8, muted: false },
			{ id: 2, name: "Music", icon: "", volume: 0.5, muted: true }
		]
	}

	OsdCard {
		id: bright
		edge: "right"
		x: 400
		y: 50
		theme: colours
		value: 0.7
	}

	SignalSpy { id: chosen; target: volume; signalName: "valueChosen" }
	SignalSpy { id: mixerToggled; target: volume; signalName: "mixerToggled" }
	SignalSpy { id: sessionVolume; target: volume; signalName: "sessionVolumeChosen" }
	SignalSpy { id: sessionMute; target: volume; signalName: "sessionMuteToggled" }

	TestCase {
		name: "OsdCard"
		when: windowShown

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function at(item, root) {
			return item.mapToItem(root, 0, 0);
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function init() {
			volume.mixerOpen = false;
			volume.shown = true;
			bright.shown = true;
			tryCompare(part(volume, "motion"), "opacity", 1, 2000);
			[chosen, mixerToggled, sessionVolume, sessionMute].forEach(s => s.clear());
		}

		function test_volumeGeometry() {
			const card = part(volume, "card");
			compare(card.width, 42);
			compare(card.height, 196);
			const bar = part(volume, "bar");
			compare(bar.width, 10);
			compare(bar.radius, 5);
			// padding 16 0 14; the bar fills down to the 20 px action (+2 margin).
			compare(at(bar, card).y, 16);
			compare(bar.height, 196 - 16 - 14 - 2 - 20);
			compare(at(bar, card).x, 16);
			const action = part(volume, "action");
			compare(at(action, card).y, 16 + 144 + 2);
			compare(action.height, 20);
			compare(bar.color, Qt.rgba(1, 1, 1, 0.2));
		}

		function test_brightnessGeometry() {
			const card = part(bright, "card");
			const bar = part(bright, "bar");
			compare(at(bar, card).y, 16 + 4);
			compare(bar.height, 130);
			const sun = part(bright, "sun");
			compare(sun.width, 20);
			// Its own place (it's rotated, so not its mapped corner).
			compare(sun.y, 20 + 130 + 10);
			compare(part(bright, "sunGlyph").name, "bloom-sun");
		}

		function test_fillSprings() {
			const fill = part(volume, "fill");
			tryCompare(fill, "height", 144 * 0.45, 2000);
			volume.value = 0.9;
			wait(50);
			verify(fill.height > 144 * 0.45 && fill.height < 144 * 0.9, `springing at ${fill.height}`);
			tryCompare(fill, "height", 144 * 0.9, 2000);
			volume.muted = true;
			tryCompare(fill, "height", 0, 2000);
			volume.muted = false;
			volume.value = 0.45;
		}

		function test_sunTurns() {
			const sun = part(bright, "sun");
			tryCompare(sun, "rotation", 0.7 * 180, 2000);
		}

		function test_percentFlashesOnShowAndChange() {
			volume.shown = false;
			wait(400);
			volume.shown = true;
			compare(volume.showingPercent, true, "flashes as it appears");
			const percent = part(volume, "percent");
			compare(percent.text, "45%");
			compare(percent.font.pixelSize, 10);
			compare(percent.font.weight, Font.Bold);
			wait(1300);
			compare(volume.showingPercent, false, "gone after 1.2 s");
			volume.value = 0.5;
			compare(volume.showingPercent, true);
			compare(percent.text, "50%");
			volume.value = 0.45;
		}

		function test_actionIcons() {
			wait(1300);
			const speaker = part(volume, "speaker");
			const mixerIcon = part(volume, "mixerIcon");
			compare(speaker.name, "sf-speaker.wave.2.fill");
			tryCompare(speaker, "opacity", 0.8, 1000);
			compare(mixerIcon.opacity, 0);
			const action = part(volume, "action");
			mouseMove(action, 21, 10);
			tryCompare(mixerIcon, "opacity", 1, 1000);
			tryCompare(speaker, "opacity", 0, 1000);
			compare(mixerIcon.name, "sf-slider.horizontal.3");
			mouseMove(host, 250, 290);
			volume.muted = true;
			compare(speaker.name, "sf-speaker.slash.fill");
			volume.muted = false;
		}

		function test_barClickAndDrag() {
			const bar = part(volume, "bar");
			mousePress(bar, 5, 144 * 0.25);
			fuzzyCompare(chosen.signalArguments[0][0], 0.75, 0.01);
			mouseMove(bar, 5, 144 * 0.5);
			mouseRelease(bar, 5, 144 * 0.5);
			fuzzyCompare(chosen.signalArguments[chosen.count - 1][0], 0.5, 0.01);
			compare(part(volume, "barPointer").cursorShape, Qt.PointingHandCursor);
		}

		// Scrolling the card moves the value 5 % a notch (owner, 2026-10-29).
		function test_wheelChangesTheValue() {
			mouseWheel(part(volume, "card"), 21, 60, 0, 120);
			compare(chosen.count, 1);
			fuzzyCompare(chosen.signalArguments[0][0], 0.5, 0.001);
			mouseWheel(part(volume, "card"), 21, 60, 0, -240);
			fuzzyCompare(chosen.signalArguments[1][0], 0.35, 0.001);
			// Clamped.
			volume.value = 0.98;
			mouseWheel(part(volume, "card"), 21, 60, 0, 120);
			compare(chosen.signalArguments[2][0], 1);
			volume.value = 0.45;
		}

		function test_wheelOverAnApp() {
			volume.mixerOpen = true;
			const tile = part(part(volume, "mixer"), "tile-1");
			// Once the card has grown to show it (a clipped tile takes no input).
			wait(400);
			mouseWheel(tile, 22, 50, 0, -120);
			compare(sessionVolume.signalArguments[0][0], 1);
			fuzzyCompare(sessionVolume.signalArguments[0][1], 0.75, 0.001);
			compare(chosen.count, 0, "an app's scroll isn't the main volume");
		}

		function test_actionOpensTheMixer() {
			mouseClick(part(volume, "action"));
			compare(mixerToggled.count, 1);
		}

		function test_mixer() {
			volume.mixerOpen = true;
			const panel = part(volume, "mixer");
			// 2 apps: 8 + 2 x 44 + 4 + 8.
			compare(panel.width, 16 + 2 * 44 + 4);
			tryCompare(part(volume, "card"), "width", 42 + 108, 2000);
			compare(at(panel, part(volume, "card")).x, 42);
			const first = part(panel, "tile-1");
			compare(first.width, 44);
			compare(at(first, panel).x, 8);
			compare(at(first, panel).y, 16);
			compare(first.height, 196 - 16 - 14);
			const tileBar = part(first, "tileBar");
			compare(tileBar.width, 10);
			const letter = part(first, "fallback");
			compare(letter.text, "F");
			compare(letter.font.pixelSize, 9);
			compare(part(part(panel, "tile-2"), "logo").opacity, 0.35, "a muted app's logo dims");
			mouseClick(part(first, "tileAction"));
			compare(sessionMute.count, 1);
			compare(sessionMute.signalArguments[0][0], 1);
			mousePress(tileBar, 5, tileBar.height * 0.5);
			mouseRelease(tileBar, 5, tileBar.height * 0.5);
			compare(sessionVolume.signalArguments[0][0], 1);
			fuzzyCompare(sessionVolume.signalArguments[0][1], 0.5, 0.02);
		}

		function test_mixerEmpty() {
			const saved = volume.sessions;
			volume.sessions = [];
			volume.mixerOpen = true;
			compare(part(volume, "mixer").width, 16 + 2 * 44 + 4, "room for the message");
			compare(part(volume, "mixerEmpty").text, "No apps with audio");
			volume.sessions = saved;
		}

		function test_entersFromTheEdge() {
			volume.shown = false;
			tryCompare(part(volume, "motion"), "opacity", 0, 2000);
			volume.shown = true;
			const card = part(volume, "motion");
			verify(card.sx < 0.5, `grows out of the edge: ${card.sx}`);
			tryCompare(card, "sx", 1, 2000);
			tryCompare(card, "opacity", 1, 2000);
		}

		function test_restDrawsNoFrames() {
			wait(1400);
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
			compare(framesIn(1000), 0);
		}
	}
}
