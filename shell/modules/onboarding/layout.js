.pragma library

// Bloom's guide placement (Onboarding.tsx at 63a9bf5): a 500×400 card scaled
// to fit, centred, 96 px from the anchored edge; arrows outside the card when
// that gap holds them, inside otherwise.
var CARD_WIDTH = 500;
var CARD_HEIGHT = 400;
var NOTIFICATION_COLUMN = 396;

function place(anchor, viewWidth, viewHeight, scale) {
	var fit = Math.max(0.4, Math.min(scale, (viewWidth - 40) / CARD_WIDTH, (viewHeight - 160) / CARD_HEIGHT));
	var width = CARD_WIDTH * fit, height = CARD_HEIGHT * fit;
	var edgeGap = Math.min(96 * fit, (viewHeight - height) / 2);
	var y = anchor === "island" || anchor === "notifications" ? edgeGap : anchor === "dock" ? viewHeight - height - edgeGap : (viewHeight - height) / 2;
	// Notifications (ours): near the top-right corner but left of the
	// notification column (NotificationCards: 396 px at the UI scale), so the
	// sample the page sends isn't covered.
	var x = anchor === "notifications" ? Math.max(20, viewWidth - NOTIFICATION_COLUMN * scale - 24 * fit - width) : (viewWidth - width) / 2;
	return { scale: fit, width: width, height: height, x: x, y: y, edgeGap: edgeGap };
}

// The arrow in card units (the card's own 500×400 frame, before scaling).
// The notifications page (ours) mirrors it to point up-right at the corner.
function arrow(anchor, viewWidth, viewHeight, scale) {
	if (anchor !== "island" && anchor !== "dock" && anchor !== "notifications")
		return null;
	var p = place(anchor, viewWidth, viewHeight, scale);
	var down = anchor === "dock";
	var mirror = anchor === "notifications";
	if (p.edgeGap / p.scale >= 88)
		return down ? { inside: false, x: CARD_WIDTH / 2 - 188, y: CARD_HEIGHT + 54 - 56, width: 112, height: 56, rotation: 180, mirror: false }
			: mirror ? { inside: false, x: CARD_WIDTH - 112, y: -56, width: 112, height: 56, rotation: 0, mirror: true }
			: { inside: false, x: CARD_WIDTH / 2 + 76, y: -56, width: 112, height: 56, rotation: 0, mirror: false };
	return { inside: true, x: CARD_WIDTH - 24 - 32, y: down ? 63 : 65, width: 32, height: 28, rotation: down ? 180 : 0, mirror: mirror };
}

// What takes input: the card plus 20 px and the arrow plus 4 px (Bloom's
// measureElements), in screen coordinates.
function region(anchor, viewWidth, viewHeight, scale) {
	var p = place(anchor, viewWidth, viewHeight, scale);
	var rects = [{ x: p.x - 20, y: p.y - 20, width: p.width + 40, height: p.height + 40 }];
	var a = arrow(anchor, viewWidth, viewHeight, scale);
	if (a)
		rects.push({ x: p.x + a.x * p.scale - 4, y: p.y + a.y * p.scale - 4, width: a.width * p.scale + 8, height: a.height * p.scale + 8 });
	return rects;
}
