import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../common/render"

// One AnimatePresence child of Bloom's pulse: enters from opacity 0, scale
// 0.95, blur 4 px; leaves to 0, 1.05, 4 px. framer gives these values no
// transition, so opacity and blur ease over 300 ms and scale is its 550/30
// spring. The blur pass exists only while the blur is above zero.
Item {
	id: root

	property bool present: false
	default property alias content: holder.data

	visible: root.opacity > 0
	opacity: root.present ? 1 : 0
	Behavior on opacity {
		NumberAnimation { duration: Tokens.pulse.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
	}

	property real blurPx: root.present ? 0 : Tokens.pulse.blur
	Behavior on blurPx {
		NumberAnimation { duration: Tokens.pulse.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1] }
	}

	onPresentChanged: {
		// Each entry starts from framer's `initial`, whatever the last exit left.
		if (root.present)
			scaleSpring.jump(Tokens.pulse.enterScale);
	}

	Spring {
		id: scaleSpring
		// A running spring redraws the whole window every frame; a hidden
		// pulse's spring waits (each entry jumps it to the start anyway).
		autoRun: root.visible
		stiffness: 550
		damping: 30
		restSpeed: 10
		initial: Tokens.pulse.enterScale
		target: root.present ? 1 : Tokens.pulse.exitScale
	}

	// The content draws directly; the blur layer is on only while the pulse
	// is blurred (entering or leaving). Content inside a hidden effect source
	// doesn't redraw a Shape that appears later (the charging bolt).
	Item {
		id: holder
		anchors.fill: parent
		scale: scaleSpring.value
		layer.enabled: root.blurPx > 0.01
		layer.textureSize: Render.texture(width, height)
		layer.effect: MultiEffect {
			blurEnabled: true
			blurMax: Tokens.pulse.blurMax
			blur: root.blurPx / Tokens.pulse.blurMax
		}
	}
}
