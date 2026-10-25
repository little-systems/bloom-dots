import QtQuick
import QtTest
import "../../shell/services/media.js" as Media

TestCase {
	name: "MediaRules"

	function p(id, props) {
		const o = { id: id, playing: false, hasTrack: true, playingSince: 0, lastActive: 0 };
		for (const k in props) o[k] = props[k];
		return o;
	}

	// Review focus 1.
	function test_pickPlayer() {
		compare(Media.pickPlayer([]), "");
		compare(Media.pickPlayer([p("a"), p("b", { playing: true, playingSince: 5 })]), "b");
		compare(Media.pickPlayer([p("a", { playing: true, playingSince: 9 }), p("b", { playing: true, playingSince: 5 })]), "a", "most recently started wins");
		compare(Media.pickPlayer([p("a", { lastActive: 3 }), p("b", { lastActive: 7 })]), "b", "nothing playing: the one that played last");
		compare(Media.pickPlayer([p("tab", { playing: true, hasTrack: false, playingSince: 99 }), p("b")]), "b", "a player with no track is ignored");
		compare(Media.pickPlayer([p("tab", { hasTrack: false })]), "");
	}

	function test_parseCava() {
		compare(Media.parseCava("0;50;100;25;75;"), [0, 0.5, 1, 0.25, 0.75]);
		compare(Media.parseCava("10;20;"), null);
		compare(Media.parseCava(""), null);
	}

	// Bloom formatTime / formatRemaining.
	function test_times() {
		compare(Media.formatTime(0), "0:00");
		compare(Media.formatTime(65000), "1:05");
		compare(Media.formatTime(600999), "10:00");
		compare(Media.formatRemaining(65000, 200000), "-2:15");
		compare(Media.formatRemaining(300000, 200000), "-0:00");
	}
}
