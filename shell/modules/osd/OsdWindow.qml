import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common"
import "../../common/screens.js" as Screens

// One edge pill on one screen. The window maps only while a change is shown.
PanelWindow {
	id: win
	required property var modelData
	required property string edge
	property bool shown: false
	property bool mixerOpen: false
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)

	function show() {
		if (!win.targetScreen) return;
		win.shown = true;
		hideTimer.restart();
	}
	function stateObject() {
		return { edge: edge, screen: modelData.name, shown: shown, mixerOpen: mixerOpen,
			width: 42 * uiScale, height: 196 * uiScale };
	}

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: edge === "left"
	anchors.right: edge === "right"
	implicitWidth: Math.ceil((edge === "left" ? 360 : 42) * uiScale)
	color: "transparent"
	visible: shown
	exclusiveZone: 0
	WlrLayershell.namespace: "bloom:osd-" + edge
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	mask: Region {
		item: win.shown ? pill : null
		Region { item: win.shown && win.mixerOpen ? mixer : null }
	}

	Timer {
		id: hideTimer
		interval: Settings.values["bloom-osd-timeout"]
		onTriggered: if (!win.mixerOpen) win.shown = false
	}
	Connections {
		target: Audio
		function onOutputChanged() { if (win.edge === "left") win.show(); }
	}
	Connections {
		target: Brightness
		function onLevelChanged() { if (win.edge === "right") win.show(); }
	}

	EdgeSurface {
		id: pill
		edge: win.edge
		pillWidth: 42 * win.uiScale
		pillHeight: 196 * win.uiScale
		flares: win.shown
		color: Theme.bg
		x: win.edge === "right" ? win.width - width : 0
		y: Math.round((win.height - height) / 2)
		Rectangle {
			x: win.edge === "right" ? 0 : 0
			y: pill.pillRect.y
			width: pill.pillRect.width
			height: pill.pillRect.height
			color: "transparent"
			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.top: parent.top
				anchors.topMargin: 12 * win.uiScale
				text: win.edge === "left" ? (Audio.muted ? "×" : "♪") : "☼"
				color: Theme.text
				font.pixelSize: 16 * win.uiScale
			}
			Rectangle {
				id: rail
				width: 6 * win.uiScale
				height: 116 * win.uiScale
				radius: width / 2
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.verticalCenter: parent.verticalCenter
				color: Theme.groupBg
				Rectangle {
					anchors.bottom: parent.bottom
					width: parent.width
					height: parent.height * Math.max(0, Math.min(1, win.edge === "left" ? Audio.volume : Brightness.percent / 100))
					radius: width / 2
					color: Theme.accent
				}
			}
			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				anchors.bottom: parent.bottom
				anchors.bottomMargin: 10 * win.uiScale
				text: win.edge === "left" ? Math.round(Audio.volume * 100) : (Brightness.available ? Brightness.percent : "–")
				color: Theme.text
				font.pixelSize: 10 * win.uiScale
			}
			MouseArea {
				anchors.fill: parent
				onClicked: mouse => {
					if (win.edge === "left" && mouse.y < 35 * win.uiScale) {
						win.mixerOpen = !win.mixerOpen;
						if (!win.mixerOpen) hideTimer.restart();
					} else {
						const value = Math.max(0, Math.min(1, (rail.y + rail.height - mouse.y) / rail.height));
						if (win.edge === "left") Audio.setVolume(value);
						else Brightness.setPercent(value * 100);
					}
				}
			}
		}
	}

	Rectangle {
		id: mixer
		visible: win.edge === "left" && win.mixerOpen
		x: 48 * win.uiScale
		y: Math.round((win.height - height) / 2)
		width: 304 * win.uiScale
		height: Math.max(72, Math.ceil(Math.min(12, Audio.mixerRows.length) / 4) * 76 + 12) * win.uiScale
		radius: 14 * win.uiScale
		color: Theme.bgExpanded
		Grid {
			anchors.fill: parent
			anchors.margins: 6 * win.uiScale
			columns: 4
			Repeater {
				model: Audio.mixerRows.slice(0, 12)
				delegate: Item {
					required property var modelData
					width: 73 * win.uiScale
					height: 76 * win.uiScale
					Text { anchors.centerIn: parent; width: parent.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: parent.modelData.name + "\n" + Math.round(parent.modelData.volume * 100) + "%"; color: Theme.text; font.pixelSize: 10 * win.uiScale }
					MouseArea { anchors.fill: parent; onClicked: Audio.toggleStreamMute(parent.modelData.id); onWheel: wheel => Audio.setStreamVolume(parent.modelData.id, parent.modelData.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)) }
				}
			}
		}
	}
}
