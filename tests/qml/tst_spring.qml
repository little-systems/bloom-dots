import QtQuick
import QtTest
import "../../shell/common/spring.js" as SpringMath

TestCase {
	name: "SpringMath"

	// value at time t (s) for a 0 -> 100 move
	function at(k, c, m, t) {
		return 100 + SpringMath.springStep(k, c, m, -100, 0, t)[0];
	}

	function test_underdampedMatchesFramerReference() {
		// framer-motion 12.43 (motion-dom spring generator), stiffness 500, damping 30
		fuzzyCompare(at(500, 30, 1, 0.050), 36.586, 0.001);
		fuzzyCompare(at(500, 30, 1, 0.150), 102.563, 0.001);
		fuzzyCompare(at(500, 30, 1, 0.250), 103.057, 0.001);
		fuzzyCompare(at(500, 30, 1, 0.300), 100.682, 0.001);
	}

	function test_criticallyDampedClosedForm() {
		// k=100, c=20, m=1 -> zeta = 1, w0 = 10: d(t) = (d0 + (v0 + w0*d0) t) e^(-w0 t)
		fuzzyCompare(at(100, 20, 1, 0.1), 100 - 200 * Math.exp(-1), 1e-9);
	}

	function test_overdampedIsMonotonic() {
		let prev = 0;
		for (let t = 0.01; t < 1; t += 0.01) {
			const x = at(100, 40, 1, t);
			verify(x >= prev && x <= 100, `overdamped spring overshot at t=${t}: ${x}`);
			prev = x;
		}
	}

	function test_stepsCompose_data() {
		return [
			{ tag: "underdamped", k: 400, c: 31, m: 1 },
			{ tag: "critical", k: 100, c: 20, m: 1 },
			{ tag: "overdamped", k: 100, c: 40, m: 1 },
			{ tag: "light mass", k: 550, c: 45, m: 0.8 }
		];
	}

	// Ten 1 ms steps must land exactly where one 10 ms step does, so frame
	// timing never changes the motion.
	function test_stepsCompose(row) {
		let d = -100, v = 0;
		for (let i = 0; i < 10; i++) [d, v] = SpringMath.springStep(row.k, row.c, row.m, d, v, 0.001);
		const one = SpringMath.springStep(row.k, row.c, row.m, -100, 0, 0.010);
		fuzzyCompare(d, one[0], 1e-9);
		fuzzyCompare(v, one[1], 1e-9);
	}

	function test_restThresholds() {
		compare(SpringMath.restThresholds(false, -1, -1), [0.5, 2]);
		compare(SpringMath.restThresholds(true, -1, -1), [0.005, 0.01]);
		compare(SpringMath.restThresholds(false, 0.001, -1), [0.001, 2]);
	}

	function test_isGranular() {
		verify(SpringMath.isGranular(0, 1));
		verify(!SpringMath.isGranular(0, 5));
		verify(!SpringMath.isGranular(140, 340));
	}
}
