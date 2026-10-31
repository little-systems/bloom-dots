// The system pages' pure rules: reading what tools print, and writing the
// Hyprland settings file. Nothing here runs a command.
function modes(monitor) {
	return (monitor.availableModes || []).map(mode => ({ value: mode, label: mode.replace("Hz", " Hz").replace("@", " · ") }));
}

function currentMode(monitor) {
	const hz = Number(monitor.refreshRate).toFixed(2);
	return monitor.width + "x" + monitor.height + "@" + hz + "Hz";
}

function monitorLine(monitor, mode, scale) {
	const m = mode.replace(/Hz$/, "");
	return 'hl.monitor({ output = "' + monitor.name + '", mode = "' + m + '", position = "' + monitor.x + "x" + monitor.y + '", scale = ' + scale + " })";
}

// `df -B1 --output=target,size,used`: real disks only, biggest first.
function parseDisks(text) {
	return text.split("\n").slice(1).map(line => line.trim().split(/\s+/)).filter(f => f.length === 3 && f[0].startsWith("/"))
		.filter(f => !/^\/(boot|run|sys|proc|dev|var|tmp|\.)/.test(f[0]) && Number(f[1]) > 0)
		.map(f => ({ path: f[0], size: Number(f[1]), used: Number(f[2]) }))
		.sort((a, b) => b.size - a.size);
}

function gigabytes(bytes) {
	return (bytes / 1e9).toFixed(bytes < 1e10 ? 1 : 0) + " GB";
}

// `updates`: { section: { key: value } } of Hyprland options, as a Lua file and
// as the one line that applies them to the running session.
function _lua(value) {
	if (typeof value === "object" && value !== null) return "{ " + Object.keys(value).map(k => k + " = " + _lua(value[k])).join(", ") + " }";
	return String(value);
}

function hyprConfig(overrides) {
	return "hl.config(" + _lua(overrides) + ")";
}

function hyprFile(overrides, monitors) {
	const lines = ["-- Written by Bloom Settings. Delete this file to undo everything in it."];
	if (Object.keys(overrides).length) lines.push(hyprConfig(overrides));
	return lines.concat(monitors).join("\n") + "\n";
}

function withOption(overrides, path, value) {
	const next = JSON.parse(JSON.stringify(overrides));
	const keys = path.split(".");
	let node = next;
	keys.slice(0, -1).forEach(key => { node = node[key] = node[key] || {}; });
	node[keys[keys.length - 1]] = value;
	return next;
}

function option(overrides, path, fallback) {
	let node = overrides;
	for (const key of path.split(".")) {
		if (node === undefined || node === null) return fallback;
		node = node[key];
	}
	return node === undefined ? fallback : node;
}

var DEFAULTS = [
	{ id: "browser", label: "Web browser", mime: "x-scheme-handler/https", icon: "globe" },
	{ id: "files", label: "File manager", mime: "inode/directory", icon: "folder" },
	{ id: "text", label: "Text editor", mime: "text/plain", icon: "file-text" },
	{ id: "image", label: "Image viewer", mime: "image/png", icon: "file-image" },
	{ id: "video", label: "Video player", mime: "video/mp4", icon: "file-video-camera" },
	{ id: "music", label: "Music player", mime: "audio/mpeg", icon: "file-music" }
];

function appName(desktopId) {
	return String(desktopId || "").replace(/\.desktop$/, "").split(".").pop() || "Not set";
}
