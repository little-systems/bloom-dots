// Pure OSD and volume-protection rules. Device observation stays in services.

function protectVolume(previous, next, options, ready) {
	if (!ready || !options.enabled)
		return { value: next, blocked: false, reason: "" };
	if (next - previous > options.maxJump / 100)
		return { value: previous, blocked: true, reason: "jump" };
	if (next > options.maxLevel / 100)
		return { value: Math.min(previous, options.maxLevel / 100), blocked: true, reason: "maximum" };
	return { value: next, blocked: false, reason: "" };
}

function volumeObservation(previous, next, options, ready) {
	const decision = protectVolume(previous, next, options, ready);
	return { value: decision.value, correction: decision.blocked,
		announce: !decision.blocked, reason: decision.reason };
}

function brightnessPercent(current, maximum) {
	if (!Number.isFinite(current) || !Number.isFinite(maximum) || maximum <= 0)
		return null;
	return Math.round(Math.max(0, Math.min(1, current / maximum)) * 100);
}

function parseBrightness(text) {
	const m = /^([A-Za-z0-9_.:+-]+),backlight,(\d+),(\d+)%,(\d+)\s*$/.exec((text || "").trim());
	if (!m) return null;
	const current = Number(m[2]);
	const maximum = Number(m[4]);
	if (!Number.isSafeInteger(current) || !Number.isSafeInteger(maximum) || maximum <= 0 || current > maximum)
		return null;
	return { device: m[1], current: current, maximum: maximum, percent: brightnessPercent(current, maximum) };
}

function edgePill(edge, screenWidth, screenHeight, scale) {
	const width = 42 * scale;
	const height = 196 * scale;
	return { x: edge === "right" ? screenWidth - width : 0,
		y: (screenHeight - height) / 2, width: width, height: height };
}

function mixerRows(nodes) {
	return (nodes || []).filter(n => n && n.isStream && n.isSink && n.ready && n.audio)
		.map(n => ({ id: n.id,
			name: n.properties?.["application.name"] || n.description || n.name || "Audio",
			volume: n.audio.volume, muted: !!n.audio.muted }));
}
