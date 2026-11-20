.pragma library

// The default task manager (owner: Mission Center unless changed). Entries are
// { id, name, categories, noDisplay } from DesktopEntries; a task manager is a
// visible app in the freedesktop Monitor category.
function _monitors(entries) {
	return entries.filter(e => !e.noDisplay && (e.categories || []).indexOf("Monitor") >= 0)
		.sort((a, b) => a.name.localeCompare(b.name));
}

// The app to open: the chosen one if installed, else the first installed
// task manager, else "".
function choose(preferred, entries) {
	if (preferred && entries.some(e => e.id === preferred))
		return preferred;
	const found = _monitors(entries);
	return found.length > 0 ? found[0].id : "";
}

// Settings' options: the task managers, and the current value if it isn't one.
function choices(entries, current) {
	const out = _monitors(entries).map(e => ({ value: e.id, label: e.name }));
	if (current && !out.some(o => o.value === current))
		out.push({ value: current, label: current });
	return out;
}
