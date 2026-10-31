// The workspace overview's rules: pages of eight workspaces in a 4 × 2 grid,
// windows scaled into their workspace's cell, search, keys and the move
// dispatch. Pure.
var COLUMNS = 4;
var ROWS = 2;
var PAGE = COLUMNS * ROWS;

function page(active) {
	const first = Math.floor((Math.max(1, active) - 1) / PAGE) * PAGE + 1;
	return Array.from({ length: PAGE }, (_, i) => first + i);
}

function windowRect(client, monitor, cellWidth, cellHeight) {
	const scale = monitor.scale || 1;
	const kx = cellWidth / (monitor.width / scale);
	const ky = cellHeight / (monitor.height / scale);
	return { x: (client.at[0] - monitor.x) * kx, y: (client.at[1] - monitor.y) * ky,
		width: client.size[0] * kx, height: client.size[1] * ky };
}

// Normal workspaces only (special ones are negative).
function byWorkspace(clients) {
	const out = {};
	for (const c of clients) {
		const id = c.workspace && c.workspace.id;
		if (id > 0) (out[id] = out[id] || []).push(c);
	}
	return out;
}

function matches(clients, term) {
	const t = String(term || "").toLowerCase();
	if (!t) return [];
	return clients.filter(c => (c.title || "").toLowerCase().includes(t) || (c.class || "").toLowerCase().includes(t));
}

// Arrow keys over the grid, wrapping.
function step(index, direction) {
	const row = Math.floor(index / COLUMNS);
	const col = index % COLUMNS;
	if (direction === "right") return row * COLUMNS + (col + 1) % COLUMNS;
	if (direction === "left") return row * COLUMNS + (col + COLUMNS - 1) % COLUMNS;
	return ((row + 1) % ROWS) * COLUMNS + col;
}

function moveArg(address, workspace) {
	if (!/^0x[0-9a-f]+$/.test(address || "") || !Number.isInteger(workspace)) return "";
	return "hl.dsp.window.move({ workspace = " + workspace + ", follow = false, window = \"address:" + address + "\" })";
}
