// Notch pulses ported from Bloom (App.tsx @ b5fb962). Plain JS, shared with
// the unit tests.

// Bloom showPowerPulse: the charger was connected or disconnected. This
// follows the charger, not UPower's charge state, which leaves Charging when
// the battery is full or at a charge limit with the charger still in. The
// first reading (as UPower first reports it) is not a change.
function powerPulse(prevPluggedIn, pluggedIn) {
	return prevPluggedIn !== null && prevPluggedIn !== pluggedIn;
}

// Bloom showLowBatteryPulse: once per drop to the threshold on battery;
// plugging in or recovering above it re-arms. An unknown battery
// keeps the state as it was.
function lowBatteryStep(armed, b) {
	if (!b.available || !b.ready)
		return { fire: false, armed: armed };
	if (b.pluggedIn || b.level > b.threshold)
		return { fire: false, armed: true };
	return { fire: armed, armed: false };
}

// One slot, in Bloom's update-over-battery order. Hover and the open player
// win over all of them (Bloom !isHovered).
function activePulse(s) {
	if (s.hovered || s.open)
		return "";
	if (s.update)
		return "update";
	if (s.low)
		return "low";
	if (s.power)
		return "power";
	return "";
}

// Bloom's AnimatePresence keys: charging and low battery share pulse-view,
// so switching between them changes the label without a swap.
function viewKey(kind) {
	if (kind === "low" || kind === "power")
		return "battery";
	return kind;
}

function batteryLabel(kind, b) {
	const state = kind === "low" ? "Low Battery" : b.pluggedIn ? "Charging" : "On Battery";
	return `${state} • ${b.level}%`;
}

// Bloom's triggerEventPeek replaced the running peek; here a shorter peek
// never ends a longer one early (it would hide a pulse still on screen).
function peekUntil(now, current, ms) {
	return Math.max(current, now + ms);
}
