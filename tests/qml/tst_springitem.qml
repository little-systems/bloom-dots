import QtQuick
import QtTest
import "../../shell/common"
import "../../shell/common/render"

TestCase {
	name: "Spring"
	function init() { Render.animationStyle = "bloom"; Render.reduceMotion = false; }
	function cleanup() { Render.animationStyle = "macos"; Render.reduceMotion = false; }

	Component {
		id: springComponent
		Spring { autoRun: false }
	}

	function make(props) {
		const s = createTemporaryObject(springComponent, null, props);
		verify(s !== null);
		return s;
	}

	function test_macStyleSettlesWithoutOvershooting() {
		Render.animationStyle = "macos";
		const s = make({ stiffness: 500, damping: 20, initial: 0, target: 100 });
		let previous = 0;
		for (let i = 0; i < 120; i++) {
			s.step(0.016);
			verify(s.value >= previous && s.value <= 100);
			previous = s.value;
		}
		verify(s.settled);
	}

	function test_reducedMotionSkipsInitialAndActiveMovement() {
		Render.reduceMotion = true;
		const s = make({ initial: 0, target: 100 });
		compare(s.value, 100); verify(s.settled);
		Render.reduceMotion = false;
		s.target = 200; s.step(0.016); verify(!s.settled);
		Render.reduceMotion = true;
		compare(s.value, 200); verify(s.settled);
	}

	function test_startsAtTargetByDefault() {
		const s = make({ target: 140 });
		compare(s.value, 140);
		verify(s.settled);
	}

	function test_initialValue() {
		const s = make({ target: 140, initial: 30.6 });
		compare(s.value, 30.6);
		verify(!s.settled);
	}

	function test_stepFollowsFramerCurve() {
		const s = make({ stiffness: 500, damping: 30, initial: 0, target: 100 });
		s.step(0.05);
		fuzzyCompare(s.value, 36.586, 0.001);
	}

	// framer-motion keeps position and velocity when the target changes mid-flight.
	function test_retargetKeepsVelocity() {
		const s = make({ stiffness: 400, damping: 31, initial: 140, target: 340 });
		s.step(0.05);
		const value = s.value, velocity = s.velocity;
		verify(velocity > 0);
		s.target = 140;
		compare(s.value, value);
		compare(s.velocity, velocity);
		s.step(0.016);
		verify(s.value > value, "still moving toward the old target for a moment");
	}

	function test_settlesExactlyOnTarget() {
		const s = make({ stiffness: 450, damping: 29, initial: 36, target: 120 });
		for (let i = 0; i < 200 && !s.settled; i++) s.step(0.016);
		verify(s.settled);
		compare(s.value, 120);
		compare(s.velocity, 0);
	}

	function test_granularMovesUseFineThresholds() {
		const s = make({ stiffness: 600, damping: 30, mass: 0.5, initial: 0.1, target: 0.9 });
		s.step(0.1);
		verify(!s.settled || Math.abs(s.value - 0.9) <= 0.005);
	}

	function test_nonFiniteTargetIsIgnored() {
		const s = make({ initial: 10, target: 20 });
		s.target = NaN;
		s.step(0.016);
		verify(isFinite(s.value), "value must never become NaN");
	}

	function test_jump() {
		const s = make({ initial: 0, target: 100 });
		s.step(0.05);
		s.jump(250);
		compare(s.value, 250);
		compare(s.velocity, 0);
		verify(!s.settled);
	}
}
