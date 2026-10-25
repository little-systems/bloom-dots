// Fails if shell/common/spring.js drifts from framer-motion's spring for any
// spring Bloom uses (spec Appendix A). Samples every millisecond of a
// 0 -> 100 px move until framer reports the spring at rest; framer snaps to
// the target at that point, so the comparison stops there.
import { spring } from "motion-dom";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const TOLERANCE_PX = 0.01;
const SPRINGS = [
	{ name: "pill width", stiffness: 400, damping: 31, mass: 1 },
	{ name: "pill height", stiffness: 450, damping: 29, mass: 1 },
	{ name: "pill y", stiffness: 550, damping: 45, mass: 0.8 },
	{ name: "corner radii", stiffness: 1000, damping: 40, mass: 1 },
	{ name: "default", stiffness: 500, damping: 30, mass: 1 },
	{ name: "clock flip", stiffness: 600, damping: 30, mass: 1 },
	{ name: "visualizer bar", stiffness: 600, damping: 30, mass: 0.5 },
	{ name: "button press", stiffness: 400, damping: 25, mass: 1 }
];

const ctx = {};
vm.createContext(ctx);
vm.runInContext(readFileSync(new URL("../../shell/common/spring.js", import.meta.url), "utf8"), ctx);

let failed = false;
for (const s of SPRINGS) {
	const framer = spring({ keyframes: [0, 100], stiffness: s.stiffness, damping: s.damping, mass: s.mass });
	let worst = 0;
	let t = 0;
	for (; t <= 10000; t++) {
		const f = framer.next(t);
		if (f.done) break;
		const ours = 100 + ctx.springStep(s.stiffness, s.damping, s.mass, -100, 0, t / 1000)[0];
		worst = Math.max(worst, Math.abs(f.value - ours));
	}
	const ok = worst <= TOLERANCE_PX;
	failed ||= !ok;
	console.log(`${ok ? "ok  " : "FAIL"} ${s.name} ${s.stiffness}/${s.damping}/${s.mass}: max error ${worst.toExponential(2)} px over ${t} ms`);
}
process.exit(failed ? 1 : 0);
