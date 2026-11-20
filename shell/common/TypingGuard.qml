import QtQuick
import "tokens.js" as Tokens

// Owner: while typing in a search box the mouse does nothing until it moves.
// Results reflowing under a still pointer re-deliver hover at the same spot;
// only a real move past the slop, or the pointer coming in from outside,
// hands hover back. Put it on the view's root and gate row hover on `!typing`.
HoverHandler {
	id: guard

	property bool typing: false
	property point _at
	property bool _known: false

	function typed() {
		guard._known = guard.hovered;
		guard._at = guard.point.scenePosition;
		guard.typing = true;
	}

	onPointChanged: {
		if (!guard.typing || !guard.hovered) return;
		const p = guard.point.scenePosition;
		if (!guard._known || Math.hypot(p.x - guard._at.x, p.y - guard._at.y) > Tokens.typingGuard.slop)
			guard.typing = false;
	}
}
