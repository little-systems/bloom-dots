import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../../common/tokens.js" as Tokens

// Bloom's ambient glow behind the open player (.notch-ambient-glow): the album
// art, cover-fitted and enlarged 1.8×, under CSS's
// blur(52px) saturate(3.5) contrast(1.1) brightness(1.4) (the stylesheet's
// 0.85 opacity is overridden by framer's animate to 1),
// then a radial vignette that fades into the notch colour, clipped to the
// pill's rounded bottom. CSS filters before it transforms, so the blur is
// enlarged with the art: a true Gaussian of σ 52 × 1.8 (two shader passes at
// eighth resolution), with the art's surroundings transparent as in
// Chromium; shaders/*.frag hold the maths.
// Motion (App.tsx): the glow fades over 0.15 s with `active`; each art enters
// over 0.3 s, opacity 0 → 1 and scale 1.1 → 1.8, once the previous art has
// faded out (AnimatePresence mode="wait"); all framer's default easeInOut.
Item {
	id: root

	property url source: ""
	property bool active: true
	property color bg: Qt.rgba(0, 0, 0, 0.92)
	property real radius: 18
	readonly property bool shown: art.status === Image.Ready
	// The art on screen: it changes only once the previous one has left.
	readonly property alias shownSource: art.source
	property real zoom: Tokens.music.ambience.scale
	property real artOpacity: 0
	readonly property real _sigma: Tokens.music.ambience.blur * root.zoom
	// Room for the widest blur.
	readonly property real _pad: 3 * Tokens.music.ambience.blur * Tokens.music.ambience.scale
	readonly property size _texture: Qt.size(Math.max(1, Math.ceil(artLayer.width / 8)), Math.max(1, Math.ceil(artLayer.height / 8)))
	readonly property var _easeInOut: [0.42, 0, 0.58, 1, 1, 1]

	opacity: root.active && root.shown ? 1 : 0
	visible: opacity > 0
	Behavior on opacity { NumberAnimation { duration: Tokens.music.ambience.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: root._easeInOut } }

	onSourceChanged: {
		if (root.artOpacity > 0 || leave.running) {
			enter.stop();
			if (!leave.running) leave.start();
		} else {
			root._show();
		}
	}
	function _show() {
		const same = art.source === root.source;
		art.source = root.source;
		if (same && root.shown) enter.restart();
	}
	Connections {
		target: art
		function onStatusChanged() { if (art.status === Image.Ready) enter.restart(); }
	}
	ParallelAnimation {
		id: enter
		NumberAnimation { target: root; property: "zoom"; from: Tokens.music.ambience.enterScale; to: Tokens.music.ambience.scale; duration: Tokens.music.ambience.artMs; easing.type: Easing.BezierSpline; easing.bezierCurve: root._easeInOut }
		NumberAnimation { target: root; property: "artOpacity"; from: 0; to: 1; duration: Tokens.music.ambience.artMs; easing.type: Easing.BezierSpline; easing.bezierCurve: root._easeInOut }
	}
	SequentialAnimation {
		id: leave
		NumberAnimation { target: root; property: "artOpacity"; to: 0; duration: Tokens.music.ambience.artMs; easing.type: Easing.BezierSpline; easing.bezierCurve: root._easeInOut }
		ScriptAction { script: root._show() }
	}
	layer.enabled: true
	layer.effect: MultiEffect {
		maskEnabled: true
		maskSource: pillShape
	}

	// The art with 3σ of transparent margin on every side, so the blur
	// fades its edges as the browser's does.
	Item {
		id: artLayer
		x: -root._pad
		y: -root._pad
		width: root.width + 2 * root._pad
		height: root.height + 2 * root._pad
		visible: false
		layer.enabled: true
		layer.smooth: true
		layer.textureSize: root._texture
		// Half floats: the filters stretch dark values about 5×, which
		// shows 8-bit steps as bands.
		layer.format: ShaderEffectSource.RGBA16F

		Image {
			id: art
			anchors.centerIn: parent
			width: root.width * root.zoom
			height: root.height * root.zoom
			fillMode: Image.PreserveAspectCrop
			asynchronous: true
			sourceSize: Qt.size(128, 128)
			smooth: true
		}
	}

	ShaderEffect {
		id: across
		x: artLayer.x
		y: artLayer.y
		width: artLayer.width
		height: artLayer.height
		visible: false
		layer.enabled: true
		layer.smooth: true
		layer.textureSize: root._texture
		// Half floats: the filters stretch dark values about 5×, which
		// shows 8-bit steps as bands.
		layer.format: ShaderEffectSource.RGBA16F
		property var source: artLayer
		property vector2d delta: Qt.vector2d(root._sigma / Math.max(1, width), 0)
		fragmentShader: "shaders/blur.frag.qsb"
	}

	ShaderEffect {
		id: glow
		objectName: "glow"
		x: artLayer.x
		y: artLayer.y
		width: artLayer.width
		height: artLayer.height
		property var source: across
		property vector2d delta: Qt.vector2d(0, root._sigma / Math.max(1, height))
		property real saturate: Tokens.music.ambience.saturate
		property real contrast: Tokens.music.ambience.contrast
		property real brightness: Tokens.music.ambience.brightness
		property real alpha: Tokens.music.ambience.opacity
		opacity: root.artOpacity
		fragmentShader: "shaders/ambience.frag.qsb"
	}

	// radial-gradient(ellipse at center, …): the ellipse reaches the
	// farthest corner, so its radii are √2 × the half-sides. Drawn as a
	// circle of the horizontal radius, squashed to the vertical one.
	Shape {
		id: vignette
		objectName: "vignette"
		readonly property real radiusX: root.width / 2 * Math.SQRT2
		readonly property real radiusY: root.height / 2 * Math.SQRT2
		width: root.width
		height: root.height
		preferredRendererType: Shape.CurveRenderer
		ShapePath {
			strokeWidth: -1
			fillGradient: RadialGradient {
				centerX: root.width / 2
				centerY: root.height / 2
				centerRadius: vignette.radiusX
				focalX: centerX
				focalY: centerY
				GradientStop { position: 0.2; color: "transparent" }
				GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.25) }
				GradientStop { position: 0.85; color: root.bg }
				GradientStop { position: 1; color: root.bg }
			}
			fillTransform: PlanarTransform.fromScale(1, vignette.radiusY / Math.max(1, vignette.radiusX), root.width / 2, root.height / 2)
			PathRectangle { x: 0; y: 0; width: root.width; height: root.height }
		}
	}

	Item {
		id: pillShape
		anchors.fill: parent
		visible: false
		layer.enabled: true
		Rectangle {
			anchors.fill: parent
			bottomLeftRadius: root.radius
			bottomRightRadius: root.radius
		}
	}
}
