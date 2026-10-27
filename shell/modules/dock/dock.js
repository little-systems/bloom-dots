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

var workspacesKey = "|workspaces|";

// What the row shows: the workspace segment (D7) and its divider, pinned
// apps, Bloom's divider when both app groups have something, then the other
// running apps.
function slots(items, separator, segmentCells, extras, extrasPosition, trayOnly) {
	const app = pinned => i => ({ key: i.id, kind: "app", pinned: pinned, name: i.name, icon: i.icon,
		windows: i.windows.length, backgroundDot: !!i.hasTray && i.windows.length === 0 });
	const extra = e => ({ key: "extra:" + e.key, kind: "extra", extraKind: e.kind, count: e.count || 0,
		pinned: false, name: e.name, icon: e.icon, windows: 0 });
	const tray = t => ({ key: "tray:" + t.key, kind: "tray", pinned: false, name: t.title || t.id || "Tray app",
		icon: t.icon || "", windows: 0, backgroundDot: true });
	const out = [];
	const cells = segmentCells || [];
	const shownExtras = extrasPosition === "left" || extrasPosition === "right" ? (extras || []) : [];
	const appsCount = items.pinned.length + items.unpinned.length;
	if (cells.length > 0) {
		out.push({ key: workspacesKey, kind: "workspaces", pinned: false, name: "", icon: "", windows: cells.length });
		if (items.pinned.length + items.unpinned.length > 0)
			out.push({ key: dividerKey + "ws", kind: "divider", pinned: false, name: "", icon: "", windows: 0 });
	}
	if (extrasPosition === "left" && shownExtras.length > 0) {
		out.push.apply(out, shownExtras.map(extra));
		if (appsCount > 0) out.push({ key: dividerKey + "extras", kind: "divider", pinned: false, name: "", icon: "", windows: 0 });
	}
	out.push.apply(out, items.pinned.map(app(true)));
	if (separator && items.pinned.length > 0 && items.unpinned.length > 0)
		out.push({ key: dividerKey, kind: "divider", pinned: false, name: "", icon: "", windows: 0 });
	out.push.apply(out, items.unpinned.map(app(false)));
	if (trayOnly && trayOnly.length > 0) {
		if (appsCount > 0) out.push({ key: dividerKey + "tray", kind: "divider", pinned: false, name: "", icon: "", windows: 0 });
		out.push.apply(out, trayOnly.map(tray));
	}
	if (extrasPosition === "right" && shownExtras.length > 0) {
		if (appsCount > 0) out.push({ key: dividerKey + "extras", kind: "divider", pinned: false, name: "", icon: "", windows: 0 });
		out.push.apply(out, shownExtras.map(extra));
	}
	return out;
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

function _width(key, cells) {
	if (key === workspacesKey)
		return segmentWidth(cells);
	return key.startsWith(dividerKey) ? DIVIDER_SPAN : ICON;
}

// Left edges of each row in the flex row (gap 12), and its total width.
function layout(keys, cells) {
	const xs = [];
	let x = 0;
	keys.forEach((k, i) => {
		if (i > 0)
			x += GAP;
		xs.push(x);
		x += _width(k, cells || 0);
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
		// Focus history 0 is the latest; -1 means never focused, so last.
		const rank = w => w.focus < 0 ? Infinity : w.focus;
		const recent = ws.slice().sort((a, b) => rank(a) - rank(b));
		return { kind: "focus", address: recent[0].address };
	}
	if (stable.length === 1)
		return { kind: "none" };
	return { kind: "focus", address: stable[(i + 1) % stable.length].address };
}

// The window that really has focus: history 0, shown on the focused
// monitor's workspace (or its open special workspace). Hyprland keeps the
// last window at history 0 after a switch to an empty workspace.
function activeAddress(clients, monitors) {
	const m = monitors.find(x => x.focused);
	if (!m)
		return "";
	const shown = id => id === m.activeWorkspace.id || (m.specialWorkspace && m.specialWorkspace.id !== 0 && id === m.specialWorkspace.id);
	const c = clients.find(x => x.focusHistoryID === 0 && x.mapped && !x.hidden && x.workspace && shown(x.workspace.id));
	return c ? c.address : "";
}

// Pins from dock.json: strings only, once each, whatever the file holds.
function pinsOf(value) {
	const list = value && Array.isArray(value.pinned) ? value.pinned : [];
	return list.filter((p, i) => typeof p === "string" && p !== "" && list.indexOf(p) === i);
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

// Context menus (Bloom Dock.tsx), mapped to Linux: desktop actions stand in
// for the taskbar's tray/jump list, and there is no Start menu (D7).
function _item(key, label, danger) {
	return { kind: "item", key: key, label: label, danger: !!danger };
}
var _divider = { kind: "divider" };

function menuFor(t) {
	if (t.kind === "workspaces")
		return [_item("hide-workspaces", "Hide Workspaces")];
	if (t.kind === "drive") {
		const entries = [_item("open", "Open Drive")];
		if (t.removable) entries.push(_item("eject", "Eject Drive"));
		entries.push(_divider, _item("hide", "Hide from Dock"));
		return entries;
	}
	if (t.kind === "trash") return [_item("open", "Open Trash"), _divider, _item("empty-trash", "Empty Trash…", true)];
	if (t.kind === "folder" || t.kind === "custom")
		return [_item("open", "Open Folder"), _divider, _item("remove", "Remove from Dock")];
	if (t.kind === "tray") return [_item("tray:" + t.trayKey, t.hasMenu ? "App tray menu" : "Activate")];
	const bloom = { kind: "submenu", key: "bloom", label: "Bloom Options", children: [_item("restart", "Restart Bloom"), _divider, _item("quit", "Quit Bloom", true)] };
	const addApp = _item("add-app", "Add App to Dock...");
	if (t.kind === "background")
		return [addApp, bloom];
	const out = [];
	if (t.pinned)
		out.push(_item("unpin", "Unpin from Dock"));
	else if (t.pinnable)
		out.push(_item("pin", "Pin to Dock"));
	if (t.pinned) {
		out.push(_divider, _item("change-icon", "Change Icon..."));
		if (t.hasCustomIcon)
			out.push(_item("reset-icon", "Reset Icon"));
	}
	if (out.length > 0)
		out.push(_divider);
	out.push(addApp, bloom);
	const actions = (t.actions || []).map((name, i) => _item("action:" + i, name));
	if (actions.length > 0 || t.running) {
		out.push(_divider);
		out.push.apply(out, actions);
		if (t.running)
			out.push(_item("new-window", "Open New Window"));
	}
	if (t.running)
		out.push(_item("close", t.windows > 1 ? "Close all windows" : "Close window", true));
	if (t.trays && t.trays.length > 0) {
		out.push(_divider);
		for (const tray of t.trays)
			out.push(_item("tray:" + tray.key, (tray.hasMenu ? "App tray menu" : "Activate tray app")
				+ (t.trays.length > 1 ? ": " + (tray.title || tray.key) : "")));
	}
	return out;
}

// Bloom: just above the pointer, kept 8 px inside the dock window.
function menuPosition(x, y, w, h, viewW) {
	const m = 8;
	return { left: Math.max(m, Math.min(x, viewW - w - m)), top: Math.max(m, y - h - m) };
}

// framer Reorder: where the dragged item goes among the others, by the
// neighbour centres it has passed.
function reorderIndex(centers, draggedCenter) {
	let i = 0;
	while (i < centers.length && draggedCenter > centers[i])
		i++;
	return i;
}

function moveKey(keys, key, index) {
	const rest = keys.filter(k => k !== key);
	rest.splice(index, 0, key);
	return rest;
}

// Bloom AddAppPopup: browse = running (unpinned) then all apps (60, not
// pinned or running); search = starts-with then contains, by name, 50 max.
function addAppSections(all, running, pinned, query) {
	const byName = (x, y) => x.name.localeCompare(y.name);
	const s = query.trim().toLowerCase();
	if (!s) {
		const suggestions = running.filter(r => pinned.indexOf(r.id) < 0);
		const ids = suggestions.map(r => r.id);
		const rest = all.filter(x => pinned.indexOf(x.id) < 0 && ids.indexOf(x.id) < 0).sort(byName).slice(0, 60);
		const out = [];
		if (suggestions.length > 0)
			out.push({ title: "Running", items: suggestions });
		if (rest.length > 0)
			out.push({ title: "All apps", items: rest });
		return out;
	}
	const starts = [];
	const contains = [];
	for (const x of all) {
		const n = x.name.toLowerCase();
		if (n.startsWith(s))
			starts.push(x);
		else if (n.indexOf(s) >= 0)
			contains.push(x);
	}
	return [{ title: null, items: starts.sort(byName).concat(contains.sort(byName)).slice(0, 50) }];
}

// This monitor's active workspace for the segment, from Hyprland's workspaces as
// plain { id, name, monitor }. Named workspaces have negative ids (from
// -1337 down); special (scratchpad) ones are not places you switch to.
function workspaceState(active, all, monitor) {
	if (!active || active.name.startsWith("special:"))
		return null;
	const ids = all.filter(w => w.monitor === monitor && !w.name.startsWith("special:")).map(w => w.id);
	if (ids.indexOf(active.id) < 0)
		ids.push(active.id);
	return { id: active.id, name: active.name, ids: ids.sort((a, b) => a - b) };
}

// The workspace segment (D7): this monitor's workspaces, no scratchpads;
// numbered ones in order, then named ones (ids -1337, -1338, …) as created.
function workspaceCells(list, activeId) {
	const rank = w => w.id > 0 ? w.id : 1e9 - w.id;
	return list
		.filter(w => !w.name.startsWith("special:"))
		.slice()
		.sort((x, y) => rank(x) - rank(y))
		.map(w => {
			const named = w.name && w.name !== String(w.id);
			return { id: w.id, label: named ? w.name.slice(0, 1).toUpperCase() : String(w.id), tip: named ? w.name : "Workspace " + w.id, active: w.id === activeId };
		});
}

function segmentWidth(n) {
	return 2 * 6 + n * 24 + Math.max(0, n - 1) * 2;
}

// Custom icons from dock.json: string paths only.
function iconsOf(value) {
	const icons = value && value.icons && typeof value.icons === "object" ? value.icons : {};
	const out = {};
	for (const id in icons)
		if (typeof icons[id] === "string" && icons[id] !== "")
			out[id] = icons[id];
	return out;
}

var ICON_TYPES = ["png", "ico", "jpg", "jpeg", "svg", "bmp"];

// The copy's name in dock-icons/: the app id (made path-safe) plus the
// source's extension; "" for anything but Bloom's image types.
// `tag` makes each copy's name (and so its URL) unique, so a new icon is
// never served from Qt's image cache under the old one's name.
function iconFile(id, source, tag) {
	const m = /\.([A-Za-z0-9]+)$/.exec(source);
	const ext = m ? m[1].toLowerCase() : "";
	if (ICON_TYPES.indexOf(ext) < 0)
		return "";
	return id.replace(/[^A-Za-z0-9_.-]/g, "_").replace(/\.\./g, "__") + (tag ? "-" + tag : "") + "." + ext;
}

// Whether `path` is one of Bloom's own copies (directly in dock-icons/):
// dock.json can be hand-edited, and nothing else may ever be deleted.
function ownsIconPath(dir, path) {
	if (typeof path !== "string" || !path.startsWith(dir + "/"))
		return false;
	const name = path.slice(dir.length + 1);
	return name !== "" && name.indexOf("/") < 0 && name !== "." && name !== "..";
}

// Prints the chosen file. Exit 1 = cancelled, 127 = no picker installed.
// BLOOM_PICKER (tests) replaces the search with a stub.
var pickerScript = 'f="Images (*.png *.svg *.jpg *.jpeg *.ico *.bmp)"; '
	+ 'if [ -n "$BLOOM_PICKER" ]; then exec "$BLOOM_PICKER"; fi; '
	+ 'if command -v kdialog >/dev/null 2>&1; then exec kdialog --title "Choose an icon" --getopenfilename "$HOME" "$f"; fi; '
	+ 'for z in zenity qarma; do if command -v $z >/dev/null 2>&1; then exec $z --file-selection --title="Choose an icon" --file-filter="Images | *.png *.svg *.jpg *.jpeg *.ico *.bmp"; fi; done; '
	+ 'exit 127';
