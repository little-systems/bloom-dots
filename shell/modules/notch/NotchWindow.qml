import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/tokens.js" as Tokens
import "notch.js" as Logic
import "panels.js" as Panels
import "calendar.js" as CalendarLogic

// One notch per screen: a fixed-size top layer surface (it never resizes,
// spec §3.3) whose input mask is the pill, or the edge band while hidden.
// Feeds NotchView from the services and computes smart-mode overlap.
PanelWindow {
	id: win

	required property var modelData
	property bool sessionLocked: false
	property bool lockPreparing: false
	readonly property alias view: view
	readonly property string _key: "notch-" + win.modelData.name

	screen: win.modelData
	anchors.top: true
	// Fixed mode claims only the collapsed top strip for app windows. The
	// surface stays large enough for expanded panels without reserving them.
	exclusiveZone: !win.sessionLocked && view.mode === "fixed" && view.userVisible ? Math.round(Tokens.notch.reserve * view.uiScale) : 0
	visible: !win.sessionLocked
	implicitWidth: Tokens.notch.surface.width
	implicitHeight: Tokens.notch.surface.height
	color: "transparent"
	WlrLayershell.namespace: "bloom:notch"
	// Overlay keeps the narrow input region above full-width Top-layer bars
	// (ii's bar takes pointer input over the notch otherwise). Overlay also
	// draws over fullscreen windows, so while one is in front the notch drops
	// to Top, which Hyprland keeps under fullscreen windows.
	WlrLayershell.layer: win._fullscreen ? WlrLayer.Top : WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Panels.wantsKeyboard(view.panel) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	mask: Region {
		item: view.bandActive ? view.bandItem : (view.hidden ? null : view.hitItem)
	}

	readonly property var _monitor: HyprState.monitors.find(m => m.name === win.modelData.name) ?? null
	readonly property bool _overlapped: view.mode === "smart" && win._monitor !== null
		&& Logic.workspaceOverlaps(HyprState.clients, win._monitor,
			Logic.notchRect(win._monitor, Logic.statusWidth(false, view.widgetCount, 0, view.use24h), view.uiScale))

	// A new desktop focus cancels an old edge/hover reveal. Layer-surface
	// focus (typing into a notch panel) does not change this application key.
	readonly property string _focusContext: {
		if (!win._monitor) return "";
		const focused = HyprState.clients.find(c => c.mapped && !c.hidden && c.monitor === win._monitor.id
			&& c.workspace && c.workspace.id === win._monitor.activeWorkspace.id && c.focusHistoryID === 0);
		return win._monitor.activeWorkspace.id + ":" + (focused?.address || "");
	}
	on_FocusContextChanged: if (view.mode === "smart" && win._overlapped) view.closeForLock()

	readonly property bool _fullscreen: win._monitor !== null && Logic.fullscreenOn(HyprState.clients, win._monitor)

	// Smart mode needs window positions every second (moving a floating window
	// sends no event); otherwise Hyprland's events are enough to follow fullscreen.
	readonly property string _hyprNeed: view.mode === "smart" ? "poll" : "events"
	on_HyprNeedChanged: HyprState.hold(win._key, win._hyprNeed)
	Component.onCompleted: {
		HyprState.hold(win._key, win._hyprNeed);
		Devices.hold(win._key, true);
		readyTimer.start();
	}
	Component.onDestruction: {
		HyprState.hold(win._key, "");
		SystemStats.hold(win._key, false);
		music.item?.hold(win._key, false, false);
		Updates.hold(win._key, false);
		Devices.hold(win._key, false);
	}

	// Let the surface map before the drop-in starts.
	Timer {
		id: readyTimer
		interval: 50
		onTriggered: view.ready = true
	}

	Timer {
		interval: 1000
		repeat: true
		running: true
		onTriggered: view.now = new Date()
	}

	readonly property bool _musicOn: Settings.values["bloom-music-mode-enabled"]

	Loader {
		id: music
		active: win._musicOn
		source: "MusicData.qml"
	}

	Loader {
		id: audio
		active: view.open
		source: "AudioData.qml"
	}

	Connections {
		target: Updates
		function onArrived() { view.updatesArrived(); }
	}

	NotchView {
		id: view
		anchors.fill: parent
		onDeviceAlertDismissed: Devices.dismissAlert()
		timer: ({
			// Bloom: timerSeconds > 0 (running or paused) || isTimerFinished.
			active: CalendarState.running || CalendarState.pausedSec > 0 || CalendarState.finished,
			seconds: CalendarLogic.remaining(CalendarState.deadlineMs, CalendarState.pausedSec, view.now.getTime()),
			finished: CalendarState.finished
		})
		onTimerResetRequested: CalendarState.reset()
		mode: Settings.values["bloom-notch-mode"]
		sessionLocked: win.sessionLocked
		lockPreparing: win.lockPreparing
		defaultPanel: Settings.values["bloom-notch-default-panel"]
		lastPanel: PanelState.lastPanel
		rememberPanel: Settings.values["bloom-notch-panel-memory"]
		shelfCount: ShelfState.items.length
		privacy: Devices.privacy
		deviceAlert: Devices.alert
		enabledPanels: ({ calendar: Settings.values["bloom-calendar-enabled"], "command-center": Settings.values["bloom-notch-command-center-enabled"], devices: Settings.values["bloom-notch-devices-enabled"] })
		onPanelRemembered: panel => PanelState.remember(panel)
		edgeDelay: Settings.values["bloom-notch-edge-delay"]
		widgets: Settings.values["bloom-status-widgets"]
		use24h: Settings.values["bloom-time-format-24h"]
		uiScale: Settings.values["bloom-scale"]
		overlapped: win._overlapped
		suppressed: win._fullscreen
		bg: Theme.bg
		bgExpanded: Theme.bgExpanded
		textColor: Theme.text
		textMuted: Theme.textMuted
		weather: ({ shown: Weather.shown, label: Weather.label, icon: Weather.icon, tooltip: Weather.tooltip })
		battery: ({ available: Battery.available, ready: Battery.ready, level: Battery.level, charging: Battery.charging, pluggedIn: Battery.pluggedIn, threshold: Battery.threshold, tooltip: Battery.tooltip })
		stats: ({ cpu: SystemStats.cpu, ram: SystemStats.ram, disk: SystemStats.disk, up: SystemStats.up, down: SystemStats.down })
		onStatsWanted: wanted => SystemStats.hold(win._key, wanted)
		musicEnabled: win._musicOn
		compactNotch: Settings.values["bloom-music-compact-notch"]
		visualizerEnabled: Settings.values["bloom-media-visualizer-enabled"] && (music.item?.visualizerAvailable ?? false)
		albumArtEnabled: Settings.values["bloom-media-album-art-enabled"]
		ambienceEnabled: Settings.values["bloom-media-ambience-enabled"] && !Performance.lowPower
		glowEnabled: Settings.values["bloom-media-compact-glow-enabled"] && !Performance.lowPower
		layout: Settings.values["bloom-media-layout"]
		media: music.item?.media ?? ({ hasMedia: false, isPlaying: false, title: "", artist: "", artUrl: "", lengthMs: 0, canSeek: false })
		positionMs: music.item?.positionMs ?? 0
		levels: music.item?.levels ?? [0.18, 0.18, 0.18, 0.18, 0.18]
		volume: audio.item?.volume ?? 0
		muted: audio.item?.muted ?? false
		mixerAvailable: audio.item?.mixerAvailable ?? false
		onTogglePlay: music.item?.togglePlay()
		onPreviousTrack: music.item?.previousTrack()
		onNextTrack: music.item?.nextTrack()
		onSeekTo: ms => music.item?.seekTo(ms)
		onSetVolume: v => audio.item?.setVolume(v)
		onOpenMixer: audio.item?.openMixer()
		onLayoutChosen: layout => Settings.set("bloom-media-layout", layout)
		onMusicWatched: watched => music.item?.hold(win._key, watched, view.visualizerEnabled)
		updates: ({ available: Updates.available, count: Updates.count })
		updateIndicator: Settings.values["bloom-show-update-indicator"]
		onUpdatesWanted: wanted => Updates.hold(win._key, wanted)
	}
}
