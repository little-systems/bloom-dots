import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/screens.js" as Screens

// The dialog on the focused screen: a full-screen layer, shown while the agent
// has a request, that takes the keyboard.
PanelWindow {
	id: win
	required property var screenData
	required property var agent
	readonly property var flow: win.agent.flow
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(screenData, HyprState.monitors, Quickshell.screens)
	readonly property bool requested: win.agent.isActive && win.targetScreen
	property string _failure: ""

	screen: screenData
	anchors.top: true
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	color: "transparent"
	exclusiveZone: -1
	visible: win.requested || view.shown
	WlrLayershell.namespace: "bloom:polkit"
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: win.requested ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

	onRequestedChanged: {
		if (win.requested) {
			win._failure = "";
			view.open();
		} else {
			view.close();
		}
	}

	PolkitView {
		id: view
		width: win.width / win.uiScale
		height: win.height / win.uiScale
		scale: win.uiScale
		transformOrigin: Item.TopLeft
		theme: Theme
		message: win.flow?.message ?? ""
		prompt: win.flow?.inputPrompt ?? ""
		responseVisible: win.flow?.responseVisible ?? false
		supplementary: win._failure || (win.flow?.supplementaryMessage ?? "")
		supplementaryIsError: win._failure !== "" || (win.flow?.supplementaryIsError ?? false)
		busy: !!win.flow && !win.flow.isResponseRequired && !win.flow.isCompleted
		onSubmitted: response => {
			win._failure = "";
			win.flow.submit(response);
		}
		onCancelled: win.flow.cancelAuthenticationRequest()
	}

	Connections {
		target: win.flow
		ignoreUnknownSignals: true
		function onAuthenticationFailed() { win._failure = "That password didn't work"; }
	}
}
