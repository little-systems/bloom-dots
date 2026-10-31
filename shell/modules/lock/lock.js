.pragma library

function failureText(outcome) {
	if (outcome === "maxtries") return "Too many tries. Wait a moment, then try again";
	if (outcome === "error") return "Couldn't check the password";
	return "Incorrect password";
}

// `hyprctl devices -j`: the main keyboard's state, or the only keyboard's.
function keyboard(devicesJson) {
	try {
		const keyboards = JSON.parse(devicesJson).keyboards || [];
		const main = keyboards.find(k => k.main) || keyboards[0];
		if (!main) return { capsLock: false, layout: "" };
		return { capsLock: main.capsLock === true, layout: String(main.active_keymap || "").slice(0, 2).toUpperCase() };
	} catch (e) {
		return { capsLock: false, layout: "" };
	}
}

// ii's own config, only until Phase 7 gives Bloom a wallpaper of its own.
function wallpaperFrom(iiConfigJson) {
	try {
		return JSON.parse(iiConfigJson).background.wallpaperPath || "";
	} catch (e) {
		return "";
	}
}

function hands(time) {
	const seconds = time.getSeconds();
	const minutes = time.getMinutes() + seconds / 60;
	return { hour: (time.getHours() % 12 + minutes / 60) * 30, minute: minutes * 6, second: seconds * 6 };
}

// The clock's face: a circle with `sides` soft lobes, as canvas points.
function cookie(size, sides, depth) {
	const points = [];
	const radius = size / 2 / (1 + depth);
	for (let i = 0; i < 360; i++) {
		const angle = i * Math.PI / 180;
		const r = radius * (1 + depth * Math.cos(sides * angle));
		points.push({ x: size / 2 + r * Math.cos(angle), y: size / 2 + r * Math.sin(angle) });
	}
	return points;
}

// While locked each screen sits on an empty workspace, so that going back slides
// the windows in. Names come from the compositor, but this builds a shell line.
var EMPTY_FROM = 2147483647;

function _focus(monitor, workspace) {
	return "hyprctl dispatch 'hl.dsp.focus({monitor=\"" + monitor + "\"})'; hyprctl dispatch 'hl.dsp.focus({workspace=" + workspace + "})';";
}

function saveWorkspaces(monitors) {
	const saved = {};
	(monitors || []).forEach(m => {
		const id = m.activeWorkspace?.id;
		if (/^[\w.-]+$/.test(m.name || "") && Number.isInteger(id) && id > 0) saved[m.name] = id;
	});
	return saved;
}

function leaveScript(saved) {
	return Object.keys(saved).map(name => _focus(name, EMPTY_FROM - saved[name])).join(" ");
}

function returnScript(saved) {
	return Object.keys(saved).map(name => _focus(name, saved[name])).join(" ");
}

function parseMarker(text) {
	try {
		return saveWorkspaces(Object.entries(JSON.parse(text)).map(([name, id]) => ({ name: name, activeWorkspace: { id: id } })));
	} catch (e) {
		return {};
	}
}
