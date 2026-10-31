// The settings app's pure rules: status widget arrangement, and the lists the
// Dock tab keeps as JSON strings.
var WIDGETS = [
	{ id: "weather", label: "Weather", icon: "cloud-sun", color: "#60a5fa" },
	{ id: "battery", label: "Battery", icon: "battery-full", color: "#4ade80" },
	{ id: "cpu", label: "CPU", icon: "cpu", color: "#f97316" },
	{ id: "ram", label: "RAM", icon: "memory-stick", color: "#a78bfa" },
	{ id: "disk", label: "Disk", icon: "hard-drive", color: "#38bdf8" },
	{ id: "net", label: "Net", icon: "arrow-up-down", color: "#2dd4bf" }
];

function widget(id) {
	return WIDGETS.find(w => w.id === id);
}

function pool(config) {
	return WIDGETS.filter(w => config.left.indexOf(w.id) < 0 && config.right.indexOf(w.id) < 0).map(w => w.id);
}

function remove(config, id) {
	return { left: config.left.filter(x => x !== id), right: config.right.filter(x => x !== id) };
}

function swapSide(config, id) {
	const next = remove(config, id);
	(config.left.indexOf(id) >= 0 ? next.right : next.left).push(id);
	return next;
}

function moveInSide(config, id, step) {
	const side = config.left.indexOf(id) >= 0 ? "left" : "right";
	const list = config[side].slice();
	const at = list.indexOf(id), to = at + step;
	if (at < 0 || to < 0 || to >= list.length) return config;
	list.splice(at, 1);
	list.splice(to, 0, id);
	const next = { left: config.left, right: config.right };
	next[side] = list;
	return next;
}

// A drop: at the end of a side unless an index says where.
function place(config, id, side, index) {
	const next = remove(config, id);
	const at = index === undefined ? next[side].length : Math.min(index, next[side].length);
	next[side].splice(at, 0, id);
	return next;
}

function parseList(json) {
	try {
		const list = JSON.parse(json);
		return Array.isArray(list) ? list : [];
	} catch (e) {
		return [];
	}
}

function toggled(list, item) {
	return list.indexOf(item) >= 0 ? list.filter(x => x !== item) : list.concat([item]);
}

// The special folders setting is comma-separated.
function folderList(text) {
	return String(text || "").split(",").filter(x => x !== "");
}

function enabledPanels(calendar, command, devices) {
	return [calendar, command, devices].filter(Boolean).length;
}
