.import "../notch/notch.js" as Notch

// Dock rules ported from Bloom (Dock.tsx, dockGeometry.ts, services.rs @
// b5fb962), with Hyprland window classes and desktop entries in place of
// Windows paths. Plain JS, shared with the unit tests.

var dividerKey = "|divider|";
var ICON = 36;
var GAP = 12;
var DIVIDER_SPAN = 5; // 1 px line + 2 px margin each side

// The desktop entry a window class resolves to, else the class itself.
function identity(cls, entryId) {
	return entryId ? entryId : "class:" + cls;
}

// Windows grouped by app in the order Hyprland lists them. Unmapped, hidden
// and classless windows (popups, helpers) never become dock items.
function groupWindows(clients, idOf) {
	const groups = [];
	const index = {};
	for (const c of clients) {
		if (!c.mapped || c.hidden || !c.class)
			continue;
		const id = idOf(c.class);
		if (index[id] === undefined) {
			index[id] = groups.length;
			groups.push({ id: id, cls: c.class, windows: [] });
		}
		groups[index[id]].windows.push({ address: c.address, focus: c.focusHistoryID, title: c.title });
	}
	return groups;
}

// Bloom's activeOrder: a running app keeps its place; new ones join the end.
function nextOrder(prev, runningIds) {
	const kept = prev.filter(id => runningIds.indexOf(id) >= 0);
	return kept.concat(runningIds.filter(id => kept.indexOf(id) < 0));
}

function buildItems(pinned, groups, order, info) {
	const byId = {};
	for (const g of groups)
		byId[g.id] = g;
	const item = id => {
		const i = info(id);
		return { id: id, name: i.name, icon: i.icon, windows: byId[id] ? byId[id].windows : [] };
	};
	return {
		pinned: pinned.map(item),
		unpinned: order.filter(id => byId[id] && pinned.indexOf(id) < 0).map(item)
	};
}

// What the row shows: pinned apps, Bloom's divider when both groups have
// something, then the other running apps.
function slots(items, separator) {
	const app = i => ({ key: i.id, kind: "app", name: i.name, icon: i.icon, windows: i.windows.length });
	const out = items.pinned.map(app);
	if (separator && items.pinned.length > 0 && items.unpinned.length > 0)
		out.push({ key: dividerKey, kind: "divider", name: "", icon: "", windows: 0 });
	return out.concat(items.unpinned.map(app));
}

// framer AnimatePresence: a row that left `next` stays where it was, marked
// leaving, until its exit ends (`expired`); one that comes back reuses it.
function reconcile(prev, nextKeys, expired) {
	const out = nextKeys.map(k => ({ key: k, leaving: false }));
	let anchor = null;
	for (const p of prev) {
		if (nextKeys.indexOf(p.key) >= 0) {
			anchor = p.key;
			continue;
		}
		if (expired.indexOf(p.key) >= 0)
			continue;
		const at = anchor === null ? 0 : out.findIndex(o => o.key === anchor) + 1;
		out.splice(at, 0, { key: p.key, leaving: true });
		anchor = p.key;
	}
	return out;
}

// Left edges of each row in the flex row (gap 12), and its total width.
function layout(keys) {
	const xs = [];
	let x = 0;
	keys.forEach((k, i) => {
		if (i > 0)
			x += GAP;
		xs.push(x);
		x += k === dividerKey ? DIVIDER_SPAN : ICON;
	});
	return { xs: xs, width: x };
}

// Bloom handleAppClick on Hyprland. Cycling uses a stable order: focus
// history would only bounce between the two latest windows.
function clickAction(item, activeAddress) {
	const ws = item.windows;
	if (ws.length === 0)
		return { kind: "launch" };
	const stable = ws.slice().sort((a, b) => a.address < b.address ? -1 : a.address > b.address ? 1 : 0);
	const i = stable.findIndex(w => w.address === activeAddress);
	if (i < 0) {
		const recent = ws.slice().sort((a, b) => a.focus - b.focus);
		return { kind: "focus", address: recent[0].address };
	}
	if (stable.length === 1)
		return { kind: "none" };
	return { kind: "focus", address: stable[(i + 1) % stable.length].address };
}

function dotCount(windows) {
	return Math.min(windows, 3);
}

function isHidden(mode, overlapped, interaction, startupAnimating) {
	if (startupAnimating)
		return false;
	if (mode === "smart")
		return overlapped && interaction === "none";
	if (mode === "peek")
		return interaction === "none";
	return false;
}

// Bloom's motion.div.dock targets (Dock.tsx).
function geometry(s) {
	const shown = s.expanded && !s.hidden && s.visible;
	const attached = (s.impacted || s.expanded) && !s.hidden && s.visible;
	return {
		y: !s.ready ? -800 : s.visible ? (s.hidden ? 100 : 0) : 150,
		width: shown ? (s.adaptive ? s.adaptiveWidth : s.contentWidth) : 34,
		height: shown ? 52 : 34,
		edgeRadius: attached ? 0 : 17,
		farRadius: attached ? 18 : 17,
		opacity: s.visible ? 1 : 0
	};
}

// Nearly full width: 24 px margin per side at the visual (scaled) size.
function adaptiveWidth(viewport, scale) {
	return (viewport - 48 * scale) / scale;
}

// The resting dock in global layout coordinates (logical pixels).
function dockRect(monitor, naturalWidth, uiScale) {
	const logicalWidth = monitor.width / monitor.scale;
	const w = naturalWidth * uiScale;
	const left = monitor.x + (logicalWidth - w) / 2;
	return { left: left, right: left + w, bottom: monitor.y + monitor.height / monitor.scale - monitor.reserved[3] };
}

// Bloom: a maximised or fullscreen window always counts; otherwise the window
// must overlap the dock's span and reach into its 56 px strip (4 px slack).
function overlaps(win, rect, uiScale) {
	if (!win)
		return false;
	if (win.fullscreen > 0)
		return true;
	const triggerY = rect.bottom - 56 * uiScale;
	return win.x < rect.right - 4 && win.x + win.width > rect.left + 4 && win.y + win.height > triggerY + 4;
}

// Hyprland fullscreen state 1 = maximised (2 = fullscreen, 3 = both).
function maximized(win) {
	return !!win && win.fullscreen === 1;
}

function focusedWindow(clients, monitor) {
	return Notch.focusedWindow(clients, monitor);
}

// The Lua dispatch that focuses a window; only Hyprland's hex addresses pass.
function focusArg(address) {
	if (!/^0x[0-9a-f]+$/.test(address || ""))
		return "";
	return 'hl.dsp.focus({ window = "address:' + address + '" })';
}
