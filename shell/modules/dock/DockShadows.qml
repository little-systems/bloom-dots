import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"
import "../../common/tokens.js" as Tokens

// The dock menu's and Add App's shadows, in their own click-through layer
// beside the dock's. Hyprland blurs the dock layer behind every pixel above
// its ignore_alpha (0.2), shadows included, so a shadow drawn there ends in a
// hard-edged blurred band; this layer has no blur rule. Same edges and height
// as the dock window, so the two share coordinates.
PanelWindow {
	id: win

	required property var view

	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	implicitHeight: Tokens.dock.surfaceHeight
	color: "transparent"
	exclusiveZone: -1
	mask: Region {}
	WlrLayershell.namespace: "bloom:dock-shadows"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	readonly property var _menu: win.view.light ? Tokens.dock.menu.shadowLight : Tokens.dock.menu.shadow

	Item {
		anchors.fill: parent

		ShadowMirror {
			target: win.view.popupCardItem
			offset.y: Tokens.dock.popup.shadow.y
			blur: Tokens.dock.popup.shadow.blur
			color: Qt.rgba(0, 0, 0, Tokens.dock.popup.shadow.alpha)
		}
		ShadowMirror {
			target: win.view.menuBoxItem
			offset.y: win._menu.y
			blur: win._menu.blur
			color: Qt.rgba(0, 0, 0, win._menu.alpha)
		}
		ShadowMirror {
			target: win.view.submenuBoxItem
			offset.y: win._menu.y
			blur: win._menu.blur
			color: Qt.rgba(0, 0, 0, win._menu.alpha)
		}
	}
}
