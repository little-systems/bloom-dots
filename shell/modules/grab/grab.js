.pragma library

// The floating-window grab handle's pure parts (owner's request: apps like
// Spotify draw no title bar to drag). Hyprland gives windows in layout pixels
// (`at`, `size`) and monitors in device pixels with a scale.

// The focused floating window on monitor `monitorId`, or null. Focus follows
// the mouse, so that's the one under the pointer.
function target(windows, monitorId) {
	for (const w of windows || []) {
		if (!w || w.focusHistoryID !== 0) continue;
		if (!w.floating || w.fullscreen || w.hidden || w.mapped === false) continue;
		if (w.monitor !== monitorId || !w.at || !w.size) continue;
		return w;
	}
	return null;
}

function _bounds(monitor) {
	const scale = monitor.scale || 1;
	return { x: monitor.x, y: monitor.y, width: monitor.width / scale, height: monitor.height / scale };
}

// Where the hover zone goes, in the screen's own coordinates: centred on the
// window's top edge, half above it, no wider than the window, on screen.
function zone(win, monitor, sizes) {
	const width = Math.min(sizes.zoneWidth, win.width);
	return {
		x: Math.round(win.x - monitor.x + (win.width - width) / 2),
		y: Math.max(0, Math.round(win.y - monitor.y - sizes.zoneHeight / 2)),
		width: width,
		height: sizes.zoneHeight
	};
}

// Where a drag puts the window: it follows the pointer, but keeps its top
// edge on screen and `keep` pixels of it in reach, so it can't be lost.
function moved(start, pressedAt, pointer, size, monitor, sizes) {
	const b = _bounds(monitor);
	const x = start.x + pointer.x - pressedAt.x;
	const y = start.y + pointer.y - pressedAt.y;
	return {
		x: Math.round(Math.max(b.x + sizes.keep - size.width, Math.min(b.x + b.width - sizes.keep, x))),
		y: Math.round(Math.max(b.y, Math.min(b.y + b.height - sizes.keep, y)))
	};
}

// The Hyprland dispatch that puts the window there, or "" for an address
// that isn't one (Quickshell drops the 0x).
function dispatch(address, at) {
	const hex = String(address || "").replace(/^0x/, "");
	if (!/^[0-9a-f]+$/.test(hex)) return "";
	return 'hl.dsp.window.move({ x = ' + at.x + ', y = ' + at.y + ', relative = false, window = "address:0x' + hex + '" })';
}
