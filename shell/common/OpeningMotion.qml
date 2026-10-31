import QtQuick
import "render"
import "tokens.js" as Tokens

// Mac-style entrances keep text and layout steady: a short fade, slight
// scale and a small slide. Config-only Bloom mode restores the size morph.
Spring {
	id: root
	readonly property bool stableLayout: Render.macMotion
	stiffness: stableLayout ? 500 : Tokens.morph.stiffness
	damping: stableLayout ? 45 : Tokens.morph.damping
	mass: stableLayout ? 1 : Tokens.morph.mass
	readonly property real progress: Math.max(0, Math.min(1, value))
	readonly property real extent: stableLayout ? 1 : Tokens.morph.from + (1 - Tokens.morph.from) * Math.max(0, Math.min(1.02, value))
	readonly property real zoom: stableLayout ? 0.97 + 0.03 * progress : 1
	readonly property real rise: stableLayout ? 6 * (1 - progress) : 0
}
