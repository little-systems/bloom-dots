import QtQuick
import "render"
import "spring.js" as SpringMath

// A value that follows `target` with framer-motion's spring physics
// (stiffness, damping, mass; seconds), so Bloom's motion carries over exactly.
// Bind a property to `value`. Retargeting mid-flight keeps position and
// velocity, like an interrupted framer-motion animation.
Item {
	id: root
	visible: false

	property real stiffness: 500
	property real damping: 30
	property real mass: 1
	// The default style settles without overshoot across every spring-driven
	// surface. Bloom mode keeps the original imported physics.
	readonly property real effectiveDamping: Render.macMotion ? Math.max(damping, 2 * Math.sqrt(stiffness * mass)) : damping
	// Negative means framer-motion's default (see spring.js restThresholds).
	property real restDelta: -1
	property real restSpeed: -1
	// Starting value; NaN starts at the target.
	property real initial: NaN
	property real target: 0
	// Frames drive the spring; tests turn this off and call step() themselves.
	property bool autoRun: true

	property real value: 0
	property real velocity: 0
	property bool settled: true
	property bool _granular: false

	Component.onCompleted: {
		root.value = Render.reduceMotion || isNaN(root.initial) ? root.target : root.initial;
		root._granular = SpringMath.isGranular(root.value, root.target);
		root.settled = root.value === root.target;
	}

	onTargetChanged: {
		if (!isFinite(root.target)) {
			console.warn(`bloom: Spring ignored non-finite target ${root.target}`);
			return;
		}
		root._granular = SpringMath.isGranular(root.value, root.target);
		root.settled = false;
		if (Render.reduceMotion) root.jump(root.target);
	}

	function jump(v) {
		root.value = v;
		root.velocity = 0;
		root._granular = SpringMath.isGranular(v, root.target);
		root.settled = v === root.target;
	}

	function step(dt) {
		if (root.settled || !isFinite(root.target))
			return;
		const r = SpringMath.springStep(root.stiffness, root.effectiveDamping, root.mass, root.value - root.target, root.velocity, dt);
		const rest = SpringMath.restThresholds(root._granular, root.restDelta, root.restSpeed);
		let x = root.target + r[0];
		let v = r[1];
		if (Math.abs(x - root.target) <= rest[0] && Math.abs(v) <= rest[1]) {
			x = root.target;
			v = 0;
			root.settled = true;
		}
		root.velocity = v;
		root.value = x;
	}

	Connections {
		target: Render
		function onReduceMotionChanged() { if (Render.reduceMotion && isFinite(root.target)) root.jump(root.target); }
	}

	FrameAnimation {
		running: root.autoRun && !root.settled
		// Cap long frames (e.g. after a stall) so the spring never jumps.
		onTriggered: root.step(Math.min(frameTime, 0.064))
	}
}
