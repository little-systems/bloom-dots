import QtQuick
import QtTest
import "../../shell/common"
import "../../shell/modules/notch/qp"

// Bloom's quick-panel parts (components/QuickPanel.css .qp-*) against the
// reference values in docs/plans/2026-10-29-ui-parity-1-cursor-and-panels.md.
Item {
	id: host
	width: 400
	height: 500

	// Opaque, distinct colours so a part using the wrong one fails.
	QtObject {
		id: colours
		property color text: "#f0f0f0"
		property color textMuted: "#909090"
		property color groupBg: "#202020"
		property color border: "#404040"
		property color bgExpanded: "#080808"
		property color scrollbarThumb: "#303030"
	}

	QpSwitch { id: sw; theme: colours; x: 300; y: 0 }
	QpHeader {
		id: header
		theme: colours
		width: 350
		y: 30
		title: "Wi-Fi"
		QpIconButton { id: refresh; theme: colours; icon: "refresh-cw" }
	}
	QpRow { id: row; theme: colours; width: 326; y: 70; icon: "wifi"; name: "Home"; sub: "Connected" }
	QpRow { id: bare; theme: colours; width: 326; y: 110; icon: "wifi"; name: "No subline" }
	QpRow {
		id: longRow
		theme: colours
		width: 200
		y: 150
		icon: "wifi"
		name: "A network name far too long to fit in a two hundred pixel row"
		sub: "Secured"
		badge: "lock-keyhole"
	}
	QpRow {
		id: openRow
		theme: colours
		width: 326
		y: 190
		icon: "wifi"
		name: "Office"
		expanded: true
		QpButton { id: inRow; theme: colours; text: "Forget" }
	}
	QpButton { id: plain; theme: colours; y: 300; text: "OK" }
	QpButton { id: primary; theme: colours; x: 80; y: 300; text: "Connect"; primary: true }
	QpButton { id: off; theme: colours; x: 160; y: 300; text: "Forget"; enabled: false }
	QpButton { id: busy; theme: colours; x: 240; y: 300; text: "Connect"; primary: true; busy: true }
	QpChip { id: chipOff; theme: colours; y: 340; text: "Buds" }
	QpChip { id: chipOn; theme: colours; x: 80; y: 340; text: "Over-ear"; on: true }
	QpInput { id: input; theme: colours; y: 370; width: 200; placeholder: "Password" }
	QpFooter { id: footer; theme: colours; y: 410; text: "More Wi-Fi settings" }
	FracText { id: frac; y: 495; text: "Connect"; pixelSize: 10.5; font.family: "Inter" }
	Text { id: whole; y: 495; text: "Connect"; font.pixelSize: 11; font.family: "Inter" }
	QpEmpty { id: empty; theme: colours; y: 430; width: 300; height: 60; text: "Wi-Fi is off" }

	SignalSpy { id: toggled; target: sw; signalName: "toggled" }
	SignalSpy { id: backs; target: header; signalName: "back" }
	SignalSpy { id: rowClicks; target: row; signalName: "clicked" }
	SignalSpy { id: plainClicks; target: plain; signalName: "clicked" }
	SignalSpy { id: offClicks; target: off; signalName: "clicked" }
	SignalSpy { id: busyClicks; target: busy; signalName: "clicked" }
	SignalSpy { id: footerClicks; target: footer; signalName: "clicked" }
	SignalSpy { id: accepted; target: input; signalName: "accepted" }

	TestCase {
		name: "QuickPanelParts"
		when: windowShown

		function part(item, name) {
			const found = findChild(item, name);
			verify(found, `${item} has ${name}`);
			return found;
		}

		function centre(item) {
			return item.mapToItem(host, item.width / 2, item.height / 2);
		}

		function hoverOver(item) {
			const p = centre(item);
			mouseMove(host, p.x, p.y);
		}

		function cleanup() {
			mouseMove(host, 395, 495);
			wait(250);
		}

		function test_fracTextKeepsTheFractionalSize() {
			// Qt rounds font sizes to whole pixels; FracText draws at 11 and
			// scales to 10.5, so its box is 10.5 px text's.
			fuzzyCompare(frac.implicitWidth, whole.implicitWidth * 10.5 / 11, 0.01);
			fuzzyCompare(frac.implicitHeight, whole.implicitHeight * 10.5 / 11, 0.01);
		}

		function test_switchGeometry() {
			const track = part(sw, "track");
			const knob = part(sw, "knob");
			compare(track.width, 30);
			compare(track.height, 17);
			compare(track.radius, 9);
			compare(knob.width, 13);
			compare(knob.height, 13);
			compare(knob.x, 2);
			compare(knob.y, 2);
			// .qp-switch margin-left: 4px, outside the clickable track.
			compare(track.x, 4);
			compare(sw.width, 34);
		}

		function test_switchOnMovesTheKnob() {
			const track = part(sw, "track");
			const knob = part(sw, "knob");
			compare(track.color, colours.groupBg);
			compare(knob.color, colours.textMuted);
			sw.checked = true;
			// 0.2 s: halfway through, the knob is moving.
			wait(60);
			verify(knob.x > 2 && knob.x < 15, `knob mid-travel at ${knob.x}`);
			tryCompare(knob, "x", 15, 1000);
			tryCompare(knob, "color", colours.bgExpanded, 1000);
			tryCompare(track, "color", colours.text, 1000);
			sw.checked = false;
			tryCompare(knob, "x", 2, 1000);
		}

		function test_switchClickAsksToToggle() {
			toggled.clear();
			const p = centre(part(sw, "track"));
			mouseClick(host, p.x, p.y);
			compare(toggled.count, 1);
			// The switch is controlled: the owner flips `checked`.
			compare(sw.checked, false);
			// The 4 px margin is not part of the switch.
			mouseClick(host, sw.x + 2, sw.y + 8);
			compare(toggled.count, 1);
		}

		function test_header() {
			const back = part(header, "back");
			const title = part(header, "title");
			compare(back.width, 24);
			compare(back.height, 24);
			compare(header.height, 24);
			compare(title.font.pixelSize, 12);
			compare(title.font.weight, Font.DemiBold);
			compare(title.color, colours.text);
			// gap 4: back, title (fills), actions.
			compare(title.x, 28);
			compare(refresh.width, 24);
			compare(refresh.mapToItem(header, 0, 0).x, 350 - 24);
			compare(title.width, 350 - 28 - 4 - 24);
			backs.clear();
			const p = centre(back);
			mouseClick(host, p.x, p.y);
			compare(backs.count, 1);
		}

		function test_iconButtonHover() {
			const bg = part(refresh, "background");
			const glyph = part(refresh, "glyph");
			compare(bg.radius, 8);
			compare(glyph.size, 14);
			compare(glyph.color, colours.textMuted);
			compare(bg.color, Qt.rgba(0, 0, 0, 0));
			hoverOver(refresh);
			tryCompare(bg, "color", colours.groupBg, 1000);
			tryCompare(glyph, "color", colours.text, 1000);
			compare(part(refresh, "pointer").cursorShape, Qt.PointingHandCursor);
		}

		function test_iconButtonDisabled() {
			refresh.enabled = false;
			compare(refresh.opacity, 0.4);
			refresh.enabled = true;
			compare(refresh.opacity, 1);
		}

		function test_iconButtonSpins() {
			const glyph = part(refresh, "glyph");
			refresh.spinning = true;
			wait(100);
			verify(glyph.rotation > 0, "spinning");
			refresh.spinning = false;
			tryCompare(glyph, "rotation", 0, 1000);
		}

		function test_rowHeights() {
			// padding 5 + max(24 px icon, the text block) + 5, at line-height 1.25.
			compare(row.height, 5 + 11 * 1.25 + 9.5 * 1.25 + 5);
			compare(bare.height, 5 + 24 + 5);
			const icon = part(row, "icon");
			compare(icon.width, 24);
			compare(icon.radius, 12);
			compare(part(row, "glyph").size, 13);
			const name = part(row, "name");
			compare(name.font.pixelSize, 11);
			compare(name.font.weight, Font.DemiBold);
			compare(name.mapToItem(row, 0, 0).x, 8 + 24 + 9);
			compare(part(row, "sub").pixelSize, 9.5);
			compare(part(row, "sub").color, colours.textMuted);
		}

		function test_longNameElides() {
			const name = part(longRow, "name");
			verify(name.truncated, "the name elides");
			const badge = part(longRow, "badge");
			compare(badge.size, 11);
			compare(badge.color, colours.textMuted);
			// The badge sits at the row's right padding, after a 9 px gap.
			compare(badge.mapToItem(longRow, 0, 0).x, 200 - 8 - 11);
			verify(name.mapToItem(longRow, 0, 0).x + name.width <= 200 - 8 - 11 - 9, "the name stops before the badge");
		}

		function test_rowActiveColours() {
			const icon = part(row, "icon");
			const glyph = part(row, "glyph");
			compare(icon.color, colours.groupBg);
			compare(glyph.color, colours.text);
			row.active = true;
			compare(icon.color, colours.text);
			compare(glyph.color, colours.bgExpanded);
			row.active = false;
		}

		function test_rowHoverAndClick() {
			const main = part(row, "main");
			compare(main.color, Qt.rgba(0, 0, 0, 0));
			hoverOver(main);
			// .qp-row-main has no transition: the hover is immediate.
			compare(main.color, colours.groupBg);
			compare(part(row, "pointer").cursorShape, Qt.PointingHandCursor);
			rowClicks.clear();
			const p = centre(main);
			mouseClick(host, p.x, p.y);
			compare(rowClicks.count, 1);
		}

		function test_expandedRowShowsActions() {
			const back = part(openRow, "background");
			compare(back.color, colours.groupBg);
			const main = part(openRow, "main");
			hoverOver(main);
			// An expanded row's main line doesn't add its own hover.
			compare(main.color, Qt.rgba(0, 0, 0, 0));
			verify(inRow.visible);
			// .qp-row-actions padding 0 8 8 41.
			const at = inRow.mapToItem(openRow, 0, 0);
			compare(at.x, 41);
			compare(at.y, 34);
			compare(openRow.height, 34 + 24 + 8);
			openRow.expanded = false;
			compare(openRow.height, 34);
			verify(!inRow.visible);
			openRow.expanded = true;
		}

		function test_buttonGeometryAndColours() {
			compare(plain.height, 24);
			compare(plain.width, 64);
			const bg = part(plain, "background");
			const label = part(plain, "label");
			compare(bg.radius, 8);
			compare(bg.border.width, 1);
			compare(bg.border.color, colours.border);
			compare(bg.color, colours.groupBg);
			compare(label.pixelSize, 10.5);
			compare(label.font.weight, Font.DemiBold);
			compare(label.color, colours.text);
			const pbg = part(primary, "background");
			compare(pbg.color, colours.text);
			compare(pbg.border.color, colours.text);
			compare(part(primary, "label").color, colours.bgExpanded);
		}

		function test_buttonHoverTakes150ms() {
			const bg = part(plain, "background");
			hoverOver(plain);
			wait(50);
			verify(bg.color !== colours.groupBg && bg.color !== colours.border, `mid-fade at ${bg.color}`);
			tryCompare(bg, "color", colours.border, 1000);
			hoverOver(primary);
			tryCompare(primary, "opacity", 0.9, 1000);
			compare(part(primary, "background").color, colours.text);
		}

		function test_buttonDisabled() {
			compare(off.opacity, 0.45);
			offClicks.clear();
			mouseClick(off);
			compare(offClicks.count, 0);
		}

		function test_buttonBusySpinsAndStaysClickable() {
			verify(!part(busy, "label").visible);
			const spinner = part(busy, "spinner");
			verify(spinner.visible);
			compare(spinner.size, 13);
			compare(busy.width, 64);
			wait(100);
			verify(spinner.rotation > 0, "spinning");
		}

		function test_buttonClick() {
			plainClicks.clear();
			mouseClick(plain);
			compare(plainClicks.count, 1);
			compare(part(plain, "pointer").cursorShape, Qt.PointingHandCursor);
		}

		function test_buttonGrowsForLongLabels() {
			const label = part(inRow, "label");
			compare(inRow.width, Math.max(64, Math.ceil(label.implicitWidth) + 20));
		}

		function test_chips() {
			compare(chipOff.height, 20);
			const bg = part(chipOff, "background");
			compare(bg.radius, 10);
			compare(bg.color, Qt.rgba(0, 0, 0, 0));
			compare(bg.border.color, colours.border);
			const label = part(chipOff, "label");
			compare(label.color, colours.textMuted);
			compare(label.font.pixelSize, 10);
			compare(label.font.weight, Font.DemiBold);
			compare(chipOff.width, Math.ceil(label.implicitWidth) + 16);
			compare(part(chipOn, "background").color, colours.text);
			compare(part(chipOn, "background").border.color, colours.text);
			compare(part(chipOn, "label").color, colours.bgExpanded);
			hoverOver(chipOff);
			tryCompare(label, "color", colours.text, 1000);
		}

		function test_input() {
			compare(input.height, 26);
			const bg = part(input, "background");
			compare(bg.radius, 8);
			compare(bg.color, colours.groupBg);
			compare(bg.border.color, colours.border);
			const field = part(input, "field");
			compare(field.x, 9);
			compare(field.color, colours.text);
			verify(part(input, "placeholder").visible);
			compare(part(input, "pointer").cursorShape, Qt.IBeamCursor);
			input.forceActiveFocus();
			compare(bg.border.color, colours.textMuted);
			keyClick(Qt.Key_A);
			verify(!part(input, "placeholder").visible);
			compare(input.text, "a");
			accepted.clear();
			keyClick(Qt.Key_Return);
			compare(accepted.count, 1);
		}

		function test_footer() {
			const label = part(footer, "label");
			compare(label.font.pixelSize, 10);
			compare(label.color, colours.textMuted);
			compare(footer.height, Math.ceil(label.implicitHeight) + 4);
			compare(footer.width, Math.ceil(label.implicitWidth) + 16);
			hoverOver(footer);
			// .qp-footer has no transition.
			compare(label.color, colours.text);
			footerClicks.clear();
			mouseClick(footer);
			compare(footerClicks.count, 1);
		}

		function test_empty() {
			const label = part(empty, "label");
			compare(label.color, colours.textMuted);
			compare(label.horizontalAlignment, Text.AlignHCenter);
			compare(label.width, 300 - 48);
			// Centred in its box.
			const mid = label.mapToItem(empty, 0, label.height / 2).y;
			fuzzyCompare(mid, 30, 1);
			empty.icon = "wifi-off";
			const glyph = part(empty, "glyph");
			verify(glyph.visible);
			compare(glyph.size, 18);
			compare(glyph.color, colours.textMuted);
			empty.icon = "";
		}
	}
}
