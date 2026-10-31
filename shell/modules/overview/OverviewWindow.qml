import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../dock"
import "../../common/screens.js" as Screens

// The overview on the focused screen: a full-screen layer, mapped only while
// it shows, that takes the keyboard, with live window captures.
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
	exclusiveZone: 0
	visible: targetScreen && (Overview.opened || view.shown)
	WlrLayershell.namespace: "bloom:overview"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: Overview.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
		DockCapture { streamLive: Overview.opened }
	}

	OverviewView {
		id: view
		width: win.width / win.uiScale
		height: win.height / win.uiScale
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		accent: Theme.accent
		clients: Overview.clients
		monitor: Overview.monitor
		activeWorkspace: Overview.activeWorkspace
		toplevelFor: address => win._toplevels[address] ?? null
		captureComponent: HyprState.available ? capture : null
		onWorkspaceChosen: id => Overview.goToWorkspace(id)
		onWindowChosen: address => Overview.goToWindow(address)
		onWindowMoved: (address, workspace) => Overview.moveWindow(address, workspace)
		onDismissed: Overview.hide()
	}

	Connections {
		target: Overview
		function onOpenedChanged() {
			if (Overview.opened) view.open();
			else view.close();
		}
	}
}
