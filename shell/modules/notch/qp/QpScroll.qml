import QtQuick
import "../../../common"
import "../../../common/tokens.js" as Tokens

// Scrolling over a Bloom list (.qp-list): put it on an item over `flickable`,
// which sets interactive: false (a browser list doesn't drag, and a Flickable
// lets touchpad scrolls past it). It owns every scroll over it, overflowing
// or not, so none reach the notch's panel switching (Bloom's handleWheel
// skips .qp-list): a touchpad moves it by pixels and stretches past the ends,
// a wheel moves 100 px a notch, both on a spring that lands with a small bounce.
WheelHandler {
	id: root

	required property Flickable flickable

	function _clamp(y) { return Math.max(0, Math.min(Math.max(0, root.flickable.contentHeight - root.flickable.height), y)); }

	target: null
	acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
	onWheel: event => {
		const f = root.flickable;
		if (event.pixelDelta.y !== 0 && event.device.type === PointerDevice.TouchPad) {
			root._driving = false;
			const next = f.contentY - event.pixelDelta.y;
			const past = next !== root._clamp(next);
			// Past an end the fingers drag against resistance.
			f.contentY = past ? f.contentY - event.pixelDelta.y * Tokens.scroll.resistance : next;
			settle.restart();
		} else {
			const from = root._driving ? spring.target : f.contentY;
			if (!root._driving) spring.jump(f.contentY);
			root._driving = true;
			spring.target = root._clamp(from - event.angleDelta.y / 120 * 100);
		}
	}

	property bool _driving: false
	// Lifted fingers, or a wheel that ran out: spring home from wherever it is.
	readonly property Timer _settle: Timer {
		id: settle
		interval: Tokens.scroll.settleMs
		onTriggered: {
			const y = root.flickable.contentY;
			if (y === root._clamp(y)) return;
			spring.jump(y);
			root._driving = true;
			spring.target = root._clamp(y);
		}
	}
	readonly property Spring _spring: Spring {
		id: spring
		stiffness: Tokens.scroll.stiffness
		damping: Tokens.scroll.damping
		onValueChanged: if (root._driving) root.flickable.contentY = spring.value
		onSettledChanged: if (spring.settled) root._driving = false
	}
}
