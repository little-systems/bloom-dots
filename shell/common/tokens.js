// Bloom design tokens (spec Appendix A, from Bloom App.tsx / App.css /
// theme.ts / EdgeSurface @ b5fb962). Plain JS: imported by QML and readable
// by Node tools.

// framer-motion spring parameters.
var springs = {
	pillWidth: { stiffness: 400, damping: 31, mass: 1 },
	pillHeight: { stiffness: 450, damping: 29, mass: 1 },
	pillY: { stiffness: 550, damping: 45, mass: 0.8, restDelta: 0.001 },
	radius: { stiffness: 1000, damping: 40, mass: 1 },
	standard: { stiffness: 500, damping: 30, mass: 1 },
	flip: { stiffness: 600, damping: 30, mass: 1 },
	visualizerBar: { stiffness: 600, damping: 30, mass: 0.5 },
	press: { stiffness: 400, damping: 25, mass: 1 },
	// Dock (Bloom Dock.tsx).
	dockY: { stiffness: 400, damping: 35, mass: 0.8 },
	dockSize: { stiffness: 250, damping: 22, mass: 0.8 },
	dockLayout: { stiffness: 300, damping: 25, mass: 1 },
	dockRadius: { stiffness: 500, damping: 30, mass: 1 },
	itemEntry: { stiffness: 400, damping: 25, mass: 1 },
	// framer's defaults for a hover variant: y underdamped, scale critically damped.
	hoverY: { stiffness: 500, damping: 25, mass: 1, restSpeed: 10 },
	hoverScale: { stiffness: 550, damping: 30, mass: 1, restSpeed: 10 },
	// Add App card (Dock.tsx AddAppPopup).
	popupScale: { stiffness: 300, damping: 28, mass: 0.9 }
};

// Notch geometry in px.
var sizes = {
	collapsed: { width: 140, height: 36 },
	clock24hTrim: 16,
	musicVisualizer: 30,
	musicArt: 30,
	statusHoverBase: 200,
	statusHoverPerWidget: 50,
	statusHoverMax: 380,
	musicClassic: { width: 340, height: 120 },
	edgeRadius: 0,
	farRadius: 18,
	calendarFarRadius: 28,
	padding: 12,
	mainRow: 36
};

// EdgeSurface: concave flares bridging a pill to its screen edge.
var edge = {
	flareSize: 13,
	// Cubic handle length; a circle would use 7.2, longer eases into both edges.
	flareHandle: 10,
	flareFadeMs: 300
};

var type = {
	// The family comes from common/render Fonts (familyFor(weight)).
	clock: { size: 13, weight: 500, tracking: 0.3 },
	widgetLabel: { size: 11, weight: 500, opacity: 0.85 },
	title: { size: 14.5, weight: 600, tracking: -0.15 },
	artist: { size: 12, weight: 400 }
};

var status = {
	green: "#32D74B",
	red: "#FF453A"
};

// framer-motion easings. A transition giving only a duration uses easeOut; a
// value Bloom animates with no transition gets framer's default 0.3 s curve.
var easing = {
	framerEaseOut: [0, 0, 0.58, 1],
	framerDefault: [0.25, 0.1, 0.35, 1],
	framerDefaultMs: 300,
	cssEase: [0.25, 0.1, 0.25, 1]
};

// Notch behaviour (Bloom App.tsx).
var notch = {
	// Fixed layer surface: room for the widest panel (480) at the largest scale
	// (1.3) with flares and tooltips. The surface never resizes (spec §3.3).
	surface: { width: 1000, height: 480 },
	reserve: 40,
	hidden: { width: 39.1, height: 28.9, y: -100 },
	invisibleY: -150,
	startup: { width: 30.6, height: 44.2, y: 250, readySize: 34, impactDelayMs: 240, animatingMs: 1500 },
	opacityMs: 200,
	colorFadeMs: 300,
	graceMs: 800,
	// Wayland can only sense the pointer where the surface takes input, so the
	// reveal band is a thin strip over the notch rather than Bloom's full edge.
	edgeBand: { width: 400, height: 2 },
	// Wayland reports hover only after the pointer moves, so a reveal from the
	// band lets go this long after the band switches off if the pointer never
	// reaches the pill; the normal grace then runs.
	edgeHandoffMs: 1000,
	overlapInset: 4
};

var statusStrip = {
	itemGap: 5,
	groupGap: 10,
	iconSize: 12,
	labelSize: 11,
	labelOpacity: 0.85,
	fadeMs: 200,
	tooltip: { delayMs: 400, gap: 8, fadeMs: 150, slide: 4, paddingV: 8, paddingH: 11, radius: 11, size: 11, lineHeight: 1.5 }
};


// Music mode (Bloom App.tsx, App.css, CompactMediaPlayer.tsx @ b5fb962).
var music = {
	activityLingerMs: 5000,
	// A player opened by script or keybind closes if the pointer never reaches it.
	scriptedOpenMs: 4000,
	peekMs: 3000,
	flipCurve: [0.42, 0, 0.58, 1], // framer easeInOut
	flipMs: 300,
	collapsedArt: { size: 24, pausedSize: 20, radius: 6, sizeMs: 200, flipMs: 250, appearMs: 120, glowInset: 4, glowHoverInset: 6, glowRadius: 10,
		glow: { blur: 6, saturate: 2.5, brightness: 0.8, opacity: 0.6 }, glowHover: { blur: 8, saturate: 3, brightness: 0.9, opacity: 0.7 }, glowMs: 400 },
	visualizer: { bars: 5, barWidth: 3, gap: 2.5, height: 20, idleLevel: 0.18 },
	classic: { art: 96, artRadius: 12, gap: 22, columnGap: 5, controlsGap: 24, buttonPadding: 8, playBox: 44, playIcon: 26, skipWidth: 32, skipHeight: 16, volumeRow: 12, track: 5, vizHeight: 18 },
	compact: { padding: 3, art: 50, artRadius: 10, infoGap: 8, infoBelow: 6, progressGap: 6, progressPad: 3, controlsAbove: 8, sideIcon: 22, skipBox: 32, skipIcon: 30, playBox: 44, playIcon: 26, mainGap: 4, buttonPadding: 5, bar: 3, barHover: 6, volumeTrack: 4, volumeTrackHover: 5, time: 11, timeWidth: 30, vizHeight: 16, volumeHeight: 36 },
	marquee: { speed: 30, minSeconds: 5, fade: 8 },
	slide: { distance: 30, ms: 180, curve: [0.4, 0, 0.2, 1] },
	ambience: { blur: 52, scale: 1.8, saturate: 3.5, contrast: 1.1, brightness: 1.4, opacity: 1, enterScale: 1.1, artMs: 300, fadeMs: 150 }
};

// Pulses (Bloom App.tsx/App.css @ b5fb962).
var pulse = {
	width: 200,
	gap: 10,
	labelSize: 13,
	powerMs: 4000,
	lowBatteryMs: 5000,
	updateMs: 6000,
	enterScale: 0.95,
	exitScale: 1.05,
	blur: 4,
	blurMax: 8,
	fadeMs: 300,
	arrow: { box: 18, glyph: 10, stroke: 3 },
	dot: { size: 5, top: 26 }
};

// pacman updates (spec §5.1): hourly while held; a stalled check ends at 2 min.
var updates = { firstCheckMs: 60000, intervalMs: 3600000, timeoutMs: 120000 };

// Dock (Bloom Dock.tsx/Dock.css @ b5fb962).
var dock = {
	// Room for the Add App card over the dock at the largest bloom-scale
	// (1.3 × (52 − 14 + 440) = 622), and 3C previews.
	surfaceHeight: 640,
	collapsed: 34,
	height: 52,
	padding: 8,
	iconBox: 36,
	iconImage: 28,
	iconOnlyImage: 32,
	iconRadius: 12,
	divider: { width: 1, height: 26, margin: 2, alpha: 0.24 },
	startup: { impactMs: 280, expandMs: 350, animatingMs: 1500 },
	reserve: 56,
	graceMs: 800,
	edgeBand: { height: 2 },
	edgeHandoffMs: 1000,
	opacityMs: 200,
	contentFadeMs: 150,
	entry: { delayMs: 150, fadeMs: 150 },
	exitMs: 450,
	// A running app's exit: a 120 ms tween, no delay (Dock.tsx unpinned items).
	quickExitMs: 120,
	quickExitHoldMs: 150,
	hover: { y: -5, scale: 1.1 },
	tapScale: 0.95,
	dot: { size: 4, gap: 3, offset: 4, glow: 4, glowLight: 3 },
	tooltip: { offset: 36, paddingV: 4, paddingH: 10, radius: 6, size: 12, alpha: 0.7, slide: 4, from: 0.95, fadeMs: 200 },
	fallback: { size: 16, opacity: 0.7 },
	// Context menu (Dock.css .context-menu).
	menu: {
		radius: 12, padding: 6, minWidth: 160, submenuMinWidth: 140, margin: 8,
		item: { paddingV: 8, paddingH: 12, size: 13, radius: 6 },
		divider: { marginV: 4, marginH: 8 },
		arrow: { size: 8, opacity: 0.5, gap: 10 },
		hover: "#3b82f6", dangerHover: "#ef4444",
		shadow: { y: 10, blur: 30, alpha: 0.5 }, shadowLight: { y: 8, blur: 32, alpha: 0.08 },
		fadeMs: 200
	},
	// Add App card (Dock.css .add-app-popup).
	popup: {
		width: 360, height: 440, radius: 18, tuck: 14,
		shadow: { y: -12, blur: 40, alpha: 0.4 },
		search: { margin: 10, marginBottom: 4, paddingV: 10, paddingH: 12, radius: 12, gap: 10, icon: 14, size: 14 },
		list: { top: 6, side: 10, bottom: 10 },
		row: { height: 48, paddingV: 8, paddingH: 10, gap: 12, radius: 10, icon: 32, iconRadius: 8, initial: 13, name: 14, pin: 24, pinRadius: 7, pinSize: 15 },
		label: { size: 11, tracking: 0.66, top: 10, side: 10, bottom: 4 },
		empty: { size: 13, padding: 40 },
		selectedAlpha: 0.28, selectedEdgeAlpha: 0.55,
		skeleton: { rows: 8, pulseMs: 1100, line: 12 },
		debounceMs: 150, browseLimit: 60, searchLimit: 50,
		fadeMs: 150, exitMs: 160
	},
	// Error toast (Dock.css .dock-toast).
	toast: { bottom: 80, paddingV: 8, paddingH: 16, radius: 8, size: 12, color: "#f87171", slide: 10, fadeMs: 200, showMs: 4000 },
	// Workspace segment (new, D7).
	workspaces: { padding: 6, cell: 24, cellRadius: 8, gap: 2, size: 12, idleOpacity: 0.55, highlightAlpha: 0.15 },
	preview: { width: 220, imageHeight: 130, gap: 12, maxVisible: 3, dwellMs: 300, retainMs: 100, bridge: 20, motionMs: 150 },
	extras: { tile: 36 },
	// The Command Center's System Tray button shows the dock this long (as long
	// as the notch's event peek; Bloom opens Windows' tray flyout instead).
	revealMs: 3000,
	// Bloom's drag variant.
	drag: { y: -10, scale: 1.1, opacity: 0.8 }
};

// The launcher (Phase 6; Bloom has none, owner decision: Spotlight-style). The
// language is Bloom's Add App card: its surface, search field, rows and spring.
var launcher = {
	width: 560,
	top: 0.22, // of the screen's height, where the bar sits
	radius: 18,
	maxRows: 8,
	padding: 10,
	thumb: { width: 240, height: 150, padding: 8, radius: 10 },
	gap: 6,
	field: { paddingH: 14, height: 44, radius: 12, gap: 10, icon: 16, size: 15 },
	sub: 11,
	height: { stiffness: 420, damping: 42 },
	enter: { stiffness: 320, damping: 36, mass: 0.9, scale: 0.985 },
	exitMs: 120
};

// The session menu (Phase 6): the launcher's card, Command Center's round buttons.
var session = {
	padding: 18,
	gap: 14,
	label: 11,
	labelGap: 8,
	cell: 84,
	note: 12
};

// The wallpaper picker (Phase 7): the launcher's card over a grid.
var picker = { columns: 3, rows: 3, cellWidth: 240, cellHeight: 150, gap: 8, padding: 12, radius: 10, text: 12 };

// The settings app (Bloom Settings.css).
var settings = {
	// Owner-selected Settings window size; content scaling does not resize it.
	window: { width: 1189, height: 781, minWidth: 640, minHeight: 440, radius: 12 },
	control: 28,
	controlRadius: 6,
	controlText: 14,
	title: { paddingTop: 16, paddingBottom: 10, paddingH: 18, size: 15, close: 22, closeIcon: 12 },
	sidebar: { width: 206, paddingV: 14, paddingH: 12, gap: 4, intro: { top: 8, h: 12, bottom: 18, gap: 2, title: 19, sub: 13 } },
	tab: { height: 36, paddingH: 12, gap: 10, radius: 8, icon: 20, glyph: 14, text: 15, idleOpacity: 0.8, ms: 150 },
	content: { top: 12, h: 22, bottom: 28, scrollbar: 5 },
	heading: { top: 2, h: 2, bottom: 18, title: 28, titleGap: 3, sub: 14 },
	group: { radius: 12, label: { size: 13, spacing: 0.5, top: 18, firstTop: 4, spacedTop: 24, h: 6, bottom: 8 } },
	row: { paddingV: 10, paddingH: 14, icon: 28, glyph: 14, iconGap: 12, label: 16, desc: 13, gap: 2, labelLine: 20, descLine: 16, inset: 54, divider: 53, ms: 120 },
	toggle: { width: 42, height: 24, knob: 18, inset: 2, travel: 18, on: "#34c759", ms: 160 },
	slider: { width: 100, track: 4, thumb: 14 },
	select: { size: 13, radius: 6, paddingV: 4, paddingH: 8, minWidth: 80, itemHeight: 28 },
	scale: { size: 13, radius: 6, button: 20, value: 60, gap: 8, paddingV: 2, paddingH: 4 },
	color: { size: 28, gap: 8, text: 13 },
	about: { padding: [10, 4], top: 14, bottom: 20, logo: 68, logoGap: 14, title: 40, version: 12, credit: 13.5 },
	danger: "#ff453a"
};

// The on-screen keyboard and the overlay (Phase 7).
var osk = { width: 760, height: 280, margin: 12, radius: 18, gap: 6, key: 44, keyRadius: 9, text: 15 };
var overlay = { dim: 0.45, radius: 14, padding: 14, crosshair: 18 };

// Scrolling everywhere: slightly underdamped, so it settles with a small bounce.
var scroll = { stiffness: 180, damping: 21, wheelStep: 100, resistance: 0.3, overscroll: 56, settleMs: 70, friction: 5.5, maxVelocity: 2400, stopVelocity: 12 };

// Bloom's morph: surfaces open by growing in both width and height on the
// notch's spring, not by scaling. `from` is the share of full size they start at.
var morph = { stiffness: 450, damping: 34, mass: 0.8, from: 0.9 };

// Low-power mode: how often a live preview refreshes.
var lowPower = { captureMs: 1000 };

// The keybind cheatsheet (Phase 7): the launcher's card, in three columns.
var cheatsheet = {
	width: 1080,
	margin: 48,
	padding: 20,
	gap: 20,
	rowGap: 7,
	title: 14,
	text: 12,
	cap: 11,
	capGap: 3,
	capPadding: 6,
	capHeight: 20,
	capRadius: 6
};

// The workspace overview (Phase 6): the launcher's card over a grid of
// workspaces, with Bloom's tile radii.
var overview = {
	cell: 216,
	gap: 10,
	padding: 14,
	radius: 12,
	windowRadius: 6,
	label: { size: 11, x: 8, y: 6 },
	dimmed: 0.3, // windows a search doesn't match
	dragThreshold: 6
};

// The polkit dialog (Phase 6): the launcher's card with quick-panel parts.
var lock = {
	message: 12,
	blur: { sigma: 30, dim: 0.3, spill: 100, downscale: 4, settleMs: 100 },
	clock: {
		size: 230, top: 0.2, sides: 9, depth: 0.055, turnMs: 60000,
		hour: { length: 0.5, width: 14 },
		minute: { length: 0.72, width: 8 },
		second: { orbit: 0.82, size: 10 },
		mark: { orbit: 0.86, size: 4 },
		date: { size: 36, text: 14 },
		tag: { top: 16, height: 28, paddingH: 12, gap: 6, icon: 13, text: 13 }
	},
	island: {
		height: 48, radius: 24, gap: 10, bottom: 20, paddingH: 14, itemGap: 8, icon: 16, text: 13,
		button: 36, field: 280, fieldSize: 13,
		enter: { stiffness: 320, damping: 36, mass: 0.9, scale: 0.97 }
	},
	shake: { ms: 50, steps: [-4, 3, -2, 0] },
	enter: { coverMs: 250, maxMs: 500, chromeExitMs: 400 },
	leave: { viewMs: 200, ms: 400, returnMs: 150 },
	capsPollMs: 500,
	clearMs: 10000,
	media: { width: 360, height: 134, smallHeight: 116, radius: 18, padding: 16, art: 50, artRadius: 10, gap: 12, button: 36 }
};

var polkit = {
	width: 400,
	padding: 20,
	gap: 12,
	icon: 36,
	iconGlyph: 18,
	title: 15,
	message: 12
};

// Notch panels, copied from Bloom @ b5fb962 (App.css, components/QuickPanel.css).
// Each group names the CSS rule it comes from.

// Shared by every panel below the 36 px clock strip.
var panel = {
	strip: 36,
	bottomRadius: 18 // .qp, .command-center-content-minimal: border-radius 0 0 18 18
};

// components/QuickPanel.css (.qp-*), the Wi-Fi, Bluetooth and Devices panels.
var qp = {
	padding: { top: 4, side: 12, bottom: 8 }, // .qp padding 4px 12px 8px
	gap: 6, // .qp gap
	text: 11, // .qp font-size
	header: { gap: 4, title: 12 }, // .qp-header, .qp-title 12/600
	iconButton: { size: 24, radius: 8, glyph: 14, disabledOpacity: 0.4 }, // .qp-icon-btn
	switch: { width: 30, height: 17, radius: 9, knob: 13, inset: 2, travel: 13, ms: 200, margin: 4 }, // .qp-switch
	list: { gap: 2, scrollbar: 4, rightPad: 2 }, // .qp-list
	row: { radius: 10, padV: 5, padH: 8, gap: 9, icon: 24, glyph: 13, sub: 9.5, lineHeight: 1.25, badge: 11 }, // .qp-row*
	actions: { gap: 6, left: 41, side: 8, bottom: 8 }, // .qp-row-actions padding 0 8 8 41
	button: { minWidth: 64, height: 24, padH: 10, radius: 8, text: 10.5, glyph: 13, disabledOpacity: 0.45, primaryHoverOpacity: 0.9 }, // .qp-btn
	input: { height: 26, padH: 9, radius: 8 }, // .qp-input
	chip: { height: 20, padH: 8, radius: 10, text: 10, gap: 4 }, // .qp-chip, .qp-chips
	note: 10, // .qp-note
	error: { color: "#ff8a80", text: 10, left: 41, side: 8, bottom: 7 }, // .qp-error
	empty: { gap: 8, padH: 24, glyph: 18 }, // .qp-empty
	footer: { padV: 2, padH: 8, radius: 6, text: 10 }, // .qp-footer
	spinMs: 900, // .qp-spin 0.9s linear
	hoverMs: 150 // background/colour transitions 0.15s ease
};

// Bloom's "battery hub" (QuickPanel.css .bh-*), the Connected devices panel.
var bh = {
	titleIcon: 22, // .bh-title-icon
	groupGap: 8, // .bh-list gap
	groupTitle: { text: 9.5, tracking: 0.38, padH: 8, low: "#ff453a" }, // .bh-group-title (0.04em of 9.5)
	row: { padV: 4, padH: 8, gap: 9, radius: 10 }, // .bh-row
	looksLeft: 47, // .bh-looks padding-left
	art: 30, artGlyph: 18, // .bh-art
	meters: { gap: 8, width: 40, gapV: 3, value: 10.5, label: 9, bolt: 9, bar: 3, barRadius: 2, track: 0.14, fillMs: 400 }, // .bh-meter*
	green: "#32d74b",
	red: "#ff453a",
	unknown: 9.5 // .bh-unknown
};

// App.css .command-center-content-minimal and .cc-*.
var cc = {
	padding: { v: 12, h: 14 },
	grid: { gap: 10, height: 78 }, // .cc-pills-grid
	tile: { height: 34, padV: 5, padH: 8, gap: 8, radius: 10, hoverLift: -0.5, pressScale: 0.98, ms: 150 }, // .cc-pill-tile
	tileIcon: { size: 20, glyph: 12 }, // .cc-pill-icon-wrapper
	title: 9, status: 7.5, lineHeight: 1.15, activeStatusAlpha: 0.5, // .cc-pill-title/status
	more: { size: 18, radius: 6, glyph: 12, opacity: 0.55 }, // .cc-pill-more
	round: { size: 32, glyph: 14, hoverLift: -1, pressScale: 0.95, ms: 200, sidePad: 4 }, // .cc-circular-*
	sliders: { gap: 8, rowHeight: 18, rowGap: 10, label: 75, labelGap: 6, text: 9, glyph: 12, glyphOpacity: 0.7, track: 6, trackRadius: 3, percent: 28 }, // .cc-classic-*
	easeOut: [0.16, 1, 0.3, 1] // cubic-bezier(0.16, 1, 0.3, 1)
};

// App.css .calendar-*: the calendar column.
var calendar = {
	padding: 16, gap: 16, topMargin: 1, bottomRadius: 28, // .calendar-timer-content.split-view
	columns: [1.2, 1], // .calendar-column flex 1.2, .timer-column flex 1
	month: { text: 13, opacity: 0.9, below: 8 }, // .month-year, .calendar-header margin
	grid: { gap: 2 }, // .calendar-grid
	dayName: { text: 9, opacity: 0.4, below: 2 }, // .day-name
	day: { text: 10, radius: 4 } // .calendar-day
};

// App.css .timer-*, .roll-*: the timer column.
var timer = {
	sectionGap: 18, mainGap: 4, // .timer-section-new, .timer-main
	status: { height: 14, text: 10, tracking: 0.2, opacity: 0.4, finishedOpacity: 0.9 }, // .timer-status
	digit: { width: 34, height: 58, text: 36, tracking: -0.5, gap: 5 }, // .roll-digit, .roll-num, .timer-clock gap
	compact: { width: 26, height: 46, text: 28 }, // .roll-digit.compact
	colon: { text: 32, opacity: 0.3, padH: 2 }, // .timer-colon
	roll: { travel: 0.72, angle: 50, ms: 400, ease: [0.22, 1, 0.36, 1] }, // RollDigit
	underline: { height: 2, width: 0.74, opacity: 0.3, ms: 250 }, // .timer-edit-underline
	controls: { gap: 8, spacer: 32 }, // .timer-controls-row
	play: { height: 44, radius: 22, text: 12, gap: 7, glyph: 14, hoverOpacity: 0.9, pressScale: 0.97, ms: 150 }, // .timer-btn-play
	reset: { size: 32, glyph: 14, opacity: 0.35, hoverOpacity: 0.8, disabledOpacity: 0.08, pressScale: 0.9 }, // .timer-btn-reset
	presets: { gap: 4, padV: 6, radius: 7, text: 10, opacity: 0.5 }, // .timer-preset-*
	red: "#ff453a",
	pulse: { ms: 1900, delay: 650 } // .state-finished .timer-clock animation
};

// App.css .shelf-*.
var shelf = {
	padding: { v: 12, h: 14 },
	empty: { text: 12, opacity: 0.55, border: 0.25, radius: 12 }, // .shelf-empty
	gap: 8, scrollbar: 5, // .shelf-items-grid
	tile: { width: 104, pad: 6, gap: 4, radius: 12, bg: 0.06, hoverBg: 0.12 }, // .shelf-tile
	preview: { height: 84, radius: 8, bg: 0.05, opacity: 0.85, textBg: 0.075, textLine: 0.16, text: 10, lineHeight: 1.45, fade: 0.72 }, // .shelf-tile-preview/-text
	name: { text: 11, opacity: 0.85 }, // .shelf-tile-name
	remove: { size: 18, inset: 4, bg: 0.55, ms: 120 }, // .shelf-tile-remove
	notice: { bottom: 10, padV: 5, padH: 12, bg: 0.75, text: 11 } // .shelf-notice
};

// App.css .panel-arrow: the arrows beside the clock while a panel is open.
var panelArrow = { size: 18, gap: 4, glyph: 12, ms: 150, slide: 4 };

// App.css .device-alert*.
var alert = {
	pad: { left: 14, right: 18 }, gap: 12,
	name: 13.5, status: 12,
	ring: { size: 28, stroke: 2.6, track: 0.14, ms: 600, text: 9.5 },
	buds: { gap: 7, label: 9 }
};

// App.css .time-flip-container, .compact-timer and the finished timer's
// keyframes (timer-pop, timer-heartbeat, bell-wiggle).
var clock = {
	box: { minWidth: 60, height: 24 },
	pressScale: 0.95, pressMs: 100, colorMs: 200,
	flip: { stiffness: 600, damping: 30 },
	timerGap: 5,
	bell: { size: 13, stroke: 2.5, originY: 0.12, ms: 850, loops: 3, angles: [0, -16, 13, -10, 7, -4, 0] },
	pop: { ms: 650, ease: [0.22, 1, 0.36, 1], scales: [1, 1.22, 0.97, 1], at: [0, 0.35, 0.7, 1] },
	heartbeat: { ms: 1900, scale: 1.07 },
	red: "#ff453a"
};

// The volume and brightness HUDs (Bloom Overlay.tsx, Overlay.css).
var osd = {
	card: { width: 42, height: 196, radius: 18 },
	// .volume-notch padding 16 0 14; .brightness-notch padding 16 0.
	volumePad: { top: 16, bottom: 14 },
	brightnessPad: 16,
	bar: { width: 10, radius: 5, track: 0.2, trackLight: 0.12 },
	// The brightness bar is 136 px with a 4 px margin, but flexbox shrinks it
	// to fit the 20 px sun and its 10 px margin in the card: 130.
	brightnessBar: { top: 4, height: 130 },
	sun: { size: 20, top: 10, turn: 180 },
	action: { height: 20, top: 2, icon: 16, iconOpacity: 0.8, mixerFrom: 0.82, text: 10, tracking: -0.2, ms: 160 },
	enter: { stiffness: 450, damping: 25, mass: 0.7, scaleYFrom: 0.5, blur: 12 },
	exit: { ms: 200, scaleY: 0.8, blur: 12, ease: [0.32, 0.72, 0, 1] },
	exitMixer: { ms: 220, x: -64, blur: 8 },
	content: { x: 10, delayMs: 50, ms: 200, exitX: 5, exitMs: 150 },
	fill: { stiffness: 300, damping: 35 },
	sunSpring: { stiffness: 200, damping: 25 },
	percentMs: 1200,
	hideMs: 2000, leaveMs: 1500, leaveMixerMs: 700,
	mixer: {
		column: 44, gap: 4, pad: { top: 16, side: 8, bottom: 14 }, maxColumns: 4, emptyColumns: 2,
		rowMin: 70, barMin: 48, icon: 18, iconRadius: 5, fallbackText: 9, percentText: 9,
		mutedOpacity: 0.35, pressScale: 0.94, empty: 11,
		widthSpring: { duration: 0.35, bounce: 0 },
		exitX: -18, exitXMs: 280, exitOpacityMs: 180, exitOpacityDelay: 100
	}
};
