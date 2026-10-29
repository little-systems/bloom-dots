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

var MAX_TIMER_SECONDS = 180 * 60;

// Bloom's right-to-left timer digits: "130" = 1:30, "2500" = 25:00. The last
// two digits are seconds as typed (Bloom doesn't cap them at 59).
function timerDigits(digits) {
	if (!/^\d{1,5}$/.test(digits || "")) return null;
	const seconds = parseInt(digits.slice(-2) || "0", 10);
	const minutes = parseInt(digits.slice(0, -2) || "0", 10);
	const total = minutes * 60 + seconds;
	return total > 0 && total <= MAX_TIMER_SECONDS ? total : null;
}

// The digits being typed as a clock ("130" -> "1:30").
function formatDigits(digits) {
	if (!digits) return "0:00";
	const seconds = digits.slice(-2).padStart(2, "0");
	const minutes = parseInt(digits.slice(0, -2) || "0", 10);
	return `${minutes}:${seconds}`;
}

// A duration as the digits an edit starts from (1500 -> "2500").
function secondsToDigits(total) {
	const minutes = Math.floor(total / 60);
	const seconds = total % 60;
	return `${minutes}${String(seconds).padStart(2, "0")}`.replace(/^0+(?=\d)/, "");
}

// Bloom's formatTimerTime: "m:ss".
function clockText(total) {
	const safe = Math.abs(Math.floor(total));
	return `${Math.floor(safe / 60)}:${String(safe % 60).padStart(2, "0")}`;
}

// The clock's digits: minutes padded to two, compact once they need three.
function clockDigits(text) {
	const parts = text.split(":");
	const minutes = parts[0].padStart(2, "0");
	return { minutes: minutes.split(""), seconds: parts[1].split(""), compact: minutes.length > 2 };
}

// The line above the clock. `t` is { editing, finished, running, remaining }.
function status(t, now, use24h) {
	if (t.editing) return "Set duration";
	if (t.finished) return "Time's up";
	if (t.remaining > 0) {
		const ends = new Date(now.getTime() + t.remaining * 1000);
		const h = ends.getHours();
		const mm = String(ends.getMinutes()).padStart(2, "0");
		const time = use24h ? `${String(h).padStart(2, "0")}:${mm}`
			: `${String(h % 12 || 12).padStart(2, "0")}:${mm} ${h < 12 ? "AM" : "PM"}`;
		return `${t.running ? "" : "Paused · "}ends ${time}`;
	}
	return "Click to edit";
}

function primaryLabel(running, remaining, finished) {
	return running ? "Pause" : remaining > 0 ? "Resume" : finished ? "Restart" : "Start";
}

function remaining(deadlineMs, pausedSec, nowMs) {
	if (deadlineMs > 0) return Math.max(0, Math.ceil((deadlineMs - nowMs) / 1000));
	return Math.max(0, Math.floor(pausedSec));
}

function timerText(seconds) {
	const safe = Math.max(0, Math.floor(seconds));
	return String(Math.floor(safe / 60)).padStart(2, "0") + ":" + String(safe % 60).padStart(2, "0");
}

// Bloom's states from the saved file: running (a deadline), paused (time
// left), idle (pausedSec 0, the clock shows the duration) or finished.
function restored(raw, nowMs) {
	const durationSec = Number.isInteger(raw?.durationSec) && raw.durationSec >= 1 && raw.durationSec <= MAX_TIMER_SECONDS ? raw.durationSec : 1500;
	const expired = Number.isFinite(raw?.deadlineMs) && raw.deadlineMs > 0 && raw.deadlineMs <= nowMs;
	const deadlineMs = Number.isFinite(raw?.deadlineMs) && raw.deadlineMs > nowMs && raw.deadlineMs <= nowMs + MAX_TIMER_SECONDS * 1000 ? raw.deadlineMs : 0;
	let pausedSec = Number.isInteger(raw?.pausedSec) && raw.pausedSec >= 0 && raw.pausedSec <= MAX_TIMER_SECONDS ? raw.pausedSec : 0;
	// Before Bloom's states, a reset left pausedSec at the duration: idle.
	if (!deadlineMs && pausedSec >= durationSec) pausedSec = 0;
	return { durationSec, deadlineMs, pausedSec: expired || deadlineMs ? 0 : pausedSec, finished: expired || raw?.finished === true, expired };
}
