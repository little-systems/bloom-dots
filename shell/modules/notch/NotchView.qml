import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../services/stats.js" as Stats
import "notch.js" as Logic
import "music.js" as Music
import "pulses.js" as Pulses
import "panels.js" as Panels
import "shelf.js" as Shelf
import "../../common/render"
import "../../common/i18n"

// The notch (Bloom App.tsx): a pill on the screen edge that springs between
// its startup drop-in, the collapsed clock, the hovered status strip and its
// hidden state in smart and peek modes. Pure UI: NotchWindow feeds it data
// and uses hitItem/bandItem for the layer surface's input mask. Sizes are in
// unscaled px; the stage scales them from the top centre.
Item {
	id: root

	property string mode: "fixed"
	property int edgeDelay: 200
	property var widgets: ({ left: ["weather"], right: ["battery"] })
	property bool use24h: false
	property real uiScale: 1
	property bool overlapped: false
	property bool userVisible: true
	property bool sessionLocked: false
	property bool lockPreparing: false
	readonly property bool surfaceVisible: root.userVisible && !root.lockPreparing && !root.sessionLocked
	property color bg: Qt.rgba(0, 0, 0, 0.8)
	property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
	property color textColor: "white"
	// bloom-edge-shine-enabled: the reflective rim around the notch.
	property bool edgeShine: false
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property var now: new Date()
	property var weather: ({ shown: false, label: "", icon: "thermometer", tooltip: "" })
	property var battery: ({ available: false, ready: false, level: 0, charging: false, pluggedIn: false, threshold: 20, tooltip: "" })
	property var updates: ({ available: false, count: 0 })
	property bool updateIndicator: true
	property var pulseMs: ({ power: Tokens.pulse.powerMs, low: Tokens.pulse.lowBatteryMs, update: Tokens.pulse.updateMs })
	signal updatesWanted(bool wanted)
	property var stats: ({ cpu: 0, ram: 0, disk: 0, up: 0, down: 0 })
	// Music (Bloom music mode), fed by NotchWindow.
	property bool musicEnabled: true
	property bool compactNotch: true
	property bool visualizerEnabled: true
	property bool albumArtEnabled: true
	property bool ambienceEnabled: true
	property bool glowEnabled: true
	property string layout: "classic"
	property var media: ({ hasMedia: false, isPlaying: false, title: "", artist: "", artUrl: "", lengthMs: 0, canSeek: false })
	property real positionMs: 0
	property var levels: [0.18, 0.18, 0.18, 0.18, 0.18]
	property real volume: 0
	property bool muted: false
	property bool mixerAvailable: false
	property string panel: ""
	property string defaultPanel: "calendar"
	property string lastPanel: "calendar"
	property bool rememberPanel: true
	property var enabledPanels: ({ calendar: true, "command-center": true, devices: true })
	property int calendarRows: 5
	// The Pomodoro timer for the clock: shown while it runs or has finished.
	property var timer: ({ active: false, seconds: 0, finished: false })
	signal timerResetRequested()
	// Bloom's toggleCalendarMode: a finished timer resets; a closed notch
	// opens as a click anywhere does; an open one goes to the calendar.
	function clockClicked() {
		if (root.timer.finished) {
			root.timerResetRequested();
			return;
		}
		if (root.panel === "" && !root.open) root.openPanel("");
		else root.openPanel("calendar");
	}
	// The Devices panel's measured height (DevicesView.panelHeight).
	property real devicesHeight: 150
	// How far the open panel's list is scrolled.
	property real panelScroll: 0
	property int shelfCount: 0
	signal shelfFilesDropped(var paths)
	signal shelfTextDropped(string text)
	property bool _shelfDragOpened: false
	property bool _shelfDraggingOut: false
	property bool _shelfDroppedHere: false
	property string _beforeShelfPanel: ""
	property bool _beforeShelfMusic: false
	readonly property Item shelfBubbleHit: shelfBubble.hitEnabled ? shelfBubble : null
	readonly property Item musicBubbleHit: musicBubble.hitEnabled ? musicBubble : null
	readonly property bool _showActivities: root.ready && root.expanded && root.surfaceVisible && !root.hidden
		&& !root.open && root.panel === ""
	readonly property bool _showShelfBubble: root._showActivities && root.shelfCount > 0
	readonly property bool _showMusicBubble: root._showActivities && (root.timer.active || root.agentVisible) && root.musicEnabled
		&& root.compactNotch && root.media.hasMedia && root.musicActivityVisible

	// An item's centre relative to the pill's top centre, in window pixels
	// (the pill is centred on the screen), for tests that click it.
	function _fromPillCentre(item) {
		const c = item.mapToItem(null, item.width / 2, item.height / 2);
		const p = pillArea.mapToItem(null, pillArea.width / 2, 0);
		return { dx: c.x - p.x, y: c.y };
	}

	function shelfDragEnter() {
		if (root._shelfDraggingOut || root.panel === "shelf" || root.alertVisible) return;
		scriptedPanelClose.stop();
		root._beforeShelfPanel = root.panel;
		if (root.hidden) root.edgeArmed = true;
		root._beforeShelfMusic = root.open;
		root._shelfDragOpened = true;
		root.openPanel("shelf");
	}
	function shelfDragLeave() {
		if (!root._shelfDragOpened) return;
		root._shelfDragOpened = false;
		root.edgeArmed = false;
		if (root.panel !== "shelf") return;
		if (root._beforeShelfMusic) root.openMusic();
		else if (root._beforeShelfPanel) root.openPanel(root._beforeShelfPanel);
		else root.closePanel();
	}
	function shelfDrop(paths, text) {
		root._shelfDragOpened = false;
		root._shelfDroppedHere = root._shelfDraggingOut;
		root.edgeArmed = false;
		scriptedPanelClose.stop();
		if (paths.length) root.shelfFilesDropped(paths);
		else if (text) root.shelfTextDropped(text);
		else return;
		if (!root.alertVisible) {
			root.openPanel("shelf");
			shelfCollapse.restart();
		}
	}
	onShelfCountChanged: if (root.shelfCount === 0 && root.panel === "shelf" && !root._shelfDragOpened)
		root.openPanel("")
	Timer {
		id: shelfCollapse
		interval: 1800
		onTriggered: if (root.panel === "shelf") root.closePanel()
	}
	property var privacy: ({ microphone: false, screen: false })
	property var agentActivity: null
	property var agentAttention: []
	signal agentReplayRequested()
	readonly property Item agentBubbleHit: agentBubble.hitEnabled ? agentBubble : null
	property real agentNow: 0
	property bool agentLightTheme: false
	readonly property bool agentBlocked: !root.ready || !root.surfaceVisible || root.startupAnimating
		|| root.suppressed || root.open || root.panel !== "" || root.alertVisible || root.pulse !== ""
	readonly property bool agentVisible: !!root.agentActivity && !root.agentBlocked
	property var deviceAlert: null
	signal deviceAlertDismissed()
	readonly property bool alertVisible: root.deviceAlert !== null && root.panel === "" && !root.open
	// Bloom peeks a hidden notch for as long as the alert shows.
	onDeviceAlertChanged: if (root.deviceAlert && root.mode === "peek") root.peek(root.deviceAlert.connected === false ? 2600 : 4200)
	signal panelRemembered(string panel)
	function openPanel(name) {
		if (root.lockPreparing || root.sessionLocked) return "locked";
		const choice = name || Panels.opening(root.lastPanel, root.defaultPanel, root.rememberPanel, root.enabledPanels);
		if (!choice) return "no enabled panels";
		if (Panels.ORDER.indexOf(choice) < 0 && choice !== "wifi" && choice !== "bluetooth" && choice !== "shelf") return "unknown panel";
		if (Panels.ORDER.indexOf(choice) >= 0 && root.enabledPanels[choice] === false
			&& !(choice === "command-center" && Panels.available(root.enabledPanels).length === 1
				&& Panels.available(root.enabledPanels)[0] === "command-center")) return "panel disabled";
		if ((choice === "wifi" || choice === "bluetooth") && root.enabledPanels["command-center"] === false) return "panel disabled";
		root.open = false;
		root.panel = choice;
		if (Panels.ORDER.indexOf(choice) >= 0 && root.rememberPanel) root.panelRemembered(choice);
		if (!root.pillHovered && !root._shelfDragOpened) scriptedPanelClose.restart();
		return "ok";
	}
	function closePanel() {
		shelfCollapse.stop();
		if (root.panel !== "") panelLinger.restart();
		root.panel = "";
		scriptedPanelClose.stop();
		return "ok";
	}
	// Bloom's panel exit: 0.1 s of fade and blur (PanelStage).
	Timer { id: panelLinger; interval: 150 }
	function cyclePanel(direction) {
		const next = Panels.cycle(root.panel, direction, root.enabledPanels);
		return next ? root.openPanel(next) : "no enabled panels";
	}
	Timer { id: scriptedPanelClose; interval: 5000; onTriggered: root.closePanel() }

	// Bloom's handleWheel. dx, dy in browser terms (positive = right, down):
	// the larger one decides; a scroll opens the notch to the panel it would
	// open, then cycles the panels; tiny moves are ignored, and it takes at
	// most one step every 250 ms.
	property real _lastWheel: 0
	function wheelStep(dx, dy) {
		const now = Date.now();
		if (now - root._lastWheel < 250) return false;
		const delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
		if (Math.abs(delta) < 5) return false;
		const dir = delta > 0 ? 1 : -1;
		const result = Panels.ORDER.indexOf(root.panel) >= 0 ? root.cyclePanel(dir) : root.openPanel("");
		if (result !== "ok") return false;
		root._lastWheel = now;
		return true;
	}

	signal togglePlay()
	signal previousTrack()
	signal nextTrack()
	signal seekTo(real ms)
	signal setVolume(real v)
	signal openMixer()
	signal layoutChosen(string layout)
	signal musicWatched(bool watched)

	property bool open: false
	property bool musicActivityVisible: false
	property bool volumeExpanded: false
	readonly property string collapsedMode: Music.collapsedMode({
		enabled: root.musicEnabled, compactNotch: root.compactNotch, timerActive: root.timer.active,
		hasMedia: root.media.hasMedia, activityVisible: root.musicActivityVisible
	})
	readonly property string bloomMode: root.panel || (root.alertVisible ? "device-alert" : root.open ? "music" : root.agentVisible ? "agent" : root.collapsedMode)
	readonly property bool musicOnHover: Music.musicOnStatusHover({
		open: root.open, hovered: root.statusHover, mode: root.bloomMode, enabled: root.musicEnabled, timerActive: root.timer.active,
		hasMedia: root.media.hasMedia, activityVisible: root.musicActivityVisible, compactNotch: root.compactNotch
	})
	// Bloom showCompactMusicIcons: the collapsed row shows music, not widgets.
	readonly property bool _musicIcons: root.panel === "" && ((root.bloomMode === "music" && !root.open) || root.musicOnHover)
	// An open panel keeps the main row's side widgets (Bloom's main row stays);
	// the panel header draws the clock with its arrows.
	readonly property bool _panelHeader: root.panel !== "" && !root.alertVisible
	// Set once the surface is on screen; starts the drop-in.
	property bool ready: false

	signal statsWanted(bool wanted)
	signal batteryHovered()

	property bool impacted: false
	property bool expanded: false
	property bool startupAnimating: false
	property bool edgeArmed: false
	property bool eventPeek: false
	property string interaction: "none"
	property real fitWidth: 0

	readonly property bool pillHovered: pillHover.hovered
	// The first-run guide shows the real Island while introducing it (Bloom
	// useOnboardingReveal); the saved mode is untouched.
	property bool guideReveal: false
	// An agent activity keeps the Island shown (Bloom isHidden: !agentAlert)
	// without counting as interaction, so the edge and clicks stay live.
	readonly property bool hidden: !root.guideReveal && !root.agentVisible && ((root.mode === "smart" && root.suppressed)
		|| Logic.isHidden(root.mode, root.overlapped, root.interaction, root.eventPeek, root.startupAnimating))
	// Bloom isHovered: the strip opens on the shown, expanded pill.
	readonly property bool statusHover: root.panel === "" && root.pillHovered && root.expanded && !root.hidden && root.surfaceVisible
	readonly property int widgetCount: root.widgets.left.length + root.widgets.right.length
	readonly property var target: Logic.geometry(
		{ ready: root.ready, visible: root.surfaceVisible, hidden: root.hidden, expanded: root.expanded, impacted: root.impacted },
		(root.panel ? Panels.size(root.panel, root.calendarRows, root.devicesHeight, root.shelfCount) : root.alertVisible ? { width: 330, height: 76 } : root.agentVisible ? { width: agentRow.desiredWidth, height: agentRow.height } : {
			width: Music.contentWidth({
				open: root.open, mode: root.bloomMode, hovered: root.statusHover, onStatusHover: root.musicOnHover,
				layout: root.layout, visualizer: root.visualizerEnabled, playing: root.media.isPlaying,
				albumArt: root.albumArtEnabled, widgetCount: root.widgetCount, fitWidth: root.fitWidth, use24h: root.use24h,
				pulse: root.pulse
			}),
			height: Music.contentHeight({
				open: root.open, mode: root.bloomMode, layout: root.layout,
				hasProgress: root.media.lengthMs > 0, volumeExpanded: root.volumeExpanded
			})
		}))

	readonly property Item hitItem: root._shelfDragOpened ? shelfDropArea : pillArea
	readonly property Item bandItem: band
	// A fullscreen app on this monitor: the top edge is the app's (Bloom drops
	// its edge input while a fullscreen window is in front).
	property bool suppressed: false
	property var visibilityDebug: ({})
	readonly property bool bandActive: root.hidden && root.mode !== "fixed" && root.surfaceVisible && !root.suppressed

	readonly property bool _statsShown: root.statusHover && ["cpu", "ram", "disk", "net"].some(w => root.widgets.left.indexOf(w) >= 0 || root.widgets.right.indexOf(w) >= 0)
	property bool _statsHeld: false

	property real _peekUntil: 0
	function peek(ms) {
		if (root.lockPreparing || root.sessionLocked) return;
		root._peekUntil = Pulses.peekUntil(Date.now(), root._peekUntil, ms);
		root.eventPeek = true;
		peekTimer.interval = Math.max(1, root._peekUntil - Date.now());
		peekTimer.restart();
	}
	function openMusic() {
		if (root.lockPreparing || root.sessionLocked || !(root.musicEnabled && root.media.hasMedia))
			return;
		root.closePanel();
		root.open = true;
		// Opened without the pointer (a script or keybind): close it again if
		// the pointer never comes to it, so it can't stay open unseen.
		if (!root.pillHovered)
			scriptedClose.restart();
	}

	Timer {
		id: scriptedClose
		interval: Tokens.music.scriptedOpenMs
		onTriggered: root.open = false
	}

	// Bloom: a session shows as the live activity, and a paused one lingers
	// 5 s before handing the pill back to the clock.
	property bool _hadMedia: false
	property bool _wasPlaying: false
	property string _lastTitle: ""

	function _updateActivity() {
		if (!(root.musicEnabled && root.media.hasMedia)) {
			activityTimer.stop();
			root.musicActivityVisible = false;
			return;
		}
		root.musicActivityVisible = true;
		if (root.media.isPlaying)
			activityTimer.stop();
		else
			activityTimer.restart();
	}

	onMediaChanged: {
		if (root.media.hasMedia !== root._hadMedia || root.media.isPlaying !== root._wasPlaying)
			root._updateActivity();
		if (root.mode === "peek" && Music.shouldPeek({ title: root._lastTitle, playing: root._wasPlaying }, { title: root.media.title, playing: root.media.isPlaying }))
			root.peek(Tokens.music.peekMs);
		root._hadMedia = root.media.hasMedia;
		root._wasPlaying = root.media.isPlaying;
		root._lastTitle = root.media.title;
	}
	onMusicEnabledChanged: root._updateActivity()
	Component.onCompleted: {
		root._updateActivity();
		root.updatesWanted(root.updateIndicator);
		// A watch that is already true at creation never changes, so announce it.
		if (root._watching) {
			root._watchHeld = true;
			root.musicWatched(true);
		}
	}

	// Leave the player when music is turned off or the player goes away.
	readonly property bool _musicAvailable: root.musicEnabled && root.media.hasMedia
	on_MusicAvailableChanged: if (!root._musicAvailable) root.open = false

	onOpenChanged: if (!root.open) root.volumeExpanded = false

	// The collapsed visualizer only counts while the notch is actually shown.
	readonly property bool _watching: root.open || (root._musicIcons && root.visualizerEnabled && root.media.isPlaying
		&& root.expanded && !root.hidden && root.surfaceVisible)
	property bool _watchHeld: false
	on_WatchingChanged: {
		root._watchHeld = root._watching;
		root.musicWatched(root._watching);
	}

	Timer {
		id: activityTimer
		interval: Tokens.music.activityLingerMs
		onTriggered: root.musicActivityVisible = false
	}

	// Pulses (Bloom App.tsx). Each kind has its own
	// timer; `pulse` is the one on screen.
	property bool _powerPulse: false
	property bool _lowPulse: false
	property bool _updatePulse: false
	readonly property string pulse: Pulses.activePulse({
		update: root._updatePulse, low: root._lowPulse, power: root._powerPulse,
		hovered: root.pillHovered, open: root.open
	})

	function _fire(kind) {
		const ms = root.pulseMs[kind];
		if (kind === "power") { root._powerPulse = true; powerTimer.interval = ms; powerTimer.restart(); }
		else if (kind === "low") { root._lowPulse = true; lowTimer.interval = ms; lowTimer.restart(); }
		else { root._updatePulse = true; updateTimer.interval = ms; updateTimer.restart(); }
		if (root.mode === "peek")
			root.peek(ms);
	}

	Timer { id: powerTimer; onTriggered: root._powerPulse = false }
	Timer { id: lowTimer; onTriggered: root._lowPulse = false }
	Timer { id: updateTimer; onTriggered: root._updatePulse = false }

	// The battery as UPower first reports it is not a change; Bloom started
	// watching once it was ready.
	property var _lastPluggedIn: null
	property bool _lowArmed: true
	function _batteryCheck() {
		const b = root.battery;
		if (!root.ready || !b.available || !b.ready)
			return;
		if (Pulses.powerPulse(root._lastPluggedIn, b.pluggedIn))
			root._fire("power");
		root._lastPluggedIn = b.pluggedIn;
		const low = Pulses.lowBatteryStep(root._lowArmed, b);
		root._lowArmed = low.armed;
		if (low.fire)
			root._fire("low");
	}
	onBatteryChanged: root._batteryCheck()

	function updatesArrived() {
		if (root.updateIndicator && root.ready)
			root._fire("update");
	}
	onUpdatesChanged: if (!root.updates.available) { root._updatePulse = false; updateTimer.stop(); }
	onUpdateIndicatorChanged: {
		root.updatesWanted(root.updateIndicator);
		if (!root.updateIndicator) { root._updatePulse = false; updateTimer.stop(); }
	}



	function stateObject() {
		return {
			mode: root.mode, hidden: root.hidden, hovered: root.statusHover, interaction: root.interaction,
			startupAnimating: root.startupAnimating, suppressed: root.suppressed,
			pillHovered: root.pillHovered, edgeArmed: root.edgeArmed, visibility: root.visibilityDebug,
			overlapped: root.overlapped, visible: root.surfaceVisible,
			sessionLocked: root.sessionLocked, lockPreparing: root.lockPreparing, userVisible: root.userVisible,
			width: root.target.width, height: root.target.height, y: root.target.y,
			bloomMode: root.bloomMode, open: root.open, panel: root.panel, panelScroll: root.panelScroll, shelfBubble: root._showShelfBubble && !root.alertVisible, musicBubble: root._showMusicBubble, agentBadge: agentBubble.shown, agentBadgeAt: agentBubble.hitEnabled ? root._fromPillCentre(agentBubble) : null, deviceAlert: root.deviceAlert,
			pulse: root.pulse, updateDot: root.updates.available && root.updateIndicator
		};
	}

	on_StatsShownChanged: {
		root._statsHeld = root._statsShown;
		root.statsWanted(root._statsShown);
	}
	Component.onDestruction: {
		if (root._statsHeld)
			root.statsWanted(false);
		if (root._watchHeld)
			root.musicWatched(false);
	}

	onReadyChanged: {
		if (!root.ready)
			return;
		root.startupAnimating = true;
		impactTimer.restart();
		startupTimer.restart();
		root._batteryCheck();
	}

	Timer {
		id: impactTimer
		interval: Tokens.notch.startup.impactDelayMs
		onTriggered: {
			root.impacted = true;
			root.expanded = true;
		}
	}

	Timer {
		id: startupTimer
		interval: Tokens.notch.startup.animatingMs
		onTriggered: root.startupAnimating = false
	}

	Timer {
		id: peekTimer
		onTriggered: root.eventPeek = false
	}

	// Bloom interactionState: active while hovered, then an 800 ms grace.
	// An open player counts too, so a hidden notch shows while it is open.
	readonly property bool _anyInteraction: !root.lockPreparing && !root.sessionLocked
		&& !(root.mode === "smart" && root.suppressed)
		&& (root._shelfDragOpened || root.pillHovered || root.edgeArmed || root.open || root.panel !== "" || root.alertVisible)
	function closeForLock() {
		root._shelfDragOpened = false;
		root._shelfDraggingOut = false;
		root.closePanel();
		root.open = false;
		root.edgeArmed = false;
		root.eventPeek = false;
		root.interaction = "none";
		graceTimer.stop();
	}
	onLockPreparingChanged: if (root.lockPreparing) root.closeForLock()
	onSessionLockedChanged: if (root.sessionLocked) root.closeForLock()
	onSuppressedChanged: if (root.suppressed && root.mode === "smart") root.closeForLock()
	onOverlappedChanged: if (root.overlapped && root.mode === "smart") root.closeForLock()
	on_AnyInteractionChanged: {
		if (root._anyInteraction) {
			graceTimer.stop();
			root.interaction = "active";
		} else if (root.interaction !== "none") {
			root.interaction = "grace";
			graceTimer.restart();
		}
	}

	Timer {
		id: graceTimer
		interval: Tokens.notch.graceMs
		onTriggered: root.interaction = "none"
	}

	onStatusHoverChanged: {
		if (!root.statusHover)
			root.fitWidth = 0;
		tooltip.hideNow();
	}

	// After an edge reveal the pill takes over once the pointer reaches it; if
	// it never does (no movement), the reveal lets go after the hand-off time.
	onBandActiveChanged: if (!root.bandActive && root.edgeArmed) handoff.restart()
	Timer { id: activityHandoff; interval: 400 }
	onPillHoveredChanged: {
		if (root.pillHovered) {
			shelfCollapse.stop();
			handoff.stop();
			scriptedClose.stop();
			scriptedPanelClose.stop();
			root.edgeArmed = false;
		} else if (!activityHandoff.running) {
			root.open = false;
			// Bloom's handleMouseLeave: a panel closes as the pointer leaves,
			// unless it's being typed into; then it closes once released.
			if (root.panel !== "" && !root.panelPinned && !root._shelfDragOpened && !root._shelfDraggingOut && !shelfCollapse.running) root.closePanel();
		}
	}
	// A panel being typed into (a Wi-Fi password) holds the notch open.
	property bool panelPinned: false
	onPanelPinnedChanged: if (!root.panelPinned && !root.pillHovered && root.panel !== "" && root.panel !== "shelf") root.closePanel()


	Timer {
		id: handoff
		interval: Tokens.notch.edgeHandoffMs
		onTriggered: root.edgeArmed = false
	}

	// Bloom's bottom corners: 28 for the calendar, else 18, on a 1000/40 spring.
	Spring {
		id: farS
		objectName: "farRadius"
		stiffness: Tokens.springs.radius.stiffness
		damping: Tokens.springs.radius.damping
		initial: Tokens.sizes.farRadius
		target: root.panel === "calendar" ? Tokens.sizes.calendarFarRadius : Tokens.sizes.farRadius
	}

	Spring {
		id: wS
		stiffness: Tokens.springs.pillWidth.stiffness
		damping: Tokens.springs.pillWidth.damping
		mass: Tokens.springs.pillWidth.mass
		initial: Tokens.notch.startup.width
		target: root.target.width
	}

	Spring {
		id: hS
		stiffness: Tokens.springs.pillHeight.stiffness
		damping: Tokens.springs.pillHeight.damping
		mass: Tokens.springs.pillHeight.mass
		initial: Tokens.notch.startup.height
		target: root.target.height
	}

	Spring {
		id: yS
		stiffness: Tokens.springs.pillY.stiffness
		damping: Tokens.springs.pillY.damping
		mass: Tokens.springs.pillY.mass
		restDelta: Tokens.springs.pillY.restDelta
		initial: Tokens.notch.startup.y
		target: root.target.y
	}

	Spring {
		id: rS
		stiffness: Tokens.springs.radius.stiffness
		damping: Tokens.springs.radius.damping
		mass: Tokens.springs.radius.mass
		initial: Tokens.sizes.farRadius
		target: root.target.edgeRadius
	}

	Item {
		id: stage
		anchors.fill: parent
		scale: root.uiScale
		transformOrigin: Item.Top

		Item {
			id: pillLayer
			anchors.fill: parent
			opacity: root.target.opacity
			Behavior on opacity {
				NumberAnimation {
					duration: Tokens.notch.opacityMs
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
				}
			}

			EdgeSurface {
				x: (stage.width - width) / 2
				y: yS.value
				edge: "top"
				pillWidth: Math.max(0, wS.value)
				pillHeight: Math.max(0, hS.value)
				edgeRadius: rS.value
				farRadius: farS.value
				flares: root.impacted
				reflective: root.edgeShine
				edgeColor: root.textColor
				color: root.statusHover || root.open || root.panel !== "" || root.alertVisible ? root.bgExpanded : root.bg
				Behavior on color {
					ColorAnimation {
						duration: Tokens.notch.colorFadeMs
						easing.type: Easing.BezierSpline
						easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
					}
				}
			}
		}

		// The pill's box: hover, input mask and content.
		Item {
			id: pillArea
			objectName: "pillArea"
			x: (stage.width - width) / 2
			y: yS.value
			width: Math.max(0, wS.value)
			height: Math.max(0, hS.value)
			opacity: pillLayer.opacity

			HoverHandler { id: pillHover }
			// Anywhere on the notch; lists and the calendar keep their own.
			WheelHandler {
				target: null
				acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
				onWheel: event => {
					const px = event.pixelDelta;
					const touch = px.x !== 0 || px.y !== 0;
					// Qt's deltas point the other way; a wheel notch is 120 units.
					root.wheelStep(touch ? -px.x : -event.angleDelta.x / 1.2, touch ? -px.y : -event.angleDelta.y / 1.2);
				}
			}
			// cursor: default — the notch body (Bloom .bloom { cursor: default })
			TapHandler {
				onTapped: if (root.panel === "" && !root.open) root.openPanel("")
			}

			Ambience {
				objectName: "ambience"
				anchors.fill: parent
				// Fades out as the player closes, and its art enters afresh on
				// the next open, as Bloom's remounted glow does.
				active: root.open && root.panel === "" && root.ambienceEnabled && root.media.artUrl !== ""
				source: active ? root.media.artUrl : ""
				bg: root.bgExpanded
				radius: Tokens.sizes.farRadius
			}

			// The pill clips the row, as Bloom's .bloom does; the row itself
			// doesn't, so the art's glow can spill into the padding.
			Item {
				anchors.fill: parent
				clip: true

				Item {
					id: mainRow
					objectName: "mainRow"
					x: Tokens.sizes.padding
					width: Math.max(0, parent.width - 2 * Tokens.sizes.padding)
					height: Tokens.sizes.mainRow
					readonly property bool showing: (root.expanded && !root.hidden && !root.open && root.panel === "" && !root.alertVisible && !root.agentVisible) || root._panelHeader
					opacity: showing ? 1 : 0
					// Input follows the state, not the fade: a fading row doesn't
					// take clicks meant for what replaces it.
					enabled: showing
					// An alert takes the pill at once (Bloom's first alert frame has
					// no clock); otherwise the row fades.
					Behavior on opacity {
						enabled: !root.alertVisible && !root.agentVisible
						NumberAnimation {
							duration: Tokens.easing.framerDefaultMs
							easing.type: Easing.BezierSpline
							easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1]
						}
					}

					Item {
						id: standardRow
						anchors.fill: parent
						opacity: pulseView.standardOpacity

						Row {
							id: leftGroup
							objectName: "statusLeft"
							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							spacing: Tokens.statusStrip.groupGap
							opacity: (root.statusHover && !root._musicIcons) || root._panelHeader ? 1 : 0
							visible: opacity > 0
							Behavior on opacity {
								NumberAnimation {
									duration: Tokens.statusStrip.fadeMs
									easing.type: Easing.BezierSpline
									easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
								}
							}
							Repeater {
								model: root.widgets.left
								delegate: widgetDelegate
							}
						}

						NotchClock {
							id: clock
							objectName: "notchClock"
							visible: !root._panelHeader
							anchors.centerIn: parent
							now: root.now
							use24h: root.use24h
							timerActive: root.timer.active
							timerSeconds: root.timer.seconds
							timerFinished: root.timer.finished
							textColor: root.textColor
							textMuted: root.textMuted
							onClicked: root.clockClicked()
						}
						Row {
							x: clock.x + (clock.width + clock.textWidth) / 2 + 5; y: 10; spacing: 3
							visible: root.privacy.microphone || root.privacy.screen
							Rectangle { objectName: "privacy-mic-dot"; visible: root.privacy.microphone; width: 5; height: 5; radius: 2.5; color: "#ff8c3a" }
							Rectangle { objectName: "privacy-screen-dot"; visible: root.privacy.screen; width: 5; height: 5; radius: 2.5; color: "#63df91" }
						}

						Row {
							id: rightGroup
							objectName: "statusRight"
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							spacing: Tokens.statusStrip.groupGap
							opacity: leftGroup.opacity
							visible: opacity > 0
							Repeater {
								model: root.widgets.right
								delegate: widgetDelegate
							}
						}

						Visualizer {
							objectName: "collapsedVisualizer"
							active: visible && !root.open && root.expanded && !root.hidden && root.surfaceVisible
							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							visible: root._musicIcons && root.visualizerEnabled
							playing: root.media.isPlaying
							levels: root.levels
							color: root.textColor
							opacity: visible ? 1 : 0
							Behavior on opacity {
								NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
							}
						}

						Item {
							id: artSlot
							objectName: "musicArt"
							readonly property bool shown: root._musicIcons && (root.albumArtEnabled || root.musicOnHover)
							readonly property real side: root.media.isPlaying ? Tokens.music.collapsedArt.size : Tokens.music.collapsedArt.pausedSize
							anchors.right: parent.right
							anchors.verticalCenter: parent.verticalCenter
							width: side
							height: side
							visible: opacity > 0
							opacity: shown ? 1 : 0
							scale: shown ? 1 : 0.8
							Behavior on width { NumberAnimation { duration: Tokens.music.collapsedArt.sizeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
							Behavior on height { NumberAnimation { duration: Tokens.music.collapsedArt.sizeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }
							Behavior on opacity { NumberAnimation { duration: Tokens.music.collapsedArt.appearMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }
							Behavior on scale { NumberAnimation { duration: Tokens.music.collapsedArt.appearMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] } }

							// Bloom .album-art { cursor: pointer }
							HoverHandler { id: artHover; cursorShape: Qt.PointingHandCursor }

							// Bloom's .album-art-glow-bg: the art itself, rounded, blurred
							// and saturated, spilling past the tile behind it. The blur
							// is cached: it only changes with the art or hover, not on
							// the frames the visualizer draws.
							FilterBlur {
								objectName: "musicArtGlow"
								readonly property var look: artHover.hovered ? Tokens.music.collapsedArt.glowHover : Tokens.music.collapsedArt.glow
								readonly property real spread: artHover.hovered ? Tokens.music.collapsedArt.glowHoverInset : Tokens.music.collapsedArt.glowInset
								x: -spread
								y: -spread
								width: artSlot.width + 2 * spread
								height: artSlot.height + 2 * spread
								visible: glowArt.status === Image.Ready
								sigma: look.blur
								maxSigma: Tokens.music.collapsedArt.glowHover.blur
								saturate: look.saturate
								brightness: look.brightness
								opacity: look.opacity
								Behavior on opacity { NumberAnimation { duration: Tokens.music.collapsedArt.glowMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1] } }

								// The art rounded to 10 px before the blur, as a shape
								// filled with it: an effect layer inside the blur's
								// source renders nothing.
								Image {
									id: glowArt
									anchors.fill: parent
									source: root.glowEnabled && root.albumArtEnabled ? root.media.artUrl : ""
									fillMode: Image.PreserveAspectCrop
									asynchronous: true
									sourceSize: Qt.size(64, 64)
								}
								// The image as laid out (cropped to the box): a shape's
								// fill maps its texture at the texture's own pixel size.
								ShaderEffectSource {
									id: glowTexture
									objectName: "musicArtGlowTexture"
									anchors.fill: parent
									sourceItem: glowArt
									hideSource: true
									visible: false
								}
								Shape {
									anchors.fill: parent
									preferredRendererType: Shape.CurveRenderer
									ShapePath {
										strokeWidth: -1
										fillItem: glowTexture
										PathRectangle { width: glowArt.width; height: glowArt.height; radius: Tokens.music.collapsedArt.glowRadius }
									}
								}
							}

							Rectangle {
								anchors.fill: parent
								radius: Tokens.music.collapsedArt.radius
								color: Qt.rgba(1, 1, 1, artHover.hovered ? 0.25 : 0.15)
							}

							AlbumArt {
								anchors.fill: parent
								source: root.albumArtEnabled ? root.media.artUrl : ""
								radius: Tokens.music.collapsedArt.radius
								flipMs: Tokens.music.collapsedArt.flipMs
							}

							TapHandler {
								acceptedButtons: Qt.LeftButton
								onTapped: root.openMusic()
							}

							TapHandler {
								acceptedButtons: Qt.RightButton
								onTapped: root.previousTrack()
							}
						}
					}

					PulseView {
						id: pulseView
						anchors.fill: parent
						kind: root.pulse
						battery: root.battery
						updateAvailable: root.updates.available && root.updateIndicator
						textColor: root.textColor
					}

					// Bloom's update dot: centred under the clock's 24 px box (top: 100%,
					// margin-top: -4px), in status and collapsed music alike.
					Rectangle {
						objectName: "update-dot"
						visible: root.updates.available && root.updateIndicator
						x: clock.x + clock.width / 2 - width / 2
						y: Tokens.pulse.dot.top
						width: Tokens.pulse.dot.size
						height: width
						radius: width / 2
						color: Tokens.status.green
						opacity: standardRow.opacity
					}
				}

				// Reveal the player inside the growing pill, like the clock row.
				Loader {
					objectName: "musicPlayerLoader"
					x: Tokens.sizes.padding
					width: Math.max(0, parent.width - 2 * Tokens.sizes.padding)
					height: parent.height
					active: root.open && root.panel === ""
					opacity: root.open ? 1 : 0
					Behavior on opacity { NumberAnimation { duration: 100 } }
					sourceComponent: root.layout === "compact" ? compactComponent : classicComponent
				}
			}
			// The pill's rounded shape, for masking a panel while the pill moves.
			Item {
				id: panelMask
				anchors.fill: parent
				visible: false
				layer.enabled: panelLoader.layer.enabled
				layer.textureSize: Render.texture(width, height)

				Rectangle {
					anchors.fill: parent
					bottomLeftRadius: farS.value
					bottomRightRadius: farS.value
					color: "black"
				}
			}
			Loader {
				id: panelLoader
				objectName: "panelLoader"
				anchors.fill: parent
				// Bloom's panels: overflow hidden with the pill's radius. Only
				// while the pill moves; a mask costs a pass at rest.
				layer.enabled: active && (!wS.settled || !hS.settled || !farS.settled)
				layer.textureSize: Render.texture(width, height)
				layer.effect: MultiEffect {
					maskEnabled: true
					maskSource: panelMask
				}
				// Stays a moment after a close so the last panel fades out.
				active: root.panel !== "" || panelLinger.running
				source: active ? "PanelHost.qml" : ""
				onLoaded: {
					item.panel = Qt.binding(() => root.panel);
					item.enabledPanels = Qt.binding(() => root.enabledPanels);
					item.textColor = Qt.binding(() => root.textColor);
					item.textMuted = Qt.binding(() => root.textMuted);
					item.use24h = Qt.binding(() => root.use24h);
					root.calendarRows = item.calendarRowCount;
					root.panelPinned = Qt.binding(() => item?.pinned ?? false);
					root.devicesHeight = Qt.binding(() => item?.devicesHeight ?? 150);
					root.panelScroll = Qt.binding(() => item?.listScroll ?? 0);
				}
			}
			AgentActivity {
				id: agentRow
				objectName: "agentActivity"
				width: parent.width
				y: Math.max(0, (parent.height - height) / 2)
				entry: root.agentVisible ? root.agentActivity : null
				now: root.agentNow
				light: root.agentLightTheme
				ink: root.textColor
				mutedInk: root.textMuted
			}
			DeviceAlert {
				id: alertSurface
				objectName: "deviceAlert"
				anchors.fill: parent
				alert: root.alertVisible ? root.deviceAlert : null
				textColor: root.textColor
				textMuted: root.textMuted
				// Bloom: a Bluetooth device opens its list; USB ones just go.
				onClicked: {
					const bluetooth = root.deviceAlert?.bluetooth;
					root.deviceAlertDismissed();
					if (bluetooth) root.openPanel("bluetooth");
				}
			}
			Connections {
				target: panelLoader.item
				ignoreUnknownSignals: true
				function onCloseRequested() { root.closePanel(); }
				function onNextRequested() { root.cyclePanel(1); }
				function onPreviousRequested() { root.cyclePanel(-1); }
				function onSubpanelRequested(name) {
					root.openPanel(name);
				}
				function onShelfDragStarted() {
					shelfCollapse.stop();
					root._shelfDraggingOut = true;
					root._shelfDroppedHere = false;
				}
				function onShelfDragFinished() {
					root._shelfDraggingOut = false;
					if (!root._shelfDroppedHere) root.closePanel();
				}
				function onCalendarRowCountChanged() { root.calendarRows = panelLoader.item?.calendarRowCount ?? 5; }
			}
		}

		// Bloom statusFitWidth: grows during a hover so a shrinking live label
		// doesn't make the notch jitter.
		readonly property real _needed: Logic.fitWidth(clock.textWidth, leftGroup.implicitWidth, rightGroup.implicitWidth)
		on_NeededChanged: if (root.statusHover && stage._needed > root.fitWidth) root.fitWidth = stage._needed

		ActivityBubble {
			id: agentBubble
			objectName: "agentAttentionBubble"
			leading: true
			shown: root._showActivities && root.agentAttention.length > 0
				&& root.agentActivity?.kind !== "attention" && !root.alertVisible
			x: pillArea.x - width - (root._showShelfBubble ? shelfBubble.width + 16 : 8)
			y: pillArea.y + 3
			color: root.statusHover ? root.bgExpanded : root.bg
			ink: "#e9b873"
			contentPadding: 8
			agent: root.agentAttention[0]?.agent ?? ""
			light: root.agentLightTheme
			label: String(root.agentAttention.length)
			description: I18n.tCount("agentActivity.attentionBadge", root.agentAttention.length)
			onActivated: root.agentReplayRequested()
		}

		ActivityBubble {
			id: shelfBubble
			objectName: "shelfBubble"
			leading: true
			shown: root._showShelfBubble && !root.alertVisible
			x: pillArea.x - width - 8
			y: pillArea.y + 3
			color: root.statusHover ? root.bgExpanded : root.bg
			ink: root.textColor
			icon: "inbox"
			label: String(root.shelfCount)
			description: I18n.tCount("linux.notch.openShelf", root.shelfCount)
			onActivated: { activityHandoff.restart(); root.openPanel("shelf"); }
		}
		ActivityBubble {
			id: musicBubble
			objectName: "musicBubble"
			shown: root._showMusicBubble
			x: pillArea.x + pillArea.width + 8
			y: pillArea.y + 3
			color: root.statusHover ? root.bgExpanded : root.bg
			ink: root.textColor
			icon: "music"
			art: root.albumArtEnabled ? root.media.artUrl || "" : ""
			description: root.media.title ? I18n.t("ui.app.openMusicValue1", { value1: root.media.title }) : I18n.t("ui.app.openMusic")
			onActivated: { activityHandoff.restart(); root.openMusic(); }
		}
		DropArea {
			id: shelfDropArea
			// Keep one target across the morph so Qt retains the drag session.
			x: root.bandActive ? band.x : Math.min(pillArea.x, root._shelfDragOpened ? band.x : pillArea.x)
			y: root.bandActive || root._shelfDragOpened ? 0 : pillArea.y
			width: root.bandActive ? band.width : Math.max(pillArea.width, root._shelfDragOpened ? band.width : 0)
			height: root.bandActive ? band.height : Math.max(pillArea.height, root._shelfDragOpened ? band.height : 0)
			enabled: root.surfaceVisible && (!root.hidden || root.bandActive) && !root.suppressed
			function paths(event) {
				return (event.urls || []).map(url => Shelf.filePath(url.toString())).filter(Boolean);
			}
			onEntered: event => {
				// Wayland delivers MIME bytes only when dropped.
				if ((!event.hasUrls && !event.hasText) || !(event.supportedActions & Qt.CopyAction))
					event.accepted = false;
				else {
					event.accept(Qt.CopyAction);
					// Qt must finish accepting the enter before the panel changes the input region.
					Qt.callLater(() => { if (shelfDropArea.containsDrag) root.shelfDragEnter(); });
				}
			}
			onExited: root.shelfDragLeave()
			onDropped: event => {
				const files = paths(event);
				const snippet = event.hasUrls ? "" : event.text;
				if (files.length || snippet) root.shelfDrop(files, snippet);
				else root.shelfDragLeave();
				// The shelf stores a reference; it never moves the source file.
				if ((files.length || snippet) && (event.supportedActions & Qt.CopyAction))
					event.accept(Qt.CopyAction);
			}
		}

		StatusTooltip {
			id: tooltip
			bg: root.bgExpanded
			textColor: root.textColor
			pillBottom: yS.value + hS.value
		}

		// Edge reveal band (Wayland stand-in for Bloom's top-edge hook).
		Item {
			id: band
			x: (stage.width - width) / 2
			y: 0
			width: Tokens.notch.edgeBand.width
			height: Tokens.notch.edgeBand.height
			enabled: root.bandActive

			HoverHandler {
				id: bandHover
				onHoveredChanged: {
					if (bandHover.hovered) {
						if (root.edgeDelay <= 0)
							root.edgeArmed = true;
						else
							dwell.restart();
					} else if (root.bandActive) {
						// A real leave while hidden. Once the notch shows, the band
						// switches off under the pointer, and that is not a leave.
						dwell.stop();
						root.edgeArmed = false;
					}
				}
			}

			Timer {
				id: dwell
				interval: Math.max(1, root.edgeDelay)
				onTriggered: root.edgeArmed = true
			}
		}
	}

	Component {
		id: classicComponent
		ClassicPlayer {
			hairline: 1 / root.uiScale
			media: root.media
			positionMs: root.positionMs
			levels: root.levels
			visualizer: root.visualizerEnabled
			volume: root.volume
			muted: root.muted
			mixerAvailable: root.mixerAvailable
			textColor: root.textColor
			textMuted: root.textMuted
			onTogglePlay: root.togglePlay()
			onPreviousTrack: root.previousTrack()
			onNextTrack: root.nextTrack()
			onSetVolume: v => root.setVolume(v)
			onOpenMixer: root.openMixer()
			onSwitchLayout: root.layoutChosen("compact")
		}
	}

	Component {
		id: compactComponent
		CompactPlayer {
			media: root.media
			positionMs: root.positionMs
			levels: root.levels
			visualizer: root.visualizerEnabled
			volume: root.volume
			muted: root.muted
			mixerAvailable: root.mixerAvailable
			textColor: root.textColor
			textMuted: root.textMuted
			volumeExpanded: root.volumeExpanded
			onVolumeExpandedChanged: root.volumeExpanded = volumeExpanded
			onTogglePlay: root.togglePlay()
			onPreviousTrack: root.previousTrack()
			onNextTrack: root.nextTrack()
			onSeekTo: ms => root.seekTo(ms)
			onSetVolume: v => root.setVolume(v)
			onOpenMixer: root.openMixer()
			onSwitchLayout: root.layoutChosen("classic")
		}
	}

	Component {
		id: widgetDelegate

		// Only widgets with data exist at all, so a missing battery leaves no
		// gap in the row (Bloom renders nothing for it).
		Loader {
			id: slot
			required property string modelData
			readonly property bool hasData: (slot.modelData === "weather" && root.weather.shown)
				|| (slot.modelData === "battery" && root.battery.available)
				|| ["cpu", "ram", "disk", "net"].indexOf(slot.modelData) >= 0
			active: slot.hasData
			visible: slot.active

			sourceComponent: StatusWidget {
				id: w
				widgetId: slot.modelData
				textColor: root.textColor
				battery: root.battery
				icon: {
					switch (slot.modelData) {
					case "weather": return root.weather.icon;
					case "cpu": return "cpu";
					case "ram": return "memory-stick";
					case "disk": return "hard-drive";
					case "net": return "arrow-up-down";
					}
					return "";
				}
				strokeWidth: slot.modelData === "weather" ? 2.2 : 2
				label: {
					switch (slot.modelData) {
					case "weather": return root.weather.label;
					case "battery": return `${root.battery.level}%`;
					case "cpu": return `${root.stats.cpu}%`;
					case "ram": return `${Math.round(root.stats.ram)}%`;
					case "disk": return `${root.stats.disk}GB`;
					case "net": return `↑${Stats.formatBytes(root.stats.up)} ↓${Stats.formatBytes(root.stats.down)}`;
					}
					return "";
				}
				readonly property string tip: {
					switch (slot.modelData) {
					case "weather": return root.weather.tooltip;
					case "battery": return root.battery.tooltip;
					case "cpu": return "CPU Usage";
					case "ram": return "RAM Usage";
					case "disk": return "Free Disk Space";
					case "net": return "Network Speed";
					}
					return "";
				}
				onHoveredChanged: {
					if (w.hovered) {
						if (slot.modelData === "battery")
							root.batteryHovered();
						tooltip.text = w.tip;
						tooltip.showFor(w);
					} else {
						tooltip.hideNow();
					}
				}
			}
		}
	}
}
