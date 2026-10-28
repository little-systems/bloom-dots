import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../services/stats.js" as Stats
import "notch.js" as Logic
import "music.js" as Music
import "pulses.js" as Pulses
import "panels.js" as Panels

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
	property color bg: Qt.rgba(0, 0, 0, 0.8)
	property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
	property color textColor: "white"
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
	property int notificationUnread: 0
	signal notificationHistoryRequested()
	property string panel: ""
	property string defaultPanel: "calendar"
	property string lastPanel: "calendar"
	property bool rememberPanel: true
	property var enabledPanels: ({ calendar: true, "command-center": true, devices: true })
	property int calendarRows: 5
	property int deviceCount: 0
	property var privacy: ({ microphone: false, screen: false })
	property var deviceAlert: null
	readonly property bool alertVisible: root.deviceAlert !== null && root.panel === "" && !root.open
	onDeviceAlertChanged: if (root.deviceAlert && root.mode === "peek") root.peek(4300)
	signal panelRemembered(string panel)
	function openPanel(name) {
		const choice = name || Panels.opening(root.lastPanel, root.defaultPanel, root.rememberPanel, root.enabledPanels);
		if (!choice) return "no enabled panels";
		if (Panels.ORDER.indexOf(choice) < 0 && choice !== "wifi" && choice !== "bluetooth" && choice !== "shelf") return "unknown panel";
		if (Panels.ORDER.indexOf(choice) >= 0 && root.enabledPanels[choice] === false) return "panel disabled";
		if ((choice === "wifi" || choice === "bluetooth") && root.enabledPanels["command-center"] === false) return "panel disabled";
		root.open = false;
		root.panel = choice;
		if (Panels.ORDER.indexOf(choice) >= 0 && root.rememberPanel) root.panelRemembered(choice);
		if (!root.pillHovered) scriptedPanelClose.restart();
		return "ok";
	}
	function closePanel() { root.panel = ""; scriptedPanelClose.stop(); return "ok"; }
	function cyclePanel(direction) {
		const next = Panels.cycle(root.panel, direction, root.enabledPanels);
		return next ? root.openPanel(next) : "no enabled panels";
	}
	Timer { id: scriptedPanelClose; interval: 5000; onTriggered: root.closePanel() }

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
		enabled: root.musicEnabled, compactNotch: root.compactNotch,
		hasMedia: root.media.hasMedia, activityVisible: root.musicActivityVisible
	})
	readonly property string bloomMode: root.panel || (root.alertVisible ? "device-alert" : root.open ? "music" : root.collapsedMode)
	readonly property bool musicOnHover: Music.musicOnStatusHover({
		open: root.open, hovered: root.statusHover, mode: root.bloomMode, enabled: root.musicEnabled,
		hasMedia: root.media.hasMedia, activityVisible: root.musicActivityVisible, compactNotch: root.compactNotch
	})
	// Bloom showCompactMusicIcons: the collapsed row shows music, not widgets.
	readonly property bool _musicIcons: (root.bloomMode === "music" && !root.open) || root.musicOnHover
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
	readonly property bool hidden: Logic.isHidden(root.mode, root.overlapped, root.interaction, root.eventPeek, root.startupAnimating)
	// Bloom isHovered: the strip opens on the shown, expanded pill.
	readonly property bool statusHover: root.panel === "" && root.pillHovered && root.expanded && !root.hidden && root.userVisible
	readonly property int widgetCount: root.widgets.left.length + root.widgets.right.length
	readonly property var target: Logic.geometry(
		{ ready: root.ready, visible: root.userVisible, hidden: root.hidden, expanded: root.expanded, impacted: root.impacted },
		(root.panel ? Panels.size(root.panel, root.calendarRows, root.deviceCount) : root.alertVisible ? { width: 330, height: 76 } : {
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

	readonly property Item hitItem: pillArea
	readonly property Item bandItem: band
	// A fullscreen app on this monitor: the top edge is the app's (Bloom drops
	// its edge input while a fullscreen window is in front).
	property bool suppressed: false
	readonly property bool bandActive: root.hidden && root.mode !== "fixed" && root.userVisible && !root.suppressed

	readonly property bool _statsShown: root.statusHover && ["cpu", "ram", "disk", "net"].some(w => root.widgets.left.indexOf(w) >= 0 || root.widgets.right.indexOf(w) >= 0)
	property bool _statsHeld: false

	property real _peekUntil: 0
	function peek(ms) {
		root._peekUntil = Pulses.peekUntil(Date.now(), root._peekUntil, ms);
		root.eventPeek = true;
		peekTimer.interval = Math.max(1, root._peekUntil - Date.now());
		peekTimer.restart();
	}
	function openMusic() {
		if (!(root.musicEnabled && root.media.hasMedia))
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
		&& root.expanded && !root.hidden && root.userVisible)
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
			overlapped: root.overlapped, visible: root.userVisible,
			width: root.target.width, height: root.target.height, y: root.target.y,
			bloomMode: root.bloomMode, open: root.open, panel: root.panel,
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
	readonly property bool _anyInteraction: root.pillHovered || root.edgeArmed || root.open || root.panel !== "" || root.alertVisible
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
	onPillHoveredChanged: {
		if (root.pillHovered) {
			handoff.stop();
			scriptedClose.stop();
			scriptedPanelClose.stop();
			root.edgeArmed = false;
		} else {
			root.open = false;
			if (root.panel !== "") scriptedPanelClose.restart();
		}
	}


	Timer {
		id: handoff
		interval: Tokens.notch.edgeHandoffMs
		onTriggered: root.edgeArmed = false
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
				farRadius: Tokens.sizes.farRadius
				flares: root.impacted
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
			x: (stage.width - width) / 2
			y: yS.value
			width: Math.max(0, wS.value)
			height: Math.max(0, hS.value)
			opacity: pillLayer.opacity

			HoverHandler { id: pillHover }

			Ambience {
				anchors.fill: parent
				visible: root.open && root.panel === "" && root.ambienceEnabled && root.media.artUrl !== ""
				source: visible ? root.media.artUrl : ""
				bg: root.bgExpanded
				radius: Tokens.sizes.farRadius
			}

			Item {
				id: mainRow
				x: Tokens.sizes.padding
				width: Math.max(0, parent.width - 2 * Tokens.sizes.padding)
				height: Tokens.sizes.mainRow
				clip: true
				opacity: root.expanded && !root.hidden && !root.open && root.panel === "" && !root.alertVisible ? 1 : 0
				Behavior on opacity {
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
						anchors.left: parent.left
						anchors.verticalCenter: parent.verticalCenter
						spacing: Tokens.statusStrip.groupGap
						opacity: root.statusHover && !root._musicIcons ? 1 : 0
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

					Text {
						id: clock
						anchors.centerIn: parent
						text: Logic.clockText(root.now, root.use24h)
						color: clockHover.hovered ? root.textMuted : root.textColor
						Behavior on color { ColorAnimation { duration: 200 } }
						font.family: Tokens.type.family
						font.pixelSize: Tokens.type.clock.size
						font.weight: Font.Medium
						font.letterSpacing: Tokens.type.clock.tracking
						scale: clockTap.pressed ? 0.95 : 1
						Behavior on scale { NumberAnimation { duration: 100 } }
						HoverHandler { id: clockHover }
						TapHandler { id: clockTap; onTapped: root.openPanel("") }
					}
					Row {
						x: clock.x + clock.width + 5; y: 10; spacing: 3
						visible: root.privacy.microphone || root.privacy.screen
						Rectangle { visible: root.privacy.microphone; width: 5; height: 5; radius: 2.5; color: "#ff8c3a" }
						Rectangle { visible: root.privacy.screen; width: 5; height: 5; radius: 2.5; color: "#63df91" }
					}

					Row {
						id: rightGroup
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
						active: visible && !root.open && root.expanded && !root.hidden && root.userVisible
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

						HoverHandler { id: artHover }

						// Bloom's glow: the art itself, blurred and saturated, behind the button.
						Image {
							id: glowSource
							readonly property real inset: artHover.hovered ? Tokens.music.collapsedArt.glowHoverInset : Tokens.music.collapsedArt.glowInset
							x: -inset
							y: -inset
							width: artSlot.width + 2 * inset
							height: artSlot.height + 2 * inset
							source: root.glowEnabled && root.albumArtEnabled ? root.media.artUrl : ""
							fillMode: Image.PreserveAspectCrop
							asynchronous: true
							visible: false
						}

						// Cached as a texture: the blur only changes with the art or hover,
						// but would otherwise be re-run on every frame the visualizer
						// draws (about 7 % of a core, measured 2026-10-25).
						Item {
							anchors.fill: glowSource
							visible: glowSource.status === Image.Ready
							opacity: artHover.hovered ? 0.7 : 0.6
							Behavior on opacity { NumberAnimation { duration: 400 } }
							layer.enabled: true

							MultiEffect {
								anchors.fill: parent
								source: glowSource
								blurEnabled: true
								blurMax: 16
								blur: (artHover.hovered ? 8 : 6) / 16
								saturation: 1
								brightness: artHover.hovered ? -0.1 : -0.2
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

			Loader {
				x: Tokens.sizes.padding
				width: Math.max(0, parent.width - 2 * Tokens.sizes.padding)
				height: parent.height
				active: root.open && root.panel === ""
				opacity: root.open ? 1 : 0
				Behavior on opacity { NumberAnimation { duration: 100 } }
				sourceComponent: root.layout === "compact" ? compactComponent : classicComponent
			}
			Loader {
				id: panelLoader
				anchors.fill: parent
				active: root.panel !== ""
				source: active ? "PanelHost.qml" : ""
				onLoaded: {
					item.panel = Qt.binding(() => root.panel);
					item.enabledPanels = Qt.binding(() => root.enabledPanels);
					item.textColor = Qt.binding(() => root.textColor);
					item.textMuted = Qt.binding(() => root.textMuted);
					root.calendarRows = item.calendarRowCount;
				}
			}
			Item {
				anchors.fill: parent; visible: root.alertVisible
				SvgIcon { x: 15; anchors.verticalCenter: parent.verticalCenter; name: root.deviceAlert?.kind === "bluetooth" ? "bluetooth" : root.deviceAlert?.kind === "usb" ? "usb" : "volume-2"; color: root.textColor; size: 20 }
				Column { x: 47; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 62; spacing: 3
					Text { width: parent.width; text: root.deviceAlert?.title ?? ""; color: root.textColor; font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
					Text { width: parent.width; text: root.deviceAlert?.detail ?? ""; color: root.textMuted; font.family: "Inter"; font.pixelSize: 10; elide: Text.ElideRight }
				}
			}
			Connections {
				target: panelLoader.item
				ignoreUnknownSignals: true
				function onCloseRequested() { root.closePanel(); }
				function onNextRequested() { root.cyclePanel(1); }
				function onPreviousRequested() { root.cyclePanel(-1); }
				function onSubpanelRequested(name) { root.openPanel(name); }
				function onCalendarRowCountChanged() { root.calendarRows = panelLoader.item?.calendarRowCount ?? 5; }
			}
			Rectangle {
				objectName: "notification-unread"
				visible: root.notificationUnread > 0 && root.expanded && !root.hidden && !root.open
				width: 16; height: 16; radius: 8
				x: pillArea.width - width - 2; y: 2
				color: Tokens.status.green
				Text { anchors.centerIn: parent; text: root.notificationUnread > 9 ? "9+" : root.notificationUnread; color: "black"; font.pixelSize: 9; font.bold: true }
				MouseArea { anchors.fill: parent; onClicked: root.notificationHistoryRequested() }
			}
		}

		// Bloom statusFitWidth: grows during a hover so a shrinking live label
		// doesn't make the notch jitter.
		readonly property real _needed: Logic.fitWidth(clock.implicitWidth, leftGroup.implicitWidth, rightGroup.implicitWidth)
		on_NeededChanged: if (root.statusHover && stage._needed > root.fitWidth) root.fitWidth = stage._needed

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
