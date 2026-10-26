// Notch pulses ported from Bloom (App.tsx @ b5fb962), plus the workspace
// pulse (spec D7). Plain JS, shared with the unit tests.

// Bloom showPowerPulse: the charging flag changed. The first reading (the
// battery as UPower first reports it) is not a change.
function powerPulse(prevCharging, charging) {
	return prevCharging !== null && prevCharging !== charging;
}

// Bloom showLowBatteryPulse: once per drop to the threshold while
// discharging; charging or recovering above it re-arms. An unknown battery
// keeps the state as it was.
function lowBatteryStep(armed, b) {
	if (!b.available || !b.ready)
		return { fire: false, armed: armed };
	if (b.charging || b.level > b.threshold)
		return { fire: false, armed: true };
	return { fire: armed, armed: false };
}

function workspacePulse(prevId, id) {
	return prevId !== null && id !== null && prevId !== id;
}

// One slot: the newest kind (the workspace pulse is the shortest) first,
// then Bloom's update-over-battery order. Hover and the open player win
// over all of them (Bloom !isHovered).
function activePulse(s) {
	if (s.hovered || s.open)
		return "";
	if (s.workspace)
		return "workspace";
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
	const state = kind === "low" ? "Low Battery" : b.charging ? "Charging" : "On Battery";
	return `${state} • ${b.level}%`;
}

function workspaceLabel(ws) {
	return ws.name && ws.name !== String(ws.id) ? ws.name : `Workspace ${ws.id}`;
}

// Page dots fit the 176 px row beside the label for up to 6 workspaces.
function pageDots(ws) {
	const ids = ws.ids.slice().sort((a, b) => a - b);
	return ids.length >= 2 && ids.length <= 6 ? ids : [];
}

// Bloom's triggerEventPeek replaced the running peek; here a shorter peek
// never ends a longer one early (it would hide a pulse still on screen).
function peekUntil(now, current, ms) {
	return Math.max(current, now + ms);
}
