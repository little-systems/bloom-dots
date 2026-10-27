import QtQuick
import QtTest
import "../../shell/modules/dock/previews.js" as Preview

TestCase {
	name: "DockPreviewRules"

	function test_exactAddressIdentity() {
		const item = { windows: [
			{ address: "0xAB", title: "Same", focus: 2 },
			{ address: "0xcd", title: "Same", focus: 0 }
		] };
		const found = Preview.candidates(item, [
			{ address: "0xcd", title: "Same", appId: "wrong", toplevel: "second" },
			{ address: "0xab", title: "Same", appId: "other", toplevel: "first" },
			{ address: "", title: "Same", appId: "other", toplevel: "not-a-match" }
		]);
		compare(found.map(w => w.address), ["0xcd", "0xab"], "recent window first");
		compare(found.map(w => w.toplevel), ["second", "first"], "only exact addresses supply captures");
	}

	function test_missingOrStaleAddressNeverBorrowsAnotherCapture() {
		const item = { windows: [{ address: "0xa", title: "A", focus: 0 }, { address: "0xb", title: "B", focus: -1 }] };
		const found = Preview.candidates(item, [{ address: "0xa", toplevel: "live" }, { address: "0xc", toplevel: "stale" }]);
		compare(found.map(w => w.toplevel), ["live", null]);
		compare(Preview.normalizeAddress("0xABC"), "0xabc");
		compare(Preview.normalizeAddress("123"), "");
		compare(Preview.normalizeAddress("0xz"), "");
	}

	function test_hoverDwellRetentionAndCancellation() {
		const s = { enabled: true, running: true, iconHovered: true, cardHovered: false, hoverSince: 0, leaveAt: -1, now: 299 };
		verify(!Preview.previewVisible(s));
		s.now = 300;
		verify(Preview.previewVisible(s));
		s.iconHovered = false;
		s.leaveAt = 300;
		s.now = 399;
		verify(Preview.previewVisible(s), "the pointer can cross the icon-to-card gap");
		s.now = 401;
		verify(!Preview.previewVisible(s));
		s.cardHovered = true;
		verify(Preview.previewVisible(s));
		for (const key of ["menuOpen", "dragging", "hidden", "suppressed"]) {
			s[key] = true;
			verify(!Preview.previewVisible(s), key);
			s[key] = false;
		}
		s.enabled = false;
		verify(!Preview.previewVisible(s));
	}

	function test_screenEdgePlacementAndViewportBudget() {
		const screen = { width: 1000, height: 640 };
		for (const scale of [0.8, 1.3]) {
			const left = Preview.previewPlacement({ x: 0, y: 600, width: 36 }, { width: 220, height: 160 }, screen, scale);
			const right = Preview.previewPlacement({ x: 980, y: 600, width: 36 }, { width: 220, height: 160 }, screen, scale);
			verify(left.x >= 8 && left.x + 220 * scale <= 992);
			verify(right.x >= 8 && right.x + 220 * scale <= 992);
			verify(left.y >= 8 && left.y + 160 * scale <= 592);
		}
		compare(Preview.liveCards({ left: 0, right: 700 }, [
			{ left: 0, right: 220 }, { left: 232, right: 452 }, { left: 464, right: 684 }, { left: 696, right: 916 }, { left: 928, right: 1148 }
		]), [0, 1, 2], "only three cards stream even if a fourth clips the viewport");
	}
}
