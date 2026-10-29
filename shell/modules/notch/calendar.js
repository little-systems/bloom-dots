function monthGrid(year, month) {
	if (!Number.isInteger(year) || !Number.isInteger(month) || month < 0 || month > 11) return [];
	const first = new Date(year, month, 1).getDay();
	const days = new Date(year, month + 1, 0).getDate();
	const rows = Math.ceil((first + days) / 7);
	return Array.from({ length: rows * 7 }, (_, index) => {
		const day = index - first + 1;
		return { day, inMonth: day >= 1 && day <= days };
	});
}

function monthRows(year, month) { return monthGrid(year, month).length / 7; }

// Bloom's right-to-left timer digits: "130" = 1:30, "2500" = 25:00.
function timerDigits(digits) {
	if (!/^\d{1,6}$/.test(digits || "")) return null;
	const value = digits.padStart(3, "0");
	const seconds = Number(value.slice(-2));
	const minutes = Number(value.slice(0, -2));
	const total = minutes * 60 + seconds;
	return seconds < 60 && total > 0 && total <= 180 * 60 ? total : null;
}

function remaining(deadlineMs, pausedSec, nowMs) {
	if (deadlineMs > 0) return Math.max(0, Math.ceil((deadlineMs - nowMs) / 1000));
	return Math.max(0, Math.floor(pausedSec));
}

function timerText(seconds) {
	const safe = Math.max(0, Math.floor(seconds));
	return String(Math.floor(safe / 60)).padStart(2, "0") + ":" + String(safe % 60).padStart(2, "0");
}

function restored(raw, nowMs) {
	const durationSec = Number.isInteger(raw?.durationSec) && raw.durationSec >= 1 && raw.durationSec <= 180 * 60 ? raw.durationSec : 1500;
	const expired = Number.isFinite(raw?.deadlineMs) && raw.deadlineMs > 0 && raw.deadlineMs <= nowMs;
	const deadlineMs = Number.isFinite(raw?.deadlineMs) && raw.deadlineMs > nowMs && raw.deadlineMs <= nowMs + 180 * 60 * 1000 ? raw.deadlineMs : 0;
	const pausedSec = Number.isInteger(raw?.pausedSec) && raw.pausedSec >= 0 && raw.pausedSec <= 180 * 60 ? raw.pausedSec : durationSec;
	return { durationSec, deadlineMs, pausedSec: expired ? 0 : deadlineMs ? pausedSec : Math.min(pausedSec, durationSec), expired };
}
