// checkupdates results (pacman-contrib). Plain JS, shared with the tests.
// Exit 0 lists one "name old -> new" line per update; 2 means none; anything
// else failed (1: offline or a sync error; 15: ended by the watchdog). The
// service runs it through `sh -c`, which reports 127 when it isn't installed.
function parse(code, stdout) {
	if (code === 127)
		return { ok: false, missing: true, count: 0, packages: [] };
	if (code === 2)
		return { ok: true, missing: false, count: 0, packages: [] };
	if (code !== 0)
		return { ok: false, missing: false, count: 0, packages: [] };
	const packages = stdout.split("\n").map(l => l.trim()).filter(l => l !== "").map(l => l.split(" ")[0]);
	return { ok: true, missing: false, count: packages.length, packages: packages };
}

// The pulse fires when new updates appear, not every hour that some are pending.
function rose(prevCount, count) {
	return count > prevCount;
}
