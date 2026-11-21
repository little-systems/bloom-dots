.pragma library

// The Alt + Tab switcher's pure parts. Hyprland's alt-tab.lua sends window
// addresses, most recent first, comma separated.

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
