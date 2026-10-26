.import "notch.js" as Notch

// Music mode rules ported from Bloom (App.tsx @ b5fb962). Plain JS, shared
// with the unit tests.

// Like the Dynamic Island, the collapsed pill shows one live activity: music
// while a session is live (and for 5 s after it pauses), else the clock.
function collapsedMode(s) {
	return s.enabled && s.compactNotch && s.hasMedia && s.activityVisible ? "music" : "status";
}

// A session that faded from the pill stays reachable by hovering it.
function musicOnStatusHover(s) {
	return !s.open && s.hovered && s.mode === "status" && s.enabled && s.hasMedia && (!s.activityVisible || !s.compactNotch);
}

// Bloom getDynamicWidth, in its order.
function contentWidth(s) {
	if (s.onStatusHover)
		return 170 + (s.visualizer ? 30 : 0);
	if (s.mode === "status" && s.hovered)
		return Notch.statusWidth(true, s.widgetCount, s.fitWidth, s.use24h);
	if (s.open)
		return s.layout === "compact" ? 300 : 340;
	if (s.pulse)
		return 200;
	if (s.mode === "status")
		return Notch.statusWidth(false, s.widgetCount, s.fitWidth, s.use24h);
	let w = 140 - (s.use24h ? 16 : 0);
	if (s.visualizer && s.playing)
		w += 30;
	if (s.albumArt)
		w += 30;
	return w;
}

function contentHeight(s) {
	if (s.mode !== "music" || !s.open)
		return 36;
	if (s.layout !== "compact")
		return 120;
	return (s.hasProgress ? 132 : 116) + (s.volumeExpanded ? 36 : 0);
}

// Bloom peeks for a new track while playing, or when playback starts.
function shouldPeek(prev, cur) {
	return cur.playing && (cur.title !== prev.title || !prev.playing);
}

// Bloom TitleMarquee: 30 px/s, never shorter than 5 s.
function marqueeDuration(overflow) {
	return Math.max(overflow / 30, 5);
}

function barScale(playing, level) {
	return playing ? Math.max(0.2, level) : 0.1;
}
