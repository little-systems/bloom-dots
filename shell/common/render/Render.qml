pragma Singleton
import QtQuick

// The shell draws its stages scaled (bloom-scale, on the screen's pixel
// ratio), but a layer renders at its item's own size and is then stretched,
// which blurs it. Layers size their textures with texture(): the item's box
// at the scale it is drawn. shell.qml sets the scale.
QtObject {
	property real scale: 1
	property real uiScale: 1
	property real fontScale: 1
	// bloom-reduce-motion: springs land at once. shell.qml sets it.
	property bool reduceMotion: false
	// The previous Bloom motion remains available only through settings.json.
	property string animationStyle: "macos"
	readonly property bool macMotion: animationStyle === "macos"

	function texture(width, height) {
		return Qt.size(Math.max(1, Math.ceil(width * scale)), Math.max(1, Math.ceil(height * scale)));
	}
}
