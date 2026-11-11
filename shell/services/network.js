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

// Bloom's security labels (wifi.rs) from nmcli's SECURITY field: open, wep,
// wpa, wpa2, wpa3, owe or enterprise; a network offering several takes the
// strongest, and any 802.1X sign-in makes it enterprise.
function security(field) {
	const f = (field || "").trim();
	if (!f || f === "--") return "open";
	if (/802\.1X/.test(f)) return "enterprise";
	if (/WPA3|SAE/.test(f)) return "wpa3";
	if (/WPA2/.test(f)) return "wpa2";
	if (/WPA/.test(f)) return "wpa";
	if (/OWE/.test(f)) return "owe";
	if (/WEP/.test(f)) return "wep";
	return "other";
}

// The names of NetworkManager's Wi-Fi profiles (nmcli -t -f NAME,TYPE
// connection show): Bloom's saved networks.
function savedNames(text) {
	const names = [];
	for (const line of (text || "").split("\n")) {
		const f = fields(line);
		if (f.length >= 2 && f[1] === "802-11-wireless" && f[0]) names.push(f[0]);
	}
	return names;
}

// Visible networks, one per SSID, in Bloom's order: connected, then saved,
// then strongest, then by name.
function wifiList(text, saved) {
	const seen = new Map();
	for (const line of (text || "").split("\n")) {
		if (!line.trim()) continue;
		const f = fields(line);
		if (f.length < 4 || !f[1]) continue;
		const next = { ssid: f[1], signal: Math.max(0, Math.min(100, Number(f[2]) || 0)),
			security: security(f[3]), connected: f[0] === "*", saved: (saved || []).includes(f[1]) };
		const old = seen.get(next.ssid);
		if (!old || next.connected || (!old.connected && next.signal > old.signal)) seen.set(next.ssid, next);
	}
	return Array.from(seen.values()).sort((a, b) => Number(b.connected) - Number(a.connected)
		|| Number(b.saved) - Number(a.saved) || b.signal - a.signal
		|| a.ssid.toLowerCase().localeCompare(b.ssid.toLowerCase()));
}

// Bloom's error codes for a failed nmcli connect.
function connectError(output, code, withPassword) {
	const o = output || "";
	if (code === 124) return "timeout";
	if (/Secrets were required|802-11-wireless-security\.psk: property is invalid|wrong password/i.test(o))
		return withPassword ? "wrong-password" : "password-required";
	if (/No network with SSID/i.test(o)) return "not-found";
	if (/No Wi-?Fi device/i.test(o)) return "no-adapter";
	return "failed";
}

// Passwords travel through Process.write to nmcli --ask, never through argv.
function connectCommand(ssid, password) {
	return password
		? ["timeout", "-k", "1s", "20s", "nmcli", "--ask", "-w", "18", "device", "wifi", "connect", ssid]
		: ["timeout", "-k", "1s", "15s", "nmcli", "-w", "12", "device", "wifi", "connect", ssid];
}

// Why an nmcli query failed: NetworkManager stopped or nmcli absent, versus a
// transient failure. "No Wi-Fi device" is not a failure.
function failure(code, stderr) {
	const text = String(stderr || "");
	if (code === 127)
		return { state: "missing", reason: "nmcli is not installed", message: "NetworkManager tools aren't installed" };
	if (code === 8 || /NetworkManager is not running|could not be found|ServiceUnknown/i.test(text))
		return { state: "missing", reason: "NetworkManager is not running", message: "NetworkManager isn't running" };
	if (code === 124)
		return { state: "degraded", reason: "query timed out", message: "NetworkManager isn't responding" };
	return { state: "degraded", reason: "query failed", message: "NetworkManager unavailable" };
}
