import QtQuick
import "render"
import "tokens.js" as Tokens

// One input owner for vertical lists and horizontal strips. Wheel bursts
// retarget a spring; touchpad strokes coast after release. Native momentum
// is already decelerated by the platform, so it is never amplified again.
WheelHandler {
	id: root
	required property Flickable flickable
	property bool horizontal: false
	property bool clampOnRangeChange: true
	signal userScrolled()
	parent: flickable
	target: null
	enabled: flickable.visible && flickable.enabled
	acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
	readonly property real minimum: horizontal ? flickable.originX : flickable.originY
	readonly property real maximum: minimum + Math.max(0, horizontal ? flickable.contentWidth - flickable.width : flickable.contentHeight - flickable.height)
	readonly property real position: horizontal ? flickable.contentX : flickable.contentY
	property bool _driving: false
	property bool _coasting: false
	property bool _writing: false
	property real _velocity: 0
	property real _lastInput: 0
	property bool _nativeMomentum: false

	function _clamp(v) { return Math.max(minimum, Math.min(maximum, v)); }
	function _write(v) {
		_writing = true;
		if (horizontal) flickable.contentX = v;
		else flickable.contentY = v;
		_writing = false;
	}
	function stop() {
		_driving = false; _coasting = false; _velocity = 0;
		_lastInput = 0; _nativeMomentum = false; settle.stop();
		spring.target = position; spring.jump(position);
	}
	function _home() {
		_coasting = false;
		const end = _clamp(position);
		if (Math.abs(position - end) < 0.01) return;
		spring.jump(position); _driving = true; spring.target = end;
	}
	// Also used by deterministic tests to supply timestamped touchpad strokes.
	function scroll(delta, pixels, now, phase) {
		if (phase === Qt.ScrollBegin) stop();
		if (phase === Qt.ScrollMomentum) _nativeMomentum = true;
		if (!isFinite(delta) || maximum <= minimum) { stop(); _write(minimum); return; }
		if (Render.reduceMotion) { stop(); _write(_clamp(position + delta)); return; }
		if (pixels) {
			const elapsed = now - _lastInput;
			if (delta !== 0) {
				const speed = delta / Math.max(8, Math.min(50, elapsed || 16)) * 1000;
				_velocity = elapsed > 100 || _velocity * speed < 0 ? speed : _velocity * 0.35 + speed * 0.65;
				_velocity = Math.max(-Tokens.scroll.maxVelocity, Math.min(Tokens.scroll.maxVelocity, _velocity));
				_lastInput = now;
				_driving = false; _coasting = false;
				const next = position + delta;
				const v = next !== _clamp(next) ? position + delta * Tokens.scroll.resistance : next;
				_write(Math.max(minimum - Tokens.scroll.overscroll, Math.min(maximum + Tokens.scroll.overscroll, v)));
			}
			settle.restart();
		} else if (delta !== 0) {
			settle.stop(); _coasting = false; _velocity = 0; _lastInput = 0; _nativeMomentum = false;
			const from = _driving ? spring.target : position;
			if (!_driving) spring.jump(position);
			const end = _clamp(from + delta);
			_driving = Math.abs(position - end) > 0.01; spring.target = end;
		}
	}
	// A wheel-driven value control (e.g. an app volume tile) owns its input.
	function _controlAt(x, y) {
		let item = flickable;
		let point = flickable.mapFromItem(parent, x, y);
		while (item) {
			if (item.ownsScrollWheel === true) return true;
			const child = item.childAt(point.x, point.y);
			if (!child) break;
			point = child.mapFromItem(item, point.x, point.y); item = child;
		}
		return false;
	}
	onWheel: event => {
		if (_controlAt(event.x, event.y)) { stop(); event.accepted = false; return; }
		userScrolled();
		const pixel = horizontal ? (event.pixelDelta.x || event.pixelDelta.y) : event.pixelDelta.y;
		const angle = horizontal ? (event.angleDelta.x || event.angleDelta.y) : event.angleDelta.y;
		const pixels = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0 || event.phase !== Qt.NoScrollPhase;
		scroll(pixels ? -pixel : -angle / 120 * Tokens.scroll.wheelStep, pixels, Date.now(), event.phase);
	}
	onEnabledChanged: if (!enabled) { stop(); _write(_clamp(position)); }
	onMaximumChanged: if (clampOnRangeChange) { stop(); _write(_clamp(position)); }
	onMinimumChanged: if (clampOnRangeChange) { stop(); _write(_clamp(position)); }
	// A passive press observer brakes momentum without taking a row's click.
	readonly property TapHandler _pressBrake: TapHandler { // cursor: default — passive momentum brake; child controls own their cursors
		parent: root.flickable
		onPressedChanged: if (pressed) root.stop()
	}
	readonly property Connections _positionWatch: Connections {
		target: root.flickable
		function onContentXChanged() { if (root.horizontal && !root._writing) root.stop(); }
		function onContentYChanged() { if (!root.horizontal && !root._writing) root.stop(); }
	}
	readonly property Connections _motionWatch: Connections {
		target: Render
		function onReduceMotionChanged() { if (Render.reduceMotion) { const end = root._driving ? spring.target : root._clamp(root.position); root.stop(); root._write(end); } }
	}
	readonly property Timer _settle: Timer {
		id: settle
		interval: Tokens.scroll.settleMs
		onTriggered: {
			if (root.position !== root._clamp(root.position)) root._home();
			else if (!root._nativeMomentum && Math.abs(root._velocity) > Tokens.scroll.stopVelocity) root._coasting = true;
			else root._velocity = 0;
		}
	}
	readonly property FrameAnimation _coast: FrameAnimation {
		running: root.enabled && root._coasting
		onTriggered: {
			const dt = Math.min(frameTime, 0.05);
			const decay = Math.exp(-Tokens.scroll.friction * dt);
			const next = root.position + root._velocity * (1 - decay) / Tokens.scroll.friction;
			root._velocity *= decay;
			if (next !== root._clamp(next)) { root._write(root._clamp(next)); root._coasting = false; root._velocity = 0; }
			else { root._write(next); if (Math.abs(root._velocity) < Tokens.scroll.stopVelocity) { root._coasting = false; root._velocity = 0; } }
		}
	}
	readonly property Spring _spring: Spring {
		id: spring
		stiffness: Tokens.scroll.stiffness; damping: Tokens.scroll.damping
		onValueChanged: if (root._driving) root._write(spring.value)
		onSettledChanged: if (spring.settled) root._driving = false
	}
}
