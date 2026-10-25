// Battery tooltip and fill colour, ported from Bloom batteryTooltip.ts and
// App.tsx BatteryIcon. Plain JS (shared with tests).

// Durations as the Windows taskbar writes them: "3 hr 12 min", "45 min", "1 hr".
function formatDuration(seconds) {
	const minutes = Math.max(1, Math.round(seconds / 60));
	const hours = Math.floor(minutes / 60);
	const rest = minutes % 60;
	if (hours === 0)
		return `${rest} min`;
	return rest === 0 ? `${hours} hr` : `${hours} hr ${rest} min`;
}

function tooltip(d) {
	const lines = [];
	if (d.pluggedIn && d.level >= 100 && !d.charging)
		lines.push(`Fully charged (${d.level}%)`);
	else if (d.pluggedIn)
		lines.push(`${d.level}% available (plugged in${d.charging ? ", charging" : ", not charging"})`);
	else if (d.secondsLeft)
		lines.push(`${formatDuration(d.secondsLeft)} (${d.level}%) remaining`);
	else
		lines.push(`${d.level}% remaining`);
	if (d.charging && d.secondsToFull)
		lines.push(`About ${formatDuration(d.secondsToFull)} until full`);
	if (d.powerMode)
		lines.push(`Power mode: ${d.powerMode}`);
	if (d.energySaver)
		lines.push("Energy saver is on");
	if (d.healthPercent !== null && d.healthPercent !== undefined)
		lines.push(`Battery health: ${d.healthPercent}% of original capacity`);
	return lines.join("\n");
}

function fillKind(level, charging, threshold) {
	if (charging)
		return "charging";
	return level <= threshold ? "low" : "normal";
}
