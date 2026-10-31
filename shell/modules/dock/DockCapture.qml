import QtQuick
import Quickshell.Wayland
import qs.services
import "../../common/tokens.js" as Tokens

// Loaded only in a real Wayland dock. Keeping the Quickshell import here lets
// the card's offscreen QML tests exercise its fallback without a compositor.
ScreencopyView {
	id: root
	property bool streamLive: false
	live: root.streamLive && !Performance.lowPower
	paintCursor: false
	constraintSize: Qt.size(Tokens.dock.preview.width, Tokens.dock.preview.imageHeight)

	// In low-power mode a preview refreshes now and then instead of streaming.
	Timer {
		interval: Tokens.lowPower.captureMs
		repeat: true
		triggeredOnStart: true
		running: root.streamLive && Performance.lowPower
		onTriggered: root.captureFrame()
	}
}
