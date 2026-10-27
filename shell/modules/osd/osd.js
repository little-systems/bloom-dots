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

function brightnessPercent(current, maximum) {
	if (!Number.isFinite(current) || !Number.isFinite(maximum) || maximum <= 0)
		return null;
	return Math.round(Math.max(0, Math.min(1, current / maximum)) * 100);
}

function edgePill(edge, screenWidth, screenHeight, scale) {
	const width = 42 * scale;
	const height = 196 * scale;
	return { x: edge === "right" ? screenWidth - width : 0,
		y: (screenHeight - height) / 2, width: width, height: height };
}
