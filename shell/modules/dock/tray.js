// Select SNI items for the dock (Bloom dockApps.ts selectDockTrayApps and
// mergeTrayApps). SNI items carry no Hyprland address; the shell learns each
// item's owning process from its D-Bus connection (scripts/tray-owners.py), and
// that process, not a display name, decides the app.

function normalizedId(id) {
	if (typeof id !== "string") return "";
	return id.trim().toLowerCase().replace(/\.desktop$/i, "");
}

function passive(status) { return status === "Passive" || status === 0; }

function _base(path) { return String(path || "").split("/").pop().toLowerCase(); }

// What matching needs from a desktop entry: the executable its command runs
// (past `env` and its assignments) and whether it opens a browser's web app.
function identity(id, startupClass, command) {
	const args = Array.from(command || []).map(String);
	let i = 0;
	if (_base(args[0]) === "env")
		for (i = 1; i < args.length && (args[i].indexOf("=") > 0 || args[i].startsWith("-")); i++) {}
	return { id: id, startupClass: startupClass || "", exec: i < args.length ? _base(args[i]) : "",
		webApp: args.some(a => /^--app(-id)?=/.test(a)) };
}

// The D-Bus owner of a Quickshell tray item: a pixmap icon names its service;
// otherwise the one owner with the same id, title and icon name.
function ownerOf(item, owners) {
	const icon = String(item.icon || "");
	const pixmap = "image://service.sni/";
	if (icon.startsWith(pixmap)) {
		const byService = (owners || []).find(o => icon.startsWith(pixmap + o.service + "/"));
		if (byService) return byService;
	}
	const named = icon.startsWith("image://icon/") ? icon.slice(13).split("?")[0] : "";
	const same = (owners || []).filter(o => o.id === item.id && (o.title || "") === (item.title || "")
		&& (!named || !o.iconName || o.iconName === named));
	return same.length === 1 ? same[0] : null;
}

// The app a tray owner belongs to: the app of the window its process (or its
// parent) shows, else the one desktop entry run by its executable. A process
// with windows of several apps is a browser hosting web apps: none of them.
function appFor(owner, windows, entries) {
	const ids = [];
	for (const w of windows || [])
		if (w.pid > 0 && (w.pid === owner.pid || w.pid === owner.ppid) && ids.indexOf(w.id) < 0) ids.push(w.id);
	if (ids.length > 0) return ids.length === 1 ? ids[0] : "";
	const name = _base(owner.exe);
	if (!name) return "";
	const matches = (entries || []).filter(e => !e.webApp
		&& (String(e.exec || "").toLowerCase() === name || normalizedId(e.id) === name || String(e.startupClass || "").toLowerCase() === name));
	return matches.length === 1 ? matches[0].id : "";
}

function _byId(item, desktopEntries) {
	const id = normalizedId(item.id);
	if (!id) return "";
	let matches = (desktopEntries || []).filter(e => normalizedId(e.id) === id);
	if (matches.length === 0)
		matches = (desktopEntries || []).filter(e => normalizedId(e.startupClass) === id);
	return matches.length === 1 ? matches[0].id : "";
}

// merged: tray items per present (running or pinned) app; background: apps
// with only a tray icon left; separate: tray icons of no known app. Without
// `context` (owners not known yet) every unmatched icon stays separate.
// With it, an icon is shown away from its app only once that app had a
// window (`observed`, keyed by executable, forgotten with the icon). `known`
// keeps, per owning process, the app a window showed an icon belonged to, for when that window
// closes and nothing else names it (Claude: process `claude`, entry
// `claude-desktop`).
function selectTray(items, desktopEntries, running, pinned, context) {
	const present = (running || []).concat(pinned || []);
	const merged = Object.create(null);
	const separate = [];
	const background = [];
	const observed = [];
	const known = {};
	const ctx = context || null;
	for (const item of items || []) {
		if (!item || passive(item.status)) continue;
		const owner = ctx ? ownerOf(item, ctx.owners) : null;
		let app = owner ? appFor(owner, ctx.windows, desktopEntries) : "";
		// By process: apps sharing one runtime (electron) share an executable.
		const proc = owner ? owner.pid + ":" + owner.exe : "";
		if (!app && owner) app = (ctx.known || {})[proc] || "";
		const byOwner = !!app;
		if (byOwner) known[proc] = app;
		if (!app) app = _byId(item, desktopEntries);
		const category = item.category;
		const appCategory = category === "ApplicationStatus" || category === "Communications" || category === 2 || category === 3;
		const isApp = !!app && (byOwner || appCategory);
		const key = owner && owner.exe ? owner.exe : "id:" + normalizedId(item.id);
		const seen = !!ctx && (ctx.observed.indexOf(key) >= 0
			|| (!!owner && (ctx.windows || []).some(w => w.pid > 0 && (w.pid === owner.pid || w.pid === owner.ppid)))
			|| (isApp && (running || []).indexOf(app) >= 0));
		if (seen && observed.indexOf(key) < 0) observed.push(key);
		if (isApp && present.indexOf(app) >= 0) {
			if (!merged[app]) merged[app] = [];
			merged[app].push(item);
		} else if (ctx && isApp) {
			if (!seen) continue;
			const b = background.find(x => x.id === app);
			if (b) b.trays.push(item);
			else background.push({ id: app, trays: [item] });
		} else if (!ctx || seen) separate.push(item);
	}
	return { merged: merged, separate: separate, background: background, observed: observed, known: known };
}
