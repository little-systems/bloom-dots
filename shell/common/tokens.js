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
	press: { stiffness: 400, damping: 25, mass: 1 }
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
	family: "Inter",
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
