// XDG locations for Bloom's files. Plain JS (shared with tests).

function _configHome(xdgConfigHome, home) {
	return xdgConfigHome ? xdgConfigHome : home + "/.config";
}

function _stateHome(xdgStateHome, home) {
	return xdgStateHome ? xdgStateHome : home + "/.local/state";
}

function settingsFile(xdgConfigHome, home) {
	return _configHome(xdgConfigHome, home) + "/bloom/settings.json";
}

// `name` becomes a file name, so it is limited to [a-z0-9-].
function stateFile(xdgStateHome, home, name) {
	if (!/^[a-z0-9-]+$/.test(name))
		throw new Error("invalid state name: " + name);
	return _stateHome(xdgStateHome, home) + "/bloom/" + name + ".json";
}
