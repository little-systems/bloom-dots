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
