// Damped spring maths shared by Spring.qml, the QML unit tests and the
// framer-motion parity test (tests/parity). Plain JS on purpose: no .pragma
// and no exports, so Node can evaluate the same file.

// Exact state of a damped spring after dt seconds, starting at offset d0
// (value - target) with velocity v0. Parameters are framer-motion's:
// stiffness k, damping c, mass m. Returns [offset, velocity].
// Stepping from the current state each frame is exact for any frame time,
// and keeps velocity when the target changes mid-flight, as framer-motion does.
function springStep(k, c, m, d0, v0, dt) {
	const w0 = Math.sqrt(k / m);
	const z = c / (2 * Math.sqrt(k * m));
	if (z < 1) {
		const wd = w0 * Math.sqrt(1 - z * z);
		const e = Math.exp(-z * w0 * dt);
		const A = d0;
		const B = (v0 + z * w0 * d0) / wd;
		const cs = Math.cos(wd * dt);
		const sn = Math.sin(wd * dt);
		const d = e * (A * cs + B * sn);
		return [d, -z * w0 * d + e * wd * (B * cs - A * sn)];
	}
	if (z === 1) {
		const e = Math.exp(-w0 * dt);
		const C = v0 + w0 * d0;
		const d = (d0 + C * dt) * e;
		return [d, C * e - w0 * d];
	}
	const s = Math.sqrt(z * z - 1);
	const r1 = -w0 * (z - s);
	const r2 = -w0 * (z + s);
	const C2 = (v0 - r1 * d0) / (r2 - r1);
	const C1 = d0 - C2;
	const e1 = Math.exp(r1 * dt);
	const e2 = Math.exp(r2 * dt);
	return [C1 * e1 + C2 * e2, r1 * C1 * e1 + r2 * C2 * e2];
}

// framer-motion treats moves under 5 units (scale, opacity...) as granular
// and uses finer rest thresholds for them.
function isGranular(from, to) {
	return Math.abs(to - from) < 5;
}

// [restDelta, restSpeed]; a negative argument selects framer-motion's default.
function restThresholds(granular, restDelta, restSpeed) {
	return [
		restDelta >= 0 ? restDelta : granular ? 0.005 : 0.5,
		restSpeed >= 0 ? restSpeed : granular ? 0.01 : 2
	];
}
