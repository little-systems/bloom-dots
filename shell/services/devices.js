.import "../modules/notch/device-art.js" as Art
.import "bluetooth.js" as Bluetooth

function audioDevices(nodes) {
	return (nodes || []).filter(n => n && !n.isStream && n.properties && /^Audio\/(Sink|Source)$/.test(n.properties["media.class"] || ""))
		.map(n => ({ id: n.id, name: n.description || n.nickname || n.name || "Audio device", kind: n.properties["media.class"] === "Audio/Source" ? "input" : "output" }));
}

function privacy(nodes) {
	const streams = (nodes || []).filter(n => n && n.isStream && n.properties);
	return {
		microphone: streams.some(n => n.properties["media.class"] === "Stream/Input/Audio" || n.properties["media.class"] === "Audio/Source"),
		screen: streams.some(n => {
			const props = n.properties;
			return /Video\/(Source|Capture)|Stream\/(Input|Output)\/Video/.test(props["media.class"] || "")
				&& (/portal|screencast|screen/i.test([props["node.name"], props["application.name"], props["media.name"]].join(" ")));
		})
	};
}

function udevEvent(lines) {
	const props = {};
	for (const line of lines || []) {
		const at = line.indexOf("=");
		if (at > 0) props[line.slice(0, at)] = line.slice(at + 1);
	}
	if (props.ACTION !== "add" || props.DEVTYPE !== "usb_device") return null;
	// Audio-class devices (interface class 01) alert as audio instead.
	if (/:01/.test(props.ID_USB_INTERFACES || "")) return null;
	const name = (props.ID_MODEL_FROM_DATABASE || props.ID_MODEL || props.PRODUCT || "USB device").replace(/_/g, " ").slice(0, 90);
	return { kind: "usb", title: "Device connected", detail: name };
}

function headphonePorts(text) {
	const ports = {};
	let sink = "";
	for (const line of (text || "").split("\n")) {
		const header = /^Sink #(\d+)/.exec(line);
		if (header) { sink = header[1]; continue; }
		const port = /^\s+Active Port:\s*(\S+)/.exec(line);
		if (port && sink) ports[sink] = /headphone|headset/i.test(port[1]);
	}
	return ports;
}

function jackChange(before, after) {
	if (!before) return "";
	for (const [sink, connected] of Object.entries(after)) {
		if (!(sink in before) || before[sink] === connected) continue;
		return connected ? "connected" : "disconnected";
	}
	return "";
}

// ---- Bloom's battery hub (connectedDevices.ts, ConnectedDevicesPanel.tsx) ----

var GROUPS = [
	{ key: "low", title: "Needs charging" },
	{ key: "pc", title: "This PC" },
	{ key: "audio", title: "Audio" },
	{ key: "phone", title: "Phone & watch" },
	{ key: "accessories", title: "Accessories" },
	{ key: "usb", title: "Drives & cameras" },
	{ key: "other", title: "Other" }
];

function _typeGroup(kind) {
	switch (kind) {
	case "pc": return "pc";
	case "audio": return "audio";
	case "phone":
	case "wearable": return "phone";
	case "mouse":
	case "keyboard":
	case "gamepad": return "accessories";
	case "usb": return "usb";
	default: return "other";
	}
}

function _budParts(buds) {
	return [buds.left, buds.right, buds.case].filter(p => p !== null && p !== undefined);
}

// The level that decides urgency: the lowest part that isn't charging.
function urgentLevel(entry) {
	const parts = entry.buds ? _budParts(entry.buds) : entry.level !== null ? [{ level: entry.level, charging: entry.charging }] : [];
	const draining = parts.filter(p => !p.charging).map(p => p.level);
	return draining.length > 0 ? Math.min(...draining) : null;
}

function _sortLevel(entry) {
	const levels = entry.buds ? _budParts(entry.buds).map(p => p.level) : entry.level !== null ? [entry.level] : [];
	return levels.length > 0 ? Math.min(...levels) : null;
}

function _byUrgency(a, b) {
	const la = _sortLevel(a);
	const lb = _sortLevel(b);
	if (la !== lb) {
		if (la === null) return 1;
		if (lb === null) return -1;
		return la - lb;
	}
	return a.name.localeCompare(b.name);
}

// Low batteries first, then the PC, audio, phones and watches, accessories,
// drives and cameras, the rest; the lowest battery first in each group.
function groupDevices(entries, threshold) {
	const buckets = {};
	for (const entry of entries) {
		const urgent = urgentLevel(entry);
		const key = urgent !== null && urgent <= threshold ? "low" : _typeGroup(entry.kind);
		(buckets[key] = buckets[key] || []).push(entry);
	}
	return GROUPS.filter(g => buckets[g.key]).map(g => ({ key: g.key, title: g.title, entries: buckets[g.key].slice().sort(_byUrgency) }));
}

function _duration(seconds) {
	const minutes = Math.round(seconds / 60);
	if (minutes < 60) return `${minutes} min`;
	const hours = Math.floor(minutes / 60);
	const rest = minutes % 60;
	return rest ? `${hours} h ${rest} min` : `${hours} h`;
}

function pcStatus(pc) {
	if (pc.charging) return pc.secondsToFull ? `Charging · ${_duration(pc.secondsToFull)} to full` : "Charging";
	if (pc.pluggedIn) return "Plugged in";
	return pc.secondsLeft ? `${_duration(pc.secondsLeft)} left` : "On battery";
}

function bluetoothKind(icon) {
	return Bluetooth.bluetoothKind(icon);
}

// Bloom lists wired audio as USB devices and what's in the 3.5 mm jack, not
// the built-in sound card. One row per USB device (its sink and source).
function wiredAudio(nodes, jackHeadphones) {
	const out = jackHeadphones ? [{ id: "jack", name: "Headphones", kind: "audio", wired: true, art: "earbuds-jack" }] : [];
	const seen = {};
	for (const n of nodes || []) {
		if (!n || n.isStream || !n.properties || !/^Audio\/(Sink|Source)$/.test(n.properties["media.class"] || "")) continue;
		if (!/^alsa_(output|input)\.usb-/.test(n.name || "")) continue;
		const name = n.description || n.nickname || "USB audio";
		if (seen[name]) continue;
		seen[name] = true;
		const input = n.properties["media.class"] === "Audio/Source";
		out.push({ id: "usb:" + name, name, kind: "audio", wired: true, art: input ? "microphone" : "headphones-wired" });
	}
	return out;
}

// The USB audio device that just appeared, for its alert; the built-in sound
// card and display audio never alert.
function audioAlert(beforeNodes, afterNodes) {
	const before = wiredAudio(beforeNodes, false).map(d => d.id);
	return wiredAudio(afterNodes, false).find(d => before.indexOf(d.id) < 0) || null;
}

function wiredSub(entry) {
	return entry.id === "jack" ? "Headphone jack" : "USB";
}

function _budLevel(level) {
	return Number.isInteger(level) ? { level, charging: false } : null;
}

// The hub's entries: this PC, connected Bluetooth devices and wired audio.
// `looks` are the user's picks (bloom-device-looks) by device name.
function parseLooks(raw) {
	try {
		const parsed = JSON.parse(raw || "{}");
		return parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
	} catch (e) {
		return {};
	}
}

function entries(pc, bluetooth, wired, looks) {
	const out = [];
	if (pc && pc.present && Number.isInteger(pc.level))
		out.push({ id: "pc", name: "This PC", kind: "pc", wired: false, art: null, level: pc.level, charging: !!pc.charging, buds: null });
	for (const d of bluetooth || []) {
		if (!d.connected) continue;
		const hasBuds = d.buds && (Number.isInteger(d.buds.left) || Number.isInteger(d.buds.right) || Number.isInteger(d.buds.case));
		out.push({
			id: d.path, name: d.name, kind: d.kind || "other", wired: false,
			art: (looks || {})[d.name] || Art.artForKind(d.kind || "other", d.name),
			guess: Art.artForKind(d.kind || "other", d.name),
			level: Number.isInteger(d.battery) ? d.battery : null, charging: false,
			buds: hasBuds ? { left: _budLevel(d.buds.left), right: _budLevel(d.buds.right), case: _budLevel(d.buds.case) } : null
		});
	}
	for (const d of wired || [])
		out.push({ id: d.id, name: d.name, kind: d.kind, wired: true, art: (d.kind === "audio" && (looks || {})[d.name]) || d.art, guess: d.art, level: null, charging: false, buds: null });
	return out;
}
