// Tool-panel navigation is separate from live music, timer and Shelf activity.
var ORDER = ["calendar", "command-center", "devices"];

function available(settings) {
	const panels = ORDER.filter(p => settings[p] !== false);
	return panels.length ? panels : ["command-center"];
}

function opening(last, preferred, remember, enabled) {
	const panels = available(enabled);
	if (!panels.length) return "";
	if (remember && panels.includes(last)) return last;
	if (panels.includes(preferred)) return preferred;
	return panels[0];
}

function cycle(current, direction, enabled) {
	const panels = available(enabled);
	if (!panels.length) return "";
	const at = panels.indexOf(current);
	if (at < 0) return panels[0];
	return panels[(at + (direction < 0 ? -1 : 1) + panels.length) % panels.length];
}

// devicesHeight: the Devices panel's measured content (Bloom DEVICES_MIN/MAX_HEIGHT).
function size(panel, calendarRows, devicesHeight, shelfCount) {
	if (panel === "calendar") return { width: 480, height: calendarRows >= 6 ? 305 : 273 };
	if (panel === "command-center") return { width: 350, height: 230 };
	if (panel === "wifi" || panel === "bluetooth") return { width: 350, height: 300 };
	if (panel === "devices") return { width: 350, height: Math.max(150, Math.min(300, Math.ceil(devicesHeight || 0))) };
	if (panel === "shelf") return { width: 380, height: shelfCount > 1 ? 190 : shelfCount === 1 ? 176 : 130 };
	return null;
}

// The content's inset from the pill's sides. Bloom's panel content box pads
// 12 px, and its .qp (Wi-Fi, Bluetooth) sits inside it; the Command Center
// and shelf use 14; the calendar lays out edge to edge.
function inset(panel) {
	if (panel === "calendar") return 0;
	if (panel === "command-center" || panel === "shelf") return 14;
	return 12;
}
