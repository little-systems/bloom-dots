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
			battery: ({ available: true, ready: true, level: 80, charging: false, pluggedIn: false, threshold: 20, tooltip: "80% remaining" })
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

		function test_unreadBadgeOpensNotificationHistory() {
			const v = make({ notificationUnread: 3 });
			const spy = createTemporaryQmlObject("import QtQuick; import QtTest; SignalSpy { signalName: \"notificationHistoryRequested\" }", host);
			spy.target = v;
			settle(v);
			const badge = findChild(v, "notification-unread");
			verify(badge !== null && badge.visible);
			wait(500);
			mouseClick(v, 560, 10);
			compare(spy.count, 1);
		}

		function test_privacyDotsClearPromptly() {
			const v = make();
			settle(v);
			const mic = findChild(v, "privacy-mic-dot");
			const screen = findChild(v, "privacy-screen-dot");
			compare(mic.visible, false);
			compare(screen.visible, false);
			v.privacy = { microphone: true, screen: true };
			compare(mic.visible, true);
			compare(screen.visible, true);
			v.privacy = { microphone: false, screen: false };
			compare(mic.visible, false);
			compare(screen.visible, false);
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

		// Bloom's glow fades out over 0.15 s as the player closes, and
		// enters afresh (from scale 1.1) when it opens again.
		function test_ambienceFadesWhenThePlayerCloses() {
			const live = playing();
			live.artUrl = Qt.resolvedUrl("../../shell/assets/device-art/anim/mouse.png");
			const v = make({ media: live, layout: "compact" });
			settle(v);
			v.openMusic();
			const glow = findChild(v, "ambience");
			verify(glow, "has the ambience");
			tryCompare(glow, "opacity", 1, 1000);
			// The pointer leaving closes the player, as it would live.
			v.open = false;
			wait(60);
			verify(glow.visible && glow.opacity < 1 && glow.opacity > 0, `fading, ${glow.opacity}`);
			tryCompare(glow, "visible", false, 500);
			v.openMusic();
			tryVerify(() => glow.zoom < 1.8, 1000, "the art enters again");
		}

		// The art's hairline border is one device pixel, as Chromium draws it.
		function test_classicHairlineIsOneDevicePixel() {
			const v = make({ media: playing(), uiScale: 1.25 });
			settle(v);
			v.openMusic();
			fuzzyCompare(findChild(v, "bigArt").width, 96 + 2 * 0.8, 0.001);
		}

		// Bloom's .album-art-glow-bg: the art 4 px past the tile under
		// blur(6px) saturate(2.5) brightness(0.8) at 0.6; hovered, 6 px past
		// under blur(8px) saturate(3) brightness(0.9) at 0.7.
		function test_collapsedArtGlowIsBloomsFilter() {
			const live = playing();
			live.artUrl = Qt.resolvedUrl("../../shell/assets/device-art/anim/mouse.png");
			const v = make({ media: live });
			settle(v);
			const art = findChild(v, "musicArt");
			const glow = findChild(v, "musicArtGlow");
			verify(glow, "has the glow");
			tryVerify(() => glow.visible, 1000, "the glow shows with art");
			compare(glow.width, art.width + 8);
			compare([glow.sigma, glow.saturate, glow.brightness, glow.contrast], [6, 2.5, 0.8, 1]);
			// The rounded fill takes the art as laid out in the glow's box: a
			// shape maps its fill texture at the texture's pixel size, so the
			// raw decoded image showed only a corner of the art.
			const tex = findChild(v, "musicArtGlowTexture");
			verify(tex.sourceItem instanceof Image);
			compare([tex.width, tex.height], [glow.width, glow.height]);
			tryCompare(glow, "opacity", 0.6, 1000);
			const p = art.mapToItem(v, art.width / 2, art.height / 2);
			mouseMove(v, p.x, p.y);
			compare(glow.width, art.width + 12);
			compare([glow.sigma, glow.saturate, glow.brightness], [8, 3, 0.9]);
			tryCompare(glow, "opacity", 0.7, 1000);
		}

		// Bloom's main row doesn't clip; only the pill does, so the art's
		// glow spills into the pill's padding.
		function test_collapsedArtGlowIsClippedByThePillOnly() {
			const v = make({ media: playing() });
			settle(v);
			let p = findChild(v, "musicArtGlow").parent;
			while (p && !p.clip) p = p.parent;
			verify(p, "something clips the row");
			const pill = findChild(v, "pillArea");
			const box = p.mapToItem(pill, 0, 0);
			compare([box.x, box.y, p.width, p.height], [0, 0, pill.width, pill.height]);
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
			// The art sits over the fading clock row: the row takes no input
			// once it's on its way out.
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

		// Bloom's time-center shows the timer while it runs, is paused or has
		// finished.
		function test_clockShowsTheTimer() {
			const v = make();
			settle(v);
			const clock = findChild(v, "notchClock");
			compare(clock.timerActive, false);
			v.timer = { active: true, seconds: 300, finished: false };
			compare(clock.timerActive, true);
			compare(clock.timerSeconds, 300);
		}

		// Bloom's toggleCalendarMode.
		function test_clockClick() {
			const v = make({ defaultPanel: "command-center", rememberPanel: false });
			settle(v);
			v.clockClicked();
			compare(v.panel, "command-center", "a closed notch opens as a click anywhere does");
			v.clockClicked();
			compare(v.panel, "calendar", "an open one goes to the calendar");
			v.closePanel();
			const resets = spy(v, "timerResetRequested");
			v.timer = { active: true, seconds: 0, finished: true };
			v.clockClicked();
			compare(resets.count, 1);
			compare(v.panel, "", "a finished timer only resets");
		}

		// Bloom's handleWheel: scrolling the notch opens it (to the panel it
		// would open), then cycles the panels, at most every 250 ms; tiny moves
		// are ignored.
		function test_wheelCyclesPanels() {
			const v = make({ defaultPanel: "calendar", rememberPanel: false });
			settle(v);
			mouseMove(v, 500, 18);
			compare(v.wheelStep(0, 2), false, "a tiny move does nothing");
			compare(v.panel, "");
			verify(v.wheelStep(0, 100));
			compare(v.panel, "calendar");
			compare(v.wheelStep(0, 100), false, "within 250 ms");
			compare(v.panel, "calendar");
			wait(260);
			v.wheelStep(0, 100);
			compare(v.panel, "command-center");
			wait(260);
			v.wheelStep(0, -100);
			compare(v.panel, "calendar");
			wait(260);
			// A sideways trackpad swipe counts too.
			v.wheelStep(120, 10);
			compare(v.panel, "command-center");
		}

		function test_wheelEventsReachIt() {
			const v = make({ defaultPanel: "command-center", rememberPanel: false });
			settle(v);
			mouseMove(v, 500, 18);
			mouseWheel(v, 500, 18, 0, -120);
			tryCompare(v, "panel", "command-center", 500);
		}

		// Bloom's open panels keep the main row's side widgets (weather left,
		// battery right) beside the panel header's clock and arrows.
		function test_panelKeepsTheStatusWidgets() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			v.openPanel("calendar");
			const row = findChild(v, "mainRow");
			tryCompare(row, "opacity", 1, 1000);
			tryCompare(findChild(v, "statusLeft"), "opacity", 1, 1000);
			tryCompare(findChild(v, "statusRight"), "opacity", 1, 1000);
			verify(!findChild(v, "notchClock").visible, "the panel header draws the clock");
			// Leaving closes the panel; with the pointer away the widgets go.
			mouseMove(v, 500, 470);
			tryCompare(v, "panel", "", 1000);
			tryCompare(findChild(v, "statusLeft"), "opacity", 0, 1000);
			verify(findChild(v, "notchClock").visible);
		}

		// Bloom's bottom corners spring (1000/40) between 18 and the calendar's 28.
		function test_bottomRadiusSprings() {
			const v = make();
			settle(v);
			const far = findChild(v, "farRadius");
			compare(far.stiffness, 1000);
			compare(far.damping, 40);
			compare(far.value, 18);
			mouseMove(v, 500, 18);
			v.openPanel("calendar");
			tryCompare(far, "value", 28, 1000);
		}

		// Bloom's panels have overflow: hidden with the pill's radius: while the
		// pill moves the content is masked to its rounded shape; at rest the mask
		// is off (it costs a pass).
		function test_panelMaskedWhileThePillMoves() {
			const v = make();
			settle(v);
			const loader = findChild(v, "panelLoader");
			compare(loader.layer.enabled, false);
			mouseMove(v, 500, 18);
			v.openPanel("command-center");
			verify(loader.layer.enabled, "masked while springing");
			tryVerify(() => !loader.layer.enabled, 2000, "unmasked at rest");
		}

		// Bloom's first alert frame has no clock: the row goes at once, not
		// over the 0.3 s fade.
		function test_alertHidesTheClockAtOnce() {
			const v = make();
			settle(v);
			const row = findChild(v, "mainRow");
			compare(row.opacity, 1);
			v.deviceAlert = { id: "/a", name: "AirPods Pro", art: "stem-buds", status: "Connected", connected: true, wired: false, bluetooth: true, battery: 72, buds: null, runId: 1 };
			compare(row.opacity, 0);
		}

		// Bloom's handleMouseLeave: a panel closes as soon as the pointer leaves
		// the notch, unless something in it is being typed into.
		function test_leavingClosesAnOpenPanel() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			verify(v.pillHovered);
			compare(v.openPanel("command-center"), "ok");
			mouseMove(v, 500, 30);
			mouseMove(v, 500, 470);
			tryCompare(v, "panel", "", 300);
		}

		function test_typingKeepsThePanelUntilReleased() {
			const v = make();
			settle(v);
			mouseMove(v, 500, 18);
			v.openPanel("calendar");
			v.panelPinned = true;
			mouseMove(v, 500, 470);
			wait(300);
			compare(v.panel, "calendar", "pinned while typing");
			v.panelPinned = false;
			tryCompare(v, "panel", "", 300);
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
			p.pulseMs = { power: 600, low: 600, update: 600 };
			return make(p);
		}

		function bat(props) {
			const b = { available: true, ready: true, level: 80, charging: false, threshold: 20, tooltip: "" };
			for (const k in props) b[k] = props[k];
			// Most tests plug in to charge; a full battery on the charger says so explicitly.
			if (!("pluggedIn" in b))
				b.pluggedIn = b.charging;
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

		// A full battery stops charging on the charger (UPower: Charging →
		// FullyCharged, or PendingCharge at a charge limit): still plugged in.
		function test_fullChargeIsNotUnplugging() {
			const v = fast({ battery: bat({ level: 99, charging: true }) });
			settle(v);
			v.battery = bat({ level: 100, charging: false, pluggedIn: true });
			compare(v.pulse, "", "no On Battery pulse while the charger is connected");
			v.battery = bat({ level: 100, charging: false, pluggedIn: false });
			compare(v.pulse, "power", "unplugging pulses");
		}

		function test_pluggingInWhenFullPulses() {
			const v = fast({ battery: bat({ level: 100, charging: false, pluggedIn: false }) });
			settle(v);
			v.battery = bat({ level: 100, charging: false, pluggedIn: true });
			compare(v.pulse, "power", "Bloom: Charging • 100%");
		}

		// Review focus 1.
		function test_noPulseFromStartupValues() {
			const v = fast({ battery: bat({ ready: false, charging: false }) });
			v.battery = bat({ ready: true, charging: true });
			settle(v);
			compare(v.pulse, "", "UPower's first answer is not a change");
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



		// Review focus 3 (2C): a short peek never cuts a longer one short.
		function test_shortPeekKeepsALongerOne() {
			const v = make({ mode: "peek", pulseMs: { power: 300, low: 600, update: 1500 } });
			settle(v);
			tryCompare(v, "hidden", true, 4000);
			v.updates = { available: true, count: 1 };
			v.updatesArrived();
			v.battery = bat({ charging: true });
			wait(700);
			verify(!v.hidden, "the update peek still runs after the charging one ended");
			compare(v.pulse, "update");
		}

		// Owner decision (2026-10-27): workspaces live in the dock only; the
		// notch neither takes nor shows them.
		function test_noWorkspaceInTheNotch() {
			const v = make();
			compare(v.workspace, undefined, "no workspace input");
			compare(v.workspacePeekEnabled, undefined);
			compare(findChild(v, "pulse-workspace"), null, "no workspace pulse view");
		}

		// Review focus 2.
		function test_hoverHidesAPulse() {
			const v = make({ pulseMs: { power: 2000, low: 600, update: 600 } });
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
			const v = make({ pulseMs: { power: 5000, low: 600, update: 600 } });
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
