import QtQuick
import QtTest
import "../../shell/modules/notch"

Item {
	id: host
	width: 1000
	height: 480

	Component {
		id: viewComponent
		NotchView {
			width: 1000
			height: 480
			weather: ({ shown: true, label: "28°C", icon: "sun", tooltip: "Clear — Chennai" })
			battery: ({ available: true, ready: true, level: 80, charging: false, threshold: 20, tooltip: "80% remaining" })
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	Component {
		id: watchingComponent
		NotchView {
			property bool sawWatch: false
			width: 1000
			height: 480
			visualizerEnabled: true
			media: ({ hasMedia: true, isPlaying: true, title: "Song", artist: "", artUrl: "", lengthMs: 0, canSeek: false })
			onMusicWatched: watched => sawWatch = watched
		}
	}

	// Simulated cava: new levels 30 times a second for frame-count tests.
	Timer {
		id: fakeCava
		property var target: null
		interval: 33
		repeat: true
		running: target !== null
		onTriggered: target.levels = [Math.random(), Math.random(), Math.random(), Math.random(), Math.random()]
	}

	TestCase {
		name: "NotchView"
		when: windowShown

		function make(props) {
		// Tests share one offscreen pointer; keep its previous hover out of new views.
		mouseMove(host, 0, 400);
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v !== null);
			return v;
		}

		// After the drop-in: impacted, expanded and no longer startup-locked.
		function settle(v) {
			v.ready = true;
			tryCompare(v, "impacted", true, 1000);
			tryCompare(v, "startupAnimating", false, 3000);
		}

		function centre(v) { return { x: 500, y: v.target.height / 2 }; }

		function test_startupDropIn() {
			const v = make();
			compare(v.target.y, 250, "parked below before ready");
			v.ready = true;
			compare(v.target.y, 0);
			compare(v.target.width, 30.6, "a dot rising to the edge");
			tryCompare(v, "impacted", true, 1000);
			compare(v.target.width, 140);
			compare(v.target.height, 36);
			compare(v.target.edgeRadius, 0);
		}

		function test_hoverOpensTheStatusStrip() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(v.target.width, 300, "200 + 2 widgets x 50");
			mouseMove(v, 500, 300);
			tryCompare(v, "statusHover", false, 500);
			compare(v.target.width, 140);
		}

		function test_twentyFourHourClockIsNarrower() {
			const v = make({ use24h: true });
			settle(v);
			compare(v.target.width, 124);
		}

		// Review focus 4.
		function test_widgetWithoutDataIsHidden() {
			const v = make({ battery: { available: false } });
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(findChild(v, "widget-battery"), null);
			verify(findChild(v, "widget-weather") !== null);
			compare(v.target.width, 300, "width still counts configured widgets, as Bloom");
		}

		function test_tooltipAfterDelay() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			wait(600); // let the pill finish widening before locating the widget
			const w = findChild(v, "widget-battery");
			verify(w !== null);
			const p = w.mapToItem(v, w.width / 2, w.height / 2);
			mouseMove(v, p.x, p.y);
			const tip = findChild(v, "statusTooltip");
			verify(!tip.shown, "not before the delay");
			tryCompare(tip, "shown", true, 1000);
			compare(tip.text, "80% remaining");
			mouseMove(v, 500, 300);
			tryCompare(tip, "shown", false, 500);
		}

		function test_peekModeHidesUntilShown() {
			const v = make({ mode: "peek" });
			settle(v);
			verify(v.hidden);
			compare(v.target.y, -100);
			compare(v.target.width, 39.1);
			v.peek(300);
			verify(!v.hidden);
			tryCompare(v, "hidden", true, 1500);
		}

		// Review focus 1: the band takes input only while the notch is hidden.
		function test_bandOnlyWhileHidden() {
			const fixed = make();
			settle(fixed);
			verify(!fixed.bandActive);
			const smart = make({ mode: "smart", overlapped: true });
			settle(smart);
			verify(smart.hidden);
			verify(smart.bandActive);
			smart.overlapped = false;
			verify(!smart.hidden);
			verify(!smart.bandActive);
		}

		function test_edgeDwellRevealsAndGraceHides() {
			const v = make({ mode: "peek", edgeDelay: 200 });
			settle(v);
			verify(v.hidden);
			const b = v.bandItem.mapToItem(v, v.bandItem.width / 2, 1);
			mouseMove(v, b.x, b.y);
			wait(100);
			verify(v.hidden, "not before the dwell");
			tryCompare(v, "hidden", false, 1000);
			// The pointer never reaches the pill: the reveal lets go after the
			// 1 s hand-off, then the 800 ms grace runs.
			wait(1200);
			verify(!v.hidden, "hand-off, then grace");
			tryCompare(v, "hidden", true, 1500);
		}

		function test_smartModeFollowsOverlap() {
			const v = make({ mode: "smart" });
			settle(v);
			verify(!v.hidden);
			v.overlapped = true;
			verify(v.hidden);
			compare(v.target.y, -100);
		}

		function test_userVisibility() {
			const v = make();
			settle(v);
			v.userVisible = false;
			compare(v.target.y, -150);
			compare(v.target.opacity, 0);
		}

		function test_statsWantedOnlyForStatsWidgets() {
			const v = make({ widgets: { left: ["cpu"], right: ["battery"] } });
			const spy = createTemporaryQmlObject("import QtQuick; import QtTest; SignalSpy { signalName: \"statsWanted\" }", host);
			spy.target = v;
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(spy, "count", 1, 500);
			compare(spy.signalArguments[0][0], true);
			mouseMove(v, 500, 300);
			tryCompare(spy, "count", 2, 500);
			compare(spy.signalArguments[1][0], false);
		}

		// Review focus 5: a destroyed notch gives back its stats hold.
		function test_releasesHoldsOnDestruction() {
			const v = make({ widgets: { left: ["cpu"], right: [] } });
			let last = null;
			v.statsWanted.connect(w => last = w);
			settle(v);
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(last, true);
			v.destroy();
			wait(0);
			compare(last, false);
		}

		// A fullscreen app on this monitor: the reveal band must not take the
		// top edge from it (Bloom drops edge input while fullscreen is in front).
		function test_fullscreenSuppressesTheBand() {
			const v = make({ mode: "smart", overlapped: true });
			settle(v);
			verify(v.hidden);
			verify(v.bandActive);
			v.suppressed = true;
			verify(!v.bandActive);
		}

		function test_stateObject() {
			const v = make({ mode: "smart" });
			settle(v);
			const s = v.stateObject();
			compare(s.mode, "smart");
			compare(s.hidden, false);
			compare(s.width, 140);
			compare(s.visible, true);
		}
			function playing(title) {
			return { hasMedia: true, isPlaying: true, title: title || "Song", artist: "Artist", artUrl: "", lengthMs: 200000, canSeek: true };
		}

		function spy(target, signalName) {
			return createTemporaryObject(spyComponent, host, { target: target, signalName: signalName });
		}

		function clickArt(v) {
			const art = findChild(v, "musicArt");
			verify(art !== null, "collapsed art");
			const p = art.mapToItem(v, art.width / 2, art.height / 2);
			mouseClick(v, p.x, p.y);
		}

		function test_musicTakesTheCollapsedPill() {
			const v = make({ media: playing() });
			settle(v);
			compare(v.bloomMode, "music");
			compare(v.target.width, 200, "140 + visualizer 30 + art 30");
		}

		// Review focus 3.
		function test_noVisualizerWithoutCava() {
			const v = make({ media: playing(), visualizerEnabled: false });
			settle(v);
			compare(v.target.width, 170);
			compare(findChild(v, "collapsedVisualizer").visible, false);
		}

		function test_pausedMusicLingersThenFades() {
			const v = make({ media: playing() });
			settle(v);
			const paused = playing();
			paused.isPlaying = false;
			v.media = paused;
			compare(v.bloomMode, "music");
			compare(v.target.width, 170, "no visualizer width while paused");
			tryCompare(v, "bloomMode", "status", 6500);
			compare(v.target.width, 140);
		}

		function test_fadedSessionShowsOnHover() {
			const v = make({ media: playing() });
			settle(v);
			const paused = playing();
			paused.isPlaying = false;
			v.media = paused;
			tryCompare(v, "bloomMode", "status", 6500);
			mouseMove(v, 500, 18);
			tryCompare(v, "musicOnHover", true, 500);
			compare(v.target.width, 200, "170 + visualizer");
		}

		function test_artOpensAndLeavingClosesThePlayer() {
			const v = make({ media: playing() });
			settle(v);
			mouseMove(v, 500, 18);
			clickArt(v);
			verify(v.open);
			compare(v.target.width, 340);
			compare(v.target.height, 120);
			mouseMove(v, 500, 400);
			tryCompare(v, "open", false, 500);
			compare(v.target.width, 200);
		}

		function test_compactHeights() {
			const v = make({ media: playing(), layout: "compact" });
			settle(v);
			v.openMusic();
			compare(v.target.width, 300);
			compare(v.target.height, 132);
			v.volumeExpanded = true;
			compare(v.target.height, 168);
			const live = playing();
			live.lengthMs = 0;
			v.media = live;
			v.volumeExpanded = false;
			compare(v.target.height, 116);
		}

		function test_rightClickArtGoesBack() {
			const v = make({ media: playing() });
			const s = spy(v, "previousTrack");
			settle(v);
			const art = findChild(v, "musicArt");
			const p = art.mapToItem(v, art.width / 2, art.height / 2);
			mouseClick(v, p.x, p.y, Qt.RightButton);
			compare(s.count, 1);
			verify(!v.open);
		}

		function test_trackChangePeeksInPeekMode() {
			const v = make({ mode: "peek", media: playing("One") });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.media = playing("Two");
			verify(!v.hidden, "a new track shows the notch");
			tryCompare(v, "hidden", true, 4000);
		}

		function test_musicOffFallsBackToStatus() {
			const v = make({ media: playing() });
			settle(v);
			v.openMusic();
			v.musicEnabled = false;
			verify(!v.open);
			compare(v.bloomMode, "status");
			compare(v.target.width, 140);
		}

		// Review focus 2.
		function test_playerVanishingClosesThePanel() {
			const v = make({ media: playing() });
			settle(v);
			v.openMusic();
			v.media = { hasMedia: false, isPlaying: false, title: "", artist: "", artUrl: "", lengthMs: 0, canSeek: false };
			verify(!v.open);
			compare(v.bloomMode, "status");
		}

		function test_layoutChoiceAndWatching() {
			// Visualizer off: the collapsed notch watches nothing, so opening is what starts the watch.
			const v = make({ media: playing(), visualizerEnabled: false });
			const layouts = spy(v, "layoutChosen");
			const watched = spy(v, "musicWatched");
			settle(v);
			mouseMove(v, 500, 18);
			clickArt(v);
			verify(watched.count >= 1);
			compare(watched.signalArguments[watched.count - 1][0], true);
			const big = findChild(v, "bigArt");
			const p = big.mapToItem(v, big.width / 2, big.height / 2);
			mouseClick(v, p.x, p.y);
			compare(layouts.count, 1);
			compare(layouts.signalArguments[0][0], "compact");
		}
			// Music already playing when the notch is created: the watch is true from
		// the start, so it must still be announced (cava and position polling).
		function test_watchAnnouncedAtCreation() {
			mouseMove(host, 0, 400);
			const v = createTemporaryObject(watchingComponent, host);
			v.ready = true;
			// The collapsed visualizer counts once the notch is shown (after the drop-in).
			tryCompare(v, "sawWatch", true, 2000);
		}
			// The collapsed visualizer is only "shown" while the notch is: a hidden
		// notch must not keep cava and the position timer running.
		function test_hiddenNotchStopsWatching() {
			const v = make({ mode: "peek", media: playing() });
			let last = null;
			v.musicWatched.connect(w => last = w);
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			compare(last, false);
		}

		// Opened from a script or keybind, the panel must not stay open forever
		// if the pointer never comes to it, and a hidden notch shows while open.
		function test_scriptedOpenClosesWithoutThePointer() {
			const v = make({ mode: "peek", media: playing() });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.openMusic();
			verify(v.open);
			verify(!v.hidden, "a hidden notch shows while the player is open");
			tryCompare(v, "open", false, 6000);
		}

		function test_scriptedOpenStaysWhileHovered() {
			const v = make({ media: playing() });
			settle(v);
			v.openMusic();
			mouseMove(v, 500, 60);
			wait(5000);
			verify(v.open, "the pointer reached the player, so it stays open");
		}
			// The collapsed visualizer sits behind the open player and a hidden
		// notch; it must stop animating there (CPU, measured 2026-10-25).
		function test_collapsedVisualizerOnlyAnimatesOnScreen() {
			const v = make({ media: playing() });
			settle(v);
			const viz = findChild(v, "collapsedVisualizer");
			verify(viz.active, "on screen while collapsed");
			v.openMusic();
			verify(!viz.active, "behind the open player");
			v.open = false;
			verify(viz.active);
			v.visualizerEnabled = false;
			verify(!viz.active, "visualizer turned off");
			v.visualizerEnabled = true;
			v.userVisible = false;
			verify(!viz.active, "notch hidden by the user");
		}
			function fast(props) {
			const p = props || {};
			p.pulseMs = { power: 600, low: 600, update: 600, workspace: 600 };
			return make(p);
		}

		function bat(props) {
			const b = { available: true, ready: true, level: 80, charging: false, threshold: 20, tooltip: "" };
			for (const k in props) b[k] = props[k];
			return b;
		}

		function test_chargingPulse() {
			const v = fast();
			settle(v);
			v.battery = bat({ charging: true });
			compare(v.pulse, "power");
			compare(v.target.width, 200, "Bloom: pulses are 200 wide");
			tryCompare(v, "pulse", "", 1500);
			compare(v.target.width, 140);
		}

		// Review focus 1.
		function test_noPulseFromStartupValues() {
			const v = fast({ battery: bat({ ready: false, charging: false }), workspace: null });
			v.battery = bat({ ready: true, charging: true });
			v.workspace = { id: 2, name: "2", ids: [1, 2] };
			settle(v);
			compare(v.pulse, "", "UPower's first answer and the login workspace are not changes");
		}

		function test_lowBatteryAtLoginPulsesOnce() {
			const v = fast({ battery: bat({ level: 12 }) });
			v.ready = true;
			compare(v.pulse, "low", "Bloom pulses a low battery as soon as it is ready");
			tryCompare(v, "pulse", "", 1500);
			v.battery = bat({ level: 11 });
			compare(v.pulse, "", "once per crossing");
			v.battery = bat({ level: 30, charging: true });
			v.battery = bat({ level: 19, charging: false });
			compare(v.pulse, "low", "re-armed after charging");
		}

		function test_noBatteryNoPulse() {
			const v = fast({ battery: bat({ available: false, level: 0 }) });
			settle(v);
			v.battery = bat({ available: false, level: 0, charging: true });
			compare(v.pulse, "", "a desktop has no battery pulses");
		}

		function test_updatePulseAndDot() {
			const v = fast();
			settle(v);
			const dot = findChild(v, "update-dot");
			verify(!dot.visible);
			v.updates = { available: true, count: 3 };
			v.updatesArrived();
			compare(v.pulse, "update");
			verify(dot.visible, "the dot stays while updates are pending");
			tryCompare(v, "pulse", "", 1500);
			verify(dot.visible);
			v.updateIndicator = false;
			verify(!dot.visible, "bloom-show-update-indicator off");
		}

		function test_workspacePulse() {
			const v = fast({ workspace: { id: 1, name: "1", ids: [1, 2] } });
			settle(v);
			v.workspace = { id: 2, name: "2", ids: [1, 2] };
			compare(v.pulse, "workspace");
			tryCompare(v, "pulse", "", 1500);
			v.workspacePeekEnabled = false;
			v.workspace = { id: 1, name: "1", ids: [1, 2] };
			compare(v.pulse, "", "turned off");
		}

		// Review focus 3.
		function test_rapidWorkspaceSwitchesShowOnePulse() {
			const v = fast({ mode: "peek", workspace: { id: 1, name: "1", ids: [1, 2, 3] } });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.workspace = { id: 2, name: "2", ids: [1, 2, 3] };
			wait(300);
			v.workspace = { id: 3, name: "3", ids: [1, 2, 3] };
			compare(v.pulse, "workspace");
			verify(!v.hidden, "peek mode shows it");
			wait(450);
			verify(!v.hidden && v.pulse === "workspace", "timed from the last switch, not the first");
			tryCompare(v, "hidden", true, 1500);
		}

		function test_shortPeekKeepsALongerOne() {
			const v = make({ mode: "peek", pulseMs: { power: 600, low: 600, update: 1500, workspace: 300 }, workspace: { id: 1, name: "1", ids: [1, 2] } });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.updates = { available: true, count: 1 };
			v.updatesArrived();
			v.workspace = { id: 2, name: "2", ids: [1, 2] };
			wait(700);
			verify(!v.hidden, "the update peek still runs");
			compare(v.pulse, "update", "back to the update pulse after the workspace one");
		}

		// Review focus 2.
		function test_hoverHidesAPulse() {
			const v = make({ pulseMs: { power: 2000, low: 600, update: 600, workspace: 600 } });
			settle(v);
			v.battery = bat({ charging: true });
			compare(v.pulse, "power");
			mouseMove(v, 500, 18);
			tryCompare(v, "statusHover", true, 500);
			compare(v.pulse, "", "the status strip takes the pill");
			compare(v.target.width, 300);
			mouseMove(v, 500, 300);
			tryCompare(v, "pulse", "power", 500);
			tryCompare(v, "pulse", "", 2500);
		}

		function test_pulseHoldsWhileMusicIsCollapsed() {
			const v = fast({ media: playing(), albumArtEnabled: false });
			settle(v);
			compare(v.target.width, 170, "collapsed music: clock + visualizer");
			v.battery = bat({ charging: true });
			compare(v.target.width, 200, "pulses win over the collapsed music width");
		}

		function test_stateObjectShowsPulses() {
			const v = fast();
			settle(v);
			v.updates = { available: true, count: 1 };
			v.updatesArrived();
			const s = v.stateObject();
			compare(s.pulse, "update");
			compare(s.updateDot, true);
		}

		function test_updatesWanted() {
			const v = make();
			const s = spy(v, "updatesWanted");
			v.updateIndicator = false;
			compare(s.signalArguments[s.count - 1][0], false);
			v.updateIndicator = true;
			compare(s.signalArguments[s.count - 1][0], true);
		}

		// Frames the window draws in `ms`: the cost that matters on the
		// owner's UHD 620 is how often the surface redraws, not what's on it.
		function framesIn(ms) {
			let n = 0;
			const count = () => n++;
			host.Window.window.afterRendering.connect(count);
			wait(ms);
			host.Window.window.afterRendering.disconnect(count);
			return n;
		}

		// Waits for running animations (the hide spring's tail can outlast a
		// fixed wait on a slow run) to finish, so a count measures only what follows.
		function settleFrames() {
			for (let i = 0; i < 20 && framesIn(250) > 0; i++) {}
		}

		function test_idleNotchDrawsNoFrames() {
			const v = make();
			settle(v);
			wait(800);
			compare(framesIn(1000), 0);
		}

		function test_hiddenNotchWithMusicDrawsNoFrames() {
			const v = make({ mode: "peek", media: playing() });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			settleFrames();
			fakeCava.target = v;
			const n = framesIn(1000);
			fakeCava.target = null;
			compare(n, 0, "the hidden visualizer must not animate");
		}

		function test_settledPulseDrawsNoFrames() {
			const v = make({ pulseMs: { power: 5000, low: 600, update: 600, workspace: 600 } });
			settle(v);
			v.battery = bat({ charging: true });
			wait(1200);
			compare(framesIn(1000), 0, "a pulse at rest is static");
		}

		// The owner chose Bloom's 60 fps motion for the bars.
		function test_visibleVisualizerAnimates() {
			const v = make({ media: playing() });
			settle(v);
			wait(800);
			fakeCava.target = v;
			const n = framesIn(1000);
			fakeCava.target = null;
			verify(n > 40, `the visualizer animates every display frame (${n} frames)`);
		}
	}
}
