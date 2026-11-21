.pragma library

// The Alt + Tab switcher's pure parts. Hyprland's alt-tab.lua sends window
// addresses, most recent first, comma separated.

// Hyprland's reload restarts alt-tab.lua's count; messages of one cycle land
// within a few hundred ms of each other, so a lower seq after this long is a
// restart, not a late message.
var restartAfterMs = 2000;

function parse(text) {
	return String(text || "").split(",").filter(a => /^0x[0-9a-f]+$/.test(a));
}

function clamp(index, count) {
	return count > 0 ? Math.max(0, Math.min(count - 1, index)) : 0;
}

// Tiles across: one per window, up to `most`.
function columns(count, most) {
	return Math.max(1, Math.min(count, most));
}

// Each `bloom ipc` is its own process, so messages can land out of order:
// only one newer than the last taken counts.
function fresh(seq, last, sinceLastMs) {
	return seq > last || sinceLastMs > restartAfterMs;
}
