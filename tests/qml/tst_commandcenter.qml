import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's Command Center (App.tsx .command-center-content-minimal, App.css
// .cc-*) with notification history moved out to the top-right corner.
Item {
	id: host
	width: 400
	height: 300

	QtObject {
		id: colours
		property color text: "#f0f0f0"
		property color textMuted: "#909090"
		property color groupBg: "#202020"
		property color border: "#404040"
		property color bgExpanded: "#080808"
		property color scrollbarThumb: "#303030"
	}

	// The panel's content box: 350 wide less 14 px each side, 230 tall less
	// the 36 px clock strip.
	CommandCenterView {
		id: cc
		theme: colours
		width: 322
		height: 194
		wifiKnown: true
		wifiEnabled: true
		wifiConnected: true
		ssid: "Home"
		bluetoothPowered: false
		bluetoothNames: []
		dockMode: "smart"
		notchMode: "fixed"
		volume: 0.25
		brightness: 40
	}

	SignalSpy { id: wifiToggled; target: cc; signalName: "wifiToggled" }
	SignalSpy { id: wifiOpened; target: cc; signalName: "wifiOpened" }
	SignalSpy { id: btToggled; target: cc; signalName: "bluetoothToggled" }
	SignalSpy { id: btOpened; target: cc; signalName: "bluetoothOpened" }
	SignalSpy { id: dockCycled; target: cc; signalName: "dockModeCycled" }
	SignalSpy { id: notchCycled; target: cc; signalName: "notchModeCycled" }
	SignalSpy { id: dnd; target: cc; signalName: "dndToggled" }
	SignalSpy { id: saver; target: cc; signalName: "energySaverToggled" }
	SignalSpy { id: tray; target: cc; signalName: "trayRequested" }
	SignalSpy { id: settings; target: cc; signalName: "settingsRequested" }
	SignalSpy { id: restart; target: cc; signalName: "restartRequested" }
	SignalSpy { id: volumeChosen; target: cc; signalName: "volumeChosen" }
	SignalSpy { id: brightnessChosen; target: cc; signalName: "brightnessChosen" }

	TestCase {
		name: "CommandCenter"
		when: windowShown

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function at(item) {
			return item.mapToItem(cc, 0, 0);
		}

		function centre(item) {
			return item.mapToItem(host, item.width / 2, item.height / 2);
		}

		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		function settleFrames() {
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
		}

		function init() {
			cc.wifiKnown = true;
			cc.wifiEnabled = true;
			cc.wifiConnected = true;
			cc.ssid = "Home";
			cc.bluetoothPowered = false;
			cc.bluetoothNames = [];
			cc.dockMode = "smart";
			cc.notchMode = "fixed";
			cc.dnd = false;
			cc.energySaver = false;
			cc.volume = 0.25;
			cc.brightness = 40;
			[wifiToggled, wifiOpened, btToggled, btOpened, dockCycled, notchCycled, dnd, saver, tray, settings, restart, volumeChosen, brightnessChosen].forEach(s => s.clear());
		}

		function cleanup() {
			mouseMove(host, 395, 295);
			wait(250);
		}

		function test_tileGrid() {
			// 2 columns, gap 10, grid height 78 at the top padding (12).
			const w = (322 - 10) / 2;
			const tiles = ["tile-wifi", "tile-dock", "tile-bluetooth", "tile-notch"].map(n => part(cc, n));
			const spots = [[0, 12], [w + 10, 12], [0, 56], [w + 10, 56]];
			tiles.forEach((t, i) => {
				compare(at(t).x, spots[i][0], t.objectName);
				compare(at(t).y, spots[i][1], t.objectName);
				compare(t.width, w);
				compare(t.height, 34);
			});
		}

		function test_spaceBetween() {
			// 170 px of content box: 78 grid, 32 buttons, 18 + 8 + 18 sliders;
			// the 16 px left over splits into two 8 px gaps.
			compare(at(part(cc, "round-dnd")).y, 12 + 78 + 8);
			compare(at(part(cc, "slider-volume")).y, 12 + 78 + 8 + 32 + 8);
			compare(at(part(cc, "slider-brightness")).y, 12 + 78 + 8 + 32 + 8 + 18 + 8);
		}

		function test_tileContents() {
			const tile = part(cc, "tile-dock");
			const circle = part(tile, "iconCircle");
			// 1 px border + 8 px padding.
			compare(at(circle).x - at(tile).x, 9);
			compare(circle.width, 20);
			compare(circle.radius, 10);
			compare(part(tile, "glyph").size, 12);
			compare(part(tile, "glyph").name, "bloom-dock");
			const title = part(tile, "title");
			compare(title.text, "Dock Mode");
			compare(title.pixelSize, 9);
			compare(title.font.weight, Font.DemiBold);
			compare(title.color, colours.text);
			compare(at(title).x - at(tile).x, 9 + 20 + 8);
			const status = part(tile, "status");
			compare(status.text, "Smart");
			compare(status.pixelSize, 7.5);
			compare(status.font.weight, Font.Medium);
			compare(status.color, colours.textMuted);
			// line-height 1.15, the two lines centred in the tile.
			compare(title.height, 9 * 1.15);
			compare(status.height, 7.5 * 1.15);
			// Centred anchors snap to whole pixels (alignWhenCentered), within 0.5 px.
			fuzzyCompare(at(title).y - at(tile).y + (title.height + status.height) / 2, 17, 0.5);
			compare(part(tile, "background").color, colours.groupBg);
			compare(part(tile, "background").border.color, colours.border);
			compare(part(tile, "background").radius, 10);
		}

		function test_statuses() {
			const wifi = part(part(cc, "tile-wifi"), "status");
			const bt = part(part(cc, "tile-bluetooth"), "status");
			compare(wifi.text, "Home");
			cc.ssid = "";
			compare(wifi.text, "Connected");
			cc.wifiConnected = false;
			compare(wifi.text, "Not connected");
			cc.wifiEnabled = false;
			compare(wifi.text, "Off");
			cc.wifiKnown = false;
			compare(wifi.text, "…");
			compare(bt.text, "Off");
			cc.bluetoothPowered = true;
			compare(bt.text, "On");
			cc.bluetoothNames = ["Buds"];
			compare(bt.text, "Buds");
			cc.bluetoothNames = ["Buds", "Mouse"];
			compare(bt.text, "2 connected");
			const dock = part(part(cc, "tile-dock"), "status");
			cc.dockMode = "fixed";
			compare(dock.text, "Fixed");
			cc.dockMode = "peek";
			compare(dock.text, "Peek");
			compare(part(part(cc, "tile-notch"), "status").text, "Fixed");
		}

		function test_longSsidElides() {
			cc.ssid = "A network name far too long for a seven and a half pixel status line";
			const status = part(part(cc, "tile-wifi"), "status");
			verify(status.truncated, "the SSID elides");
			const chevron = part(part(cc, "tile-wifi"), "more");
			verify(at(status).x + status.width <= at(chevron).x - 8, "the status stops before the chevron");
		}

		function test_activeTiles() {
			const wifi = part(cc, "tile-wifi");
			compare(part(wifi, "background").color, colours.text);
			compare(part(wifi, "background").border.color, colours.text);
			compare(part(wifi, "title").color, colours.bgExpanded);
			compare(part(wifi, "status").color, colours.bgExpanded);
			// The icon circle keeps groupBg; its glyph turns bgExpanded.
			compare(part(wifi, "iconCircle").color, colours.groupBg);
			compare(part(wifi, "glyph").color, colours.bgExpanded);
			compare(part(wifi, "moreGlyph").color, colours.bgExpanded);
			// Notch Mode fixed is active; Dock Mode smart isn't; Bluetooth off isn't.
			compare(part(part(cc, "tile-notch"), "background").color, colours.text);
			compare(part(part(cc, "tile-dock"), "background").color, colours.groupBg);
			compare(part(part(cc, "tile-bluetooth"), "background").color, colours.groupBg);
			compare(part(part(cc, "tile-bluetooth"), "moreGlyph").color, colours.text);
		}

		function test_wifiGlyphOpacity() {
			const glyph = part(part(cc, "tile-wifi"), "glyph");
			compare(glyph.name, "bloom-wifi");
			compare(glyph.opacity, 1);
			cc.wifiConnected = false;
			compare(glyph.opacity, 0.7);
			cc.wifiEnabled = false;
			compare(glyph.opacity, 0.4);
		}

		function test_tileClicks() {
			const wifi = part(cc, "tile-wifi");
			mouseClick(wifi, 40, 17);
			compare(wifiToggled.count, 1);
			compare(wifiOpened.count, 0);
			const more = part(wifi, "more");
			const p = centre(more);
			mouseClick(host, p.x, p.y);
			compare(wifiOpened.count, 1);
			compare(wifiToggled.count, 1, "the chevron doesn't toggle the radio");
			mouseClick(wifi, 40, 17, Qt.RightButton);
			compare(wifiOpened.count, 2);
			const bt = part(cc, "tile-bluetooth");
			mouseClick(bt, 40, 17);
			mouseClick(bt, 40, 17, Qt.RightButton);
			compare(btToggled.count, 1);
			compare(btOpened.count, 1);
			mouseClick(part(cc, "tile-dock"), 40, 17);
			mouseClick(part(cc, "tile-notch"), 40, 17);
			compare(dockCycled.count, 1);
			compare(notchCycled.count, 1);
			verify(!findChild(part(cc, "tile-dock"), "more"), "Dock Mode has no chevron");
		}

		function test_chevron() {
			const more = part(part(cc, "tile-bluetooth"), "more");
			compare(more.width, 18);
			compare(more.height, 18);
			compare(part(more, "moreBackground").radius, 6);
			compare(more.opacity, 0.55);
			compare(part(more, "moreGlyph").size, 12);
			// margin-left auto: flush with the tile's right padding.
			compare(at(more).x + 18, at(part(cc, "tile-bluetooth")).x + part(cc, "tile-bluetooth").width - 9);
			const p = centre(more);
			mouseMove(host, p.x, p.y);
			tryCompare(more, "opacity", 1, 1000);
			tryCompare(part(more, "moreBackground"), "color", colours.groupBg, 1000);
		}

		function test_tileHoverAndPress() {
			const tile = part(cc, "tile-dock");
			const p = centre(tile);
			mouseMove(host, p.x, p.y);
			tryCompare(part(tile, "background"), "color", colours.border, 1000);
			tryCompare(tile, "lift", -0.5, 1000);
			mousePress(host, p.x, p.y);
			tryCompare(tile, "scale", 0.98, 1000);
			mouseRelease(host, p.x, p.y);
			tryCompare(tile, "scale", 1, 1000);
			// An active tile keeps its colours on hover.
			const notch = part(cc, "tile-notch");
			const q = centre(notch);
			mouseMove(host, q.x, q.y);
			wait(250);
			compare(part(notch, "background").color, colours.text);
		}

		function test_roundButtons() {
			const names = ["dnd", "energy", "tray", "settings", "restart"];
			const glyphs = ["bloom-moon", "bloom-battery-saver", "bloom-tray", "bloom-settings", "bloom-reload"];
			const sizes = [18, 18, 14, 14, 14];
			const buttons = names.map(n => part(cc, "round-" + n));
			// padding 0 4, justify-content space-between.
			compare(at(buttons[0]).x, 4);
			compare(at(buttons[4]).x + 32, 322 - 4);
			const step = (322 - 8 - 32) / 4;
			buttons.forEach((b, i) => {
				fuzzyCompare(at(b).x, 4 + i * step, 0.01);
				compare(b.width, 32);
				compare(b.height, 32);
				compare(part(b, "glyph").name, glyphs[i]);
				compare(part(b, "glyph").size, sizes[i]);
				compare(part(b, "glyph").color, colours.textMuted);
				compare(part(b, "background").color, colours.groupBg);
				compare(part(b, "background").border.color, colours.border);
			});
			compare(part(buttons[3], "glyph").opacity, 0.9);
			const spies = [dnd, saver, tray, settings, restart];
			buttons.forEach((b, i) => {
				mouseClick(b);
				compare(spies[i].count, 1, names[i]);
			});
		}

		function test_roundButtonActive() {
			const b = part(cc, "round-dnd");
			cc.dnd = true;
			tryCompare(part(b, "background"), "color", colours.text, 1000);
			compare(part(b, "background").border.color, colours.text);
			tryCompare(part(b, "glyph"), "color", colours.bgExpanded, 1000);
			verify(part(b, "shadow").visible, "0 2px 8px border shadow");
			cc.energySaver = true;
			tryCompare(part(part(cc, "round-energy"), "background"), "color", colours.text, 1000);
			cc.dnd = false;
			verify(!part(b, "shadow").visible);
		}

		function test_roundButtonHover() {
			const b = part(cc, "round-tray");
			const p = centre(b);
			mouseMove(host, p.x, p.y);
			tryCompare(part(b, "background"), "color", colours.border, 1000);
			tryCompare(part(b, "glyph"), "color", colours.text, 1000);
			tryCompare(b, "lift", -1, 1000);
			mousePress(host, p.x, p.y);
			tryCompare(b, "scale", 0.95, 1000);
			mouseRelease(host, p.x, p.y);
		}

		function test_sliders() {
			const row = part(cc, "slider-volume");
			compare(row.height, 18);
			compare(row.width, 322);
			const track = part(row, "track");
			compare(at(track).x, 75 + 10);
			compare(track.width, 322 - 75 - 10 - 10 - 28);
			compare(track.height, 6);
			compare(track.radius, 3);
			compare(track.color, colours.groupBg);
			compare(part(row, "fill").width, track.width * 0.25);
			compare(part(row, "fill").color, colours.text);
			const label = part(row, "label");
			compare(label.text, "Volume");
			compare(label.font.pixelSize, 9);
			compare(label.font.weight, Font.DemiBold);
			compare(label.color, colours.textMuted);
			compare(at(label).x, 12 + 6);
			const icon = part(row, "glyph");
			compare(icon.name, "sf-speaker.wave.1.fill");
			compare(icon.size, 12);
			compare(icon.opacity, 0.5);
			const percent = part(row, "percent");
			compare(percent.text, "25%");
			compare(percent.width, 28);
			compare(percent.horizontalAlignment, Text.AlignRight);
			compare(at(percent).x, 322 - 28);
			compare(percent.color, colours.textMuted);
			const bright = part(cc, "slider-brightness");
			compare(part(bright, "percent").text, "40%");
			compare(part(bright, "glyph").name, "bloom-brightness-low");
			compare(part(bright, "glyph").opacity, 0.5);
		}

		function test_sliderHover() {
			const row = part(cc, "slider-volume");
			const p = centre(row);
			mouseMove(host, p.x, p.y);
			tryCompare(part(row, "track"), "color", colours.border, 1000);
			compare(part(row, "percent").color, colours.text);
			const glow = part(row, "glow");
			verify(glow.visible);
			// The glow sits on the fill.
			const fill = part(row, "fill");
			compare(glow.mapToItem(cc, 0, 0).x, fill.mapToItem(cc, 0, 0).x);
			compare(glow.mapToItem(cc, 0, 0).y, fill.mapToItem(cc, 0, 0).y);
			compare(glow.width, fill.width);
			compare(glow.height, fill.height);
		}

		function test_sliderSetsTheValue() {
			const row = part(cc, "slider-volume");
			const track = part(row, "track");
			mouseClick(track, track.width * 0.6, 3);
			compare(volumeChosen.count, 1);
			fuzzyCompare(volumeChosen.signalArguments[0][0], 0.6, 0.011);
			// step 0.01
			const v = volumeChosen.signalArguments[0][0];
			fuzzyCompare(v * 100, Math.round(v * 100), 1e-9);
			const bright = part(cc, "slider-brightness");
			const btrack = part(bright, "track");
			mousePress(btrack, btrack.width * 0.2, 3);
			mouseMove(btrack, btrack.width * 0.8, 3);
			mouseRelease(btrack, btrack.width * 0.8, 3);
			const last = brightnessChosen.signalArguments[brightnessChosen.count - 1][0];
			compare(last, Math.round(last), "brightness is a whole percent");
			fuzzyCompare(last, 80, 1);
			verify(brightnessChosen.count >= 2, "dragging updates as it goes");
			compare(part(row, "pointer").cursorShape, Qt.PointingHandCursor);
		}

		function test_noBrightness() {
			cc.brightness = -1;
			const bright = part(cc, "slider-brightness");
			compare(part(bright, "percent").text, "—");
			tryCompare(part(bright, "fill"), "width", 0, 1000);
			brightnessChosen.clear();
			const btrack = part(bright, "track");
			mouseClick(btrack, btrack.width / 2, 3);
			compare(brightnessChosen.count, 0);
		}

		// Bloom's fill is a percentage width: resizing the panel (the pill
		// springing between panels) moves it with the track, not after it.
		function test_fillFollowsAResizeAtOnce() {
			const row = part(cc, "slider-volume");
			cc.width = 452;
			wait(200);
			cc.width = 322;
			compare(part(row, "fill").width, part(row, "track").width * 0.25);
			// A new value still eases in over 0.05 s.
			cc.volume = 0.75;
			verify(part(row, "fill").width < part(row, "track").width * 0.75);
			tryCompare(part(row, "fill"), "width", part(row, "track").width * 0.75, 500);
		}

		function test_restDrawsNoFrames() {
			settleFrames();
			compare(framesIn(1000), 0);
		}
	}
}
