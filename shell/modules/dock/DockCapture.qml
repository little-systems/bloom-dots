import Quickshell.Wayland
import "../../common/tokens.js" as Tokens

// Loaded only in a real Wayland dock. Keeping the Quickshell import here lets
// the card's offscreen QML tests exercise its fallback without a compositor.
ScreencopyView {
	property bool streamLive: false
	live: streamLive
	paintCursor: false
	constraintSize: Qt.size(Tokens.dock.preview.width, Tokens.dock.preview.imageHeight)
}
