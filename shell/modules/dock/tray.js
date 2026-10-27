// Select SNI items for the dock using desktop identity only. SNI has no
// trustworthy Hyprland address or PID for a tray item.

function normalizedId(id) {
	if (typeof id !== "string") return "";
	return id.trim().toLowerCase().replace(/\.desktop$/i, "");
}

function passive(status) { return status === "Passive" || status === 0; }

function selectTray(items, desktopEntries, running, pinned) {
	const present = (running || []).concat(pinned || []);
	const merged = Object.create(null);
	const separate = [];
	for (const item of items || []) {
		if (!item || passive(item.status)) continue;
		const id = normalizedId(item.id);
		let matches = (desktopEntries || []).filter(e => normalizedId(e.id) === id && id);
		if (matches.length === 0)
			matches = (desktopEntries || []).filter(e => normalizedId(e.startupClass) === id && id);
		const target = matches.length === 1 ? matches[0].id : "";
		const category = item.category;
		const appCategory = category === "ApplicationStatus" || category === "Communications" || category === 2 || category === 3;
		if (appCategory && target && present.indexOf(target) >= 0) {
			if (!merged[target]) merged[target] = [];
			merged[target].push(item);
		} else separate.push(item);
	}
	return { merged: merged, separate: separate };
}
