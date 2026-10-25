pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "media.js" as Logic

// The media player the notch follows (Bloom: Windows' current media session):
// the most recently started player that is playing, else the one that played
// last. MPRIS doesn't push position, so it is re-read 4 times a second, but
// only while something holds the service (the open player).
Singleton {
	id: root

	// dbusName -> when it last started playing / last changed play state.
	property var _since: ({})
	property var _active: ({})
	property var _holders: ({})

	readonly property var player: {
		const ps = Mpris.players.values;
		const id = Logic.pickPlayer(ps.map(p => ({
			id: p.dbusName,
			playing: p.isPlaying,
			hasTrack: (p.trackTitle ?? "") !== "",
			playingSince: root._since[p.dbusName] ?? 0,
			lastActive: root._active[p.dbusName] ?? 0
		})));
		return ps.find(p => p.dbusName === id) ?? null;
	}

	readonly property bool hasMedia: root.player !== null
	readonly property bool isPlaying: root.player?.isPlaying ?? false
	readonly property string title: root.player?.trackTitle ?? ""
	readonly property string artist: root.player?.trackArtist ?? ""
	readonly property string artUrl: root.player?.trackArtUrl ?? ""
	readonly property real lengthMs: root.player && root.player.lengthSupported ? root.player.length * 1000 : 0
	readonly property bool canSeek: root.player?.canSeek ?? false
	property real positionMs: 0

	function hold(key, on) {
		const next = Object.assign({}, root._holders);
		if (on)
			next[key] = true;
		else
			delete next[key];
		root._holders = next;
	}

	function togglePlaying() {
		if (root.player && root.player.canTogglePlaying)
			root.player.togglePlaying();
	}

	function next() {
		if (root.player && root.player.canGoNext)
			root.player.next();
	}

	function previous() {
		if (root.player && root.player.canGoPrevious)
			root.player.previous();
	}

	function seek(ms) {
		if (!root.player || !root.player.canSeek)
			return;
		root.player.position = ms / 1000;
		root.positionMs = ms;
	}

	function _mark(p) {
		const now = Date.now();
		const active = Object.assign({}, root._active);
		active[p.dbusName] = now;
		root._active = active;
		if (p.isPlaying) {
			const since = Object.assign({}, root._since);
			since[p.dbusName] = now;
			root._since = since;
		}
	}

	Instantiator {
		model: Mpris.players
		delegate: Connections {
			required property var modelData
			target: modelData
			function onIsPlayingChanged() { root._mark(modelData); }
		}
	}

	Timer {
		interval: 250
		repeat: true
		triggeredOnStart: true
		running: Object.keys(root._holders).length > 0 && root.player !== null
		onTriggered: {
			root.player.positionChanged();
			root.positionMs = root.player.position * 1000;
		}
	}
}
