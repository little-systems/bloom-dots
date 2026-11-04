// Notch rules ported from Bloom (App.tsx, services.rs @ b5fb962). Plain JS,
// shared with the unit tests.

// Bloom getDynamicWidth for the status mode: the collapsed clock, or the
// hovered strip sized by widget count, never narrower than its content.
function statusWidth(hovered, widgetCount, fitWidth, use24h) {
	const trim = use24h ? 16 : 0;
	if (hovered)
		return Math.max(Math.min(200 + widgetCount * 50, 380) - trim, fitWidth);
	return 140 - trim;
}

// Both sides of the strip get the wider side's width around the centred
// clock, plus the pill's 12 px padding each side and a 10 px gap to the clock.
function fitWidth(clockWidth, leftWidth, rightWidth) {
	const side = Math.max(leftWidth, rightWidth);
	return side > 0 ? Math.ceil(clockWidth + 2 * (side + 10) + 24) : 0;
}

// Bloom pillTarget{Y,Width,Height} and corner radii. `content` is the size
// of the shown, expanded notch.
function geometry(s, content) {
	const shown = s.expanded && s.visible && !s.hidden;
	return {
		y: !s.ready ? 250 : s.visible ? (s.hidden ? -100 : 0) : -150,
		width: !s.ready ? 34 : shown ? content.width : s.impacted ? 39.1 : 30.6,
		height: !s.ready ? 34 : shown ? content.height : s.impacted ? 28.9 : 44.2,
		edgeRadius: s.impacted ? 0 : 18,
		farRadius: 18,
		opacity: s.visible ? 1 : 0
	};
}

// Bloom isHidden: smart hides while overlapped, peek hides unless something
// shows it. Startup must respect smart overlap instead of flashing over an app.
function isHidden(mode, overlapped, interaction, eventPeek, startupAnimating) {
	if (mode === "smart")
		return overlapped && interaction === "none";
	if (startupAnimating)
		return false;
	if (mode === "peek")
		return interaction === "none" && !eventPeek;
	return false;
}

// The window a monitor's notch reacts to: the most recently focused, mapped,
// visible window on that monitor's active workspace (Bloom used the
// foreground window). `clients` and `monitor` are `hyprctl -j` objects.
function focusedWindow(clients, monitor) {
	let best = null;
	for (const c of clients) {
		if (!c.mapped || c.hidden || c.monitor !== monitor.id || !c.workspace || c.workspace.id !== monitor.activeWorkspace.id)
			continue;
		if (!best || c.focusHistoryID < best.focusHistoryID)
			best = c;
	}
	return best ? { x: best.at[0], y: best.at[1], width: best.size[0], height: best.size[1], fullscreen: best.fullscreen } : null;
}

// Whether the visible workspace has a window covering the resting notch.
function workspaceOverlaps(clients, monitor, rect) {
	return clients.some(c => c.mapped && !c.hidden && c.monitor === monitor.id && c.workspace
		&& (c.workspace.id === monitor.activeWorkspace.id || c.pinned === true)
		&& overlaps({ x: c.at[0], y: c.at[1], width: c.size[0], height: c.size[1], fullscreen: c.fullscreen }, rect));
}

// True when the monitor's active workspace shows a fullscreen window
// (Hyprland fullscreen state 2, or 3 = maximised and fullscreen). Maximised
// alone leaves the top layer visible, so it doesn't count.
function fullscreenOn(clients, monitor) {
	return clients.some(c => c.mapped && !c.hidden && c.monitor === monitor.id && c.workspace
		&& c.workspace.id === monitor.activeWorkspace.id && (c.fullscreen & 2) !== 0);
}

// The resting notch in global layout coordinates. Hyprland reports monitor
// width in physical pixels; the layout works in logical ones.
function notchRect(monitor, restWidth, uiScale) {
	const logicalWidth = monitor.width / monitor.scale;
	const w = restWidth * uiScale;
	const left = monitor.x + (logicalWidth - w) / 2;
	return { left: left, right: left + w, top: monitor.y + monitor.reserved[1], rowHeight: 36 * uiScale };
}

// Bloom services.rs: maximised or fullscreen always counts; otherwise the
// window must reach into the notch's row and overlap it horizontally, with a
// 4 px tolerance.
function overlaps(win, rect) {
	if (!win)
		return false;
	if (win.fullscreen > 0)
		return true;
	const triggerY = rect.top + rect.rowHeight;
	return win.x < rect.right - 4 && win.x + win.width > rect.left + 4 && win.y < triggerY - 4;
}

function _pad(n) {
	return n < 10 ? "0" + n : String(n);
}

// Bloom: toLocaleTimeString with 2-digit hour and minute ("01:05 PM", "13:05").
function clockText(date, use24h) {
	const h = date.getHours();
	const m = date.getMinutes();
	if (use24h)
		return _pad(h) + ":" + _pad(m);
	const h12 = h % 12 === 0 ? 12 : h % 12;
	return _pad(h12) + ":" + _pad(m) + " " + (h < 12 ? "AM" : "PM");
}
