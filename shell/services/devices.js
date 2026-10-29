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

// ---- Bloom's device alert (App.tsx showDeviceAlert, deviceAlertStatus) ----

var PLUGGED_ART = ["headphones-wired", "earbuds-usbc", "earbuds-jack", "flash-drive", "ssd", "hub", "webcam", "microphone"];

function alertStatus(art, connected, wired) {
	if (art === "sd-card") return connected ? "Inserted" : "Removed";
	// A wired device is plugged in whatever it was picked to look like.
	if (wired || PLUGGED_ART.indexOf(art) >= 0) return connected ? "Plugged in" : "Unplugged";
	return connected ? "Connected" : "Disconnected";
}

// How long an alert stays (Bloom DEVICE_ALERT_MS).
function alertMs(connected) {
	return connected ? 4200 : 2600;
}

function _alert(name, art, connected, wired, extra) {
	return Object.assign({ name, art, connected, wired, bluetooth: false, battery: null, buds: null, status: alertStatus(art, connected, wired) }, extra || {});
}

function bluetoothAlert(device, connected, looks) {
	const art = (looks || {})[device.name] || Art.artForKind(device.kind || "other", device.name);
	const buds = device.buds && (Number.isInteger(device.buds.left) || Number.isInteger(device.buds.right)) ? device.buds : null;
	return _alert(device.name, art, connected, false, {
		bluetooth: true,
		battery: connected && Number.isInteger(device.battery) ? device.battery : null,
		buds: connected ? buds : null
	});
}

function wiredAlert(name, art, connected, looks) {
	return _alert(name, (looks || {})[name] || art, connected, true);
}

// Bluetooth devices whose connection changed, by path.
function connectionChanges(before, after) {
	const out = [];
	for (const d of after || []) {
		const old = (before || []).find(o => o.path === d.path);
		if (old && old.connected !== d.connected) out.push({ device: d, connected: d.connected });
		else if (!old && d.connected) out.push({ device: d, connected: true });
	}
	return out;
}

// Bloom's queue: the same device replaces its alert; another device waits
// behind the one showing, at most DEVICE_ALERT_QUEUE (3), newest last.
function queueAlert(current, queue, alert) {
	if (current && current.id !== alert.id)
		return { show: null, queue: (queue || []).filter(q => q.id !== alert.id).concat([alert]).slice(-3) };
	return { show: alert, queue: queue || [] };
}

// ---- USB devices (shell/scripts/usb-devices.sh; Bloom usb.rs, usbArtFor.ts) ----

function parseUsb(text) {
	const out = [];
	for (const line of (text || "").split("\n")) {
		const f = line.split("\t");
		if (f.length < 3 || !f[0] || !f[1]) continue;
		out.push({ id: "usb:" + f[0], class: f[1], name: f.slice(2).join("\t") });
	}
	return out;
}

var _SSD = /\b(ssd|pssd|nvme|t[579]\b|extreme portable|portable ssd|x[56]\b)/i;
var _CARD = /\b(sd|sdhc|sdxc|micro ?sd|card|reader|mmc|compactflash|cf)\b/i;
var _EARBUDS = /\b(buds?|pods|earbuds?|earphones?|in-?ear)\b/i;

function usbArtFor(d) {
	switch (d.class) {
	case "camera": return "webcam";
	case "audio-in": return "microphone";
	case "audio-out": return _EARBUDS.test(d.name) ? "earbuds-usbc" : "headphones-wired";
	case "jack-headset": return "earbuds-jack";
	case "jack-headphones": return "headphones-wired";
	default:
		if (_SSD.test(d.name)) return "ssd";
		if (_CARD.test(d.name)) return "sd-card";
		return "flash-drive";
	}
}

// A readable name; a generic one says nothing the drawing doesn't.
function usbDisplayName(d) {
	const cleaned = (d.name || "")
		.replace(/\s+(usb|scsi)(\s+disk)?\s+device$/i, "")
		.replace(/^(usb\s+)?(mass\s+storage|disk|drive)(\s+device)?$/i, "")
		.trim();
	if (cleaned) return cleaned;
	switch (d.class) {
	case "camera": return "USB camera";
	case "audio-in": return "USB microphone";
	case "audio-out": return "USB audio";
	default: return "USB drive";
	}
}

function _isAudio(cls) {
	return cls === "audio-out" || cls === "audio-in" || cls.startsWith("jack-");
}

// Devices plugged in or removed between two lists.
function usbChanges(before, after) {
	const out = [];
	for (const d of after || [])
		if (!(before || []).some(b => b.id === d.id)) out.push({ device: d, connected: true });
	for (const d of before || [])
		if (!(after || []).some(a => a.id === d.id)) out.push({ device: d, connected: false });
	return out;
}

// A USB device's alert; an audio device's look can be picked.
function usbAlert(d, connected, looks) {
	const name = usbDisplayName(d);
	const art = (_isAudio(d.class) && (looks || {})[name]) || usbArtFor(d);
	return _alert(name, art, connected, true);
}

// The panel's wired devices: what's in the jack, then USB devices.
function wiredDevices(usb, jackHeadphones) {
	const out = jackHeadphones ? [{ id: "jack", name: "Headphones", kind: "audio", wired: true, art: "earbuds-jack" }] : [];
	for (const d of usb || [])
		out.push({ id: d.id, name: usbDisplayName(d), kind: _isAudio(d.class) ? "audio" : "usb", wired: true, art: usbArtFor(d) });
	return out;
}
