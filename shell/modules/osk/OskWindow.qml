import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/tokens.js" as Tokens
import "../../common/screens.js" as Screens

// The keyboard on the focused screen. It never takes keyboard focus, so keys
// land in whatever window you were using.
PanelWindow {
	id: win
	required property var modelData
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)

	screen: modelData
	anchors.bottom: true
	margins.bottom: Tokens.osk.margin
	implicitWidth: Tokens.osk.width * win.uiScale
	implicitHeight: Tokens.osk.height * win.uiScale
	color: "transparent"
	exclusiveZone: 0
	visible: Osk.opened && targetScreen
	WlrLayershell.namespace: "bloom:osk"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	OskView {
		width: Tokens.osk.width
		height: Tokens.osk.height
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		accent: Theme.accent
		held: Osk.held
		onPressed: key => Osk.press(key)
	}
}
