import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import "."
import "../dock"
import "../../common/screens.js" as Screens

// The Alt + Tab switcher on the focused screen: a full-screen layer, mapped
// only while it shows, that never takes the keyboard (Hyprland's Alt binds
// drive it) and takes clicks only on the card. Live previews as the overview.
PanelWindow {
	id: win
	required property var modelData
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "transparent"
	exclusiveZone: -1
	visible: targetScreen && (Switcher.revealed || view.shown)
	mask: Region { item: Switcher.revealed ? view.cardItem : null }
	WlrLayershell.namespace: "bloom:switcher"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	HyprlandWindow.opacity: view.compositorFade ? view.fade : 1

	readonly property var _toplevels: {
		const out = {};
		for (const t of ToplevelManager.toplevels.values) {
			const raw = t.HyprlandToplevel?.address;
			if (raw) out[raw.startsWith("0x") ? raw : "0x" + raw] = t;
		}
		return out;
	}

	Component {
		id: capture
		DockCapture { streamLive: Switcher.revealed; constraintSize: Qt.size(440, 248) }
	}

	SwitcherView {
		id: view
		compositorFade: HyprState.available
		width: win.width / win.uiScale
		height: win.height / win.uiScale
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		accent: Theme.accent
		index: Switcher.index
		items: {
			void Apps.revision;
			return Switcher.addresses.map(address => {
				const t = win._toplevels[address];
				const id = t ? Apps.idForClass(t.appId) : "";
				const info = id ? Apps.info(id) : null;
				return {
					address: address,
					title: t?.title ?? "",
					appName: info?.name ?? t?.appId ?? "",
					icon: info?.icon || (t?.appId ? Quickshell.iconPath(t.appId, true) : "")
				};
			});
		}
		toplevelFor: address => win._toplevels[address] ?? null
		captureComponent: HyprState.available ? capture : null
		onChosen: index => Switcher.choose(index)
	}

	Connections {
		target: Switcher
		function onRevealedChanged() {
			if (Switcher.revealed) view.open();
			else view.close();
		}
	}
}
