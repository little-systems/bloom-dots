import QtQuick

// Scrolling over a Bloom list (.qp-list): put it on an item over `flickable`,
// which sets interactive: false (a browser list doesn't drag, and a Flickable
// lets touchpad scrolls past it). It owns every scroll over it, overflowing
// or not, so none reach the notch's panel switching (Bloom's handleWheel
// skips .qp-list): a touchpad moves it by pixels, a wheel 100 px a notch,
// eased as Chromium does.
WheelHandler {
	id: root

	required property Flickable flickable

	function _clamp(y) { return Math.max(0, Math.min(Math.max(0, root.flickable.contentHeight - root.flickable.height), y)); }

	target: null
	acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
	onWheel: event => {
		if (event.pixelDelta.y !== 0 && event.device.type === PointerDevice.TouchPad) {
			ease.stop();
			root.flickable.contentY = root._clamp(root.flickable.contentY - event.pixelDelta.y);
		} else {
			const from = ease.running ? ease.to : root.flickable.contentY;
			ease.stop();
			ease.to = root._clamp(from - event.angleDelta.y / 120 * 100);
			ease.start();
		}
	}

	readonly property NumberAnimation _ease: NumberAnimation {
		id: ease
		target: root.flickable
		property: "contentY"
		duration: 150
		easing.type: Easing.OutCubic
	}
}
