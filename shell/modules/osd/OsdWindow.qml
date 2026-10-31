import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common"
import "."
import "../../common/screens.js" as Screens
import "../../common/tokens.js" as Tokens

// One edge HUD on one screen: binds OsdCard (Bloom's VolumeNotch or
// BrightnessNotch) to the services, with Bloom's timing: shown for 2 s after a
// change, kept while the pointer is on it or the edge, hidden 1.5 s after it
// leaves (0.7 s with the mixer open); an open mixer pins it. Only the narrow
// edge target and the card take input; the rest of the layer passes it on.
PanelWindow {
	id: win
	required property var modelData
	required property string edge
	property bool shown: false
	property bool mixerOpen: false
	readonly property bool pointerOverCard: edgeArea.containsMouse || cardHover.hovered
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool hudEnabled: Settings.values[win.edge === "left" ? "bloom-volume-hud-enabled" : "bloom-brightness-hud-enabled"]
	readonly property bool edgeEnabled: win.hudEnabled && Settings.values[win.edge === "left" ? "bloom-volume-edge-enabled" : "bloom-brightness-edge-enabled"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)

	function show() {
		if (!win.hudEnabled || !win.targetScreen || (win.edge === "right" && !Brightness.available)) return false;
		win.shown = true;
		hoverHideTimer.stop();
		if (!win.pointerOverCard && !win.mixerOpen) hideTimer.restart();
		return true;
	}
	function keepOpen() {
		if (!win.hudEnabled || !win.targetScreen || (win.edge === "right" && !Brightness.available)) return;
		win.shown = true;
		hideTimer.stop();
		hoverHideTimer.stop();
	}
	function leaveCard() {
		// Wait until Qt has delivered hover to a neighbouring item.
		Qt.callLater(() => {
			if (win.shown && !win.pointerOverCard) {
				hoverHideTimer.interval = win.mixerOpen ? Tokens.osd.leaveMixerMs : Tokens.osd.leaveMs;
				hoverHideTimer.restart();
			}
		});
	}
	function stateObject() {
		return { edge: edge, screen: modelData.name, shown: shown, mixerOpen: mixerOpen,
			width: Tokens.osd.card.width * uiScale, height: Tokens.osd.card.height * uiScale,
			backlightAvailable: edge === "right" && Brightness.available };
	}
	onShownChanged: if (!win.shown) win.mixerOpen = false

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: edge === "left"
	anchors.right: edge === "right"
	// Room for the card with its widest mixer (4 columns) and edge flares.
	implicitWidth: Math.ceil((edge === "left" ? 360 : 60) * uiScale)
	color: "transparent"
	// Stay mapped so the transparent edge target can receive pointer hover.
	visible: targetScreen && (edge === "left" || Brightness.available)
	exclusiveZone: 0
	WlrLayershell.namespace: "bloom:osd-" + edge
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	mask: Region {
		item: edgeTarget
		Region { item: card.onScreen ? cardBox : null }
	}

	Timer {
		id: hideTimer
		interval: Settings.values["bloom-osd-timeout"]
		onTriggered: if (!win.pointerOverCard && !win.mixerOpen) win.shown = false
	}
	Timer {
		id: hoverHideTimer
		interval: Tokens.osd.leaveMs
		onTriggered: if (!win.pointerOverCard) { win.mixerOpen = false; win.shown = false; }
	}
	Connections {
		target: Audio
		function onOutputChanged() { if (win.edge === "left") win.show(); }
	}
	Connections {
		target: Brightness
		function onLevelChanged() { if (win.edge === "right") win.show(); }
	}

	Item {
		id: edgeTarget
		x: win.edge === "left" ? 0 : win.width - width
		width: 8 * win.uiScale
		height: win.height
		// cursor: default — the screen-edge reveal band
		MouseArea {
			id: edgeArea
			enabled: win.edgeEnabled
			anchors.fill: parent
			hoverEnabled: true
			onEntered: win.keepOpen()
			onExited: win.leaveCard()
		}
	}

	// The card's box at its scale, for the input mask and hover.
	Item {
		id: cardBox
		x: win.edge === "left" ? 0 : win.width - width
		y: Math.round((win.height - height) / 2)
		width: card.width * win.uiScale
		height: card.height * win.uiScale

		HoverHandler {
			id: cardHover
			onHoveredChanged: {
				if (hovered) win.keepOpen();
				else win.leaveCard();
			}
		}

		OsdCard {
			id: card
			edge: win.edge
			scale: win.uiScale
			transformOrigin: win.edge === "left" ? Item.TopLeft : Item.TopRight
			x: win.edge === "left" ? 0 : cardBox.width - width
			theme: Theme
			light: Theme.isLight
			shown: win.shown
			value: win.edge === "left" ? Audio.volume : Brightness.percent / 100
			muted: win.edge === "left" && Audio.muted
			mixerOpen: win.mixerOpen
			sessions: win.edge === "left" ? Audio.mixerRows.slice(0, 12).map(r => ({
				id: r.id, name: r.name, volume: r.volume, muted: r.muted,
				icon: r.iconName ? Quickshell.iconPath(r.iconName, true) : ""
			})) : []
			onValueChosen: value => {
				if (win.edge === "left") Audio.setVolume(value);
				else Brightness.setPercent(value * 100);
			}
			onMixerToggled: {
				win.mixerOpen = !win.mixerOpen;
				if (win.mixerOpen) win.keepOpen();
				else if (!win.pointerOverCard) hoverHideTimer.restart();
			}
			onSessionVolumeChosen: (id, volume) => Audio.setStreamVolume(id, volume)
			onSessionMuteToggled: id => Audio.toggleStreamMute(id)
		}
	}
}
