import QtQuick

// CSS `filter: blur(σ) saturate() contrast() brightness()` and `opacity` on
// its children, computed as Chromium does (checked against Bloom's renders):
// a true Gaussian over a transparent surround, then the Filter Effects colour
// matrices, each clamped. Lay the children out in this item's box; the blur
// spills 3 × maxSigma beyond it. shaders/blur.frag and shaders/filter.frag
// hold the maths.
Item {
	id: root

	default property alias content: box.data
	property real sigma: 0
	// The widest sigma this will animate to: the margin the blur needs.
	property real maxSigma: root.sigma
	property real saturate: 1
	property real contrast: 1
	property real brightness: 1
	property real alpha: 1
	// Render the blur at 1 / downscale resolution: plenty for a wide blur.
	property real downscale: 1

	readonly property real _pad: Math.ceil(3 * root.maxSigma)
	readonly property size _texture: Qt.size(Math.max(1, Math.ceil(source.width / root.downscale)), Math.max(1, Math.ceil(source.height / root.downscale)))

	Item {
		id: source
		x: -root._pad
		y: -root._pad
		width: root.width + 2 * root._pad
		height: root.height + 2 * root._pad
		visible: false
		layer.enabled: true
		layer.smooth: true
		layer.textureSize: root._texture
		// Half floats: the filters stretch dark values several times over,
		// which shows 8-bit steps as bands.
		layer.format: ShaderEffectSource.RGBA16F

		Item {
			id: box
			x: root._pad
			y: root._pad
			width: root.width
			height: root.height
		}
	}

	ShaderEffect {
		id: across
		x: source.x
		y: source.y
		width: source.width
		height: source.height
		visible: false
		layer.enabled: true
		layer.smooth: true
		layer.textureSize: root._texture
		layer.format: ShaderEffectSource.RGBA16F
		property var source: source
		property vector2d delta: Qt.vector2d(root.sigma / Math.max(1, width), 0)
		fragmentShader: "shaders/blur.frag.qsb"
	}

	ShaderEffect {
		x: source.x
		y: source.y
		width: source.width
		height: source.height
		property var source: across
		property vector2d delta: Qt.vector2d(0, root.sigma / Math.max(1, height))
		property real saturate: root.saturate
		property real contrast: root.contrast
		property real brightness: root.brightness
		property real alpha: root.alpha
		fragmentShader: "shaders/filter.frag.qsb"
	}
}
