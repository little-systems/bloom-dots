// nmcli's terse format escapes colons and backslashes inside fields.
function fields(line) {
	const out = [];
	let part = "";
	let escaped = false;
	for (const c of line) {
		if (escaped) { part += c; escaped = false; }
		else if (c === "\\") escaped = true;
		else if (c === ":") { out.push(part); part = ""; }
		else part += c;
	}
	out.push(part);
	return out;
}

function status(text) {
	const first = fields((text || "").trim().split("\n")[0] || "");
	return { wifiEnabled: first[0] === "enabled", connected: first[1] === "connected" };
}

function wifiList(text) {
	const seen = new Map();
	for (const line of (text || "").split("\n")) {
		if (!line.trim()) continue;
		const f = fields(line);
		if (f.length < 4 || !f[1]) continue;
		const next = { ssid: f[1], signal: Math.max(0, Math.min(100, Number(f[2]) || 0)),
			secured: f[3] !== "--" && f[3] !== "", active: f[0] === "*" };
		const old = seen.get(next.ssid);
		if (!old || next.active || (!old.active && next.signal > old.signal)) seen.set(next.ssid, next);
	}
	return Array.from(seen.values()).sort((a, b) => Number(b.active) - Number(a.active) || b.signal - a.signal || a.ssid.localeCompare(b.ssid));
}

// Passwords travel through Process.write to nmcli --ask, never through argv.
function connectCommand(ssid, password) {
	return password
		? ["timeout", "-k", "1s", "20s", "nmcli", "--ask", "-w", "18", "device", "wifi", "connect", ssid]
		: ["timeout", "-k", "1s", "15s", "nmcli", "-w", "12", "device", "wifi", "connect", ssid];
}
