// Backend capability vocabulary and restart pacing. Plain JS (shared with tests).
// A capability says whether a backend can serve requests now; it is separate
// from what the owner configured and from the device state it reports.
// state: "available" | "degraded" | "missing" | "stopped" | "unknown"

const STATES = ["available", "degraded", "missing", "stopped", "unknown"];

// 1 s, 2 s, 4 s ... capped, so a broken backend can't spin or be forgotten.
function backoffMs(attempt, baseMs, capMs) {
	const n = Math.max(1, attempt | 0);
	return Math.min(capMs, baseMs * Math.pow(2, Math.min(n - 1, 20)));
}

function entry(state, reason, attempts, sinceMs) {
	return {
		state: STATES.indexOf(state) >= 0 ? state : "unknown",
		reason: String(reason || "").slice(0, 160),
		attempts: Math.max(0, attempts | 0),
		since: sinceMs,
	};
}

// The worst state wins when a backend has several processes.
function worst(states) {
	const order = ["missing", "degraded", "unknown", "available", "stopped"];
	let best = "stopped";
	for (const s of states)
		if (order.indexOf(s) < order.indexOf(best)) best = s;
	return best;
}
