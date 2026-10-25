// Media rules: which MPRIS player the notch follows, cava output, and the
// player's time labels (Bloom CompactMediaPlayer formatTime/formatRemaining).
// Plain JS, shared with the unit tests.

// Bloom followed Windows' current media session. On MPRIS: the player that
// most recently started playing; with none playing, the one that played last.
// A player with no track (an idle browser tab) never counts.
function pickPlayer(players) {
	const withTrack = players.filter(p => p.hasTrack);
	const playing = withTrack.filter(p => p.playing).sort((a, b) => b.playingSince - a.playingSince);
	if (playing.length)
		return playing[0].id;
	const recent = withTrack.slice().sort((a, b) => b.lastActive - a.lastActive);
	return recent.length ? recent[0].id : "";
}

// One cava raw ASCII frame ("12;80;...;"), levels 0-100, to five 0-1 levels.
function parseCava(line) {
	const v = line.split(";").filter(s => s.trim() !== "").map(Number).filter(n => !isNaN(n)).map(n => n / 100);
	return v.length >= 5 ? v.slice(0, 5) : null;
}

function _clock(totalSeconds) {
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;
	return `${minutes}:${seconds.toString().padStart(2, "0")}`;
}

function formatTime(ms) {
	return ms <= 0 ? "0:00" : _clock(Math.floor(ms / 1000));
}

function formatRemaining(elapsed, duration) {
	return "-" + _clock(Math.floor(Math.max(0, duration - elapsed) / 1000));
}
