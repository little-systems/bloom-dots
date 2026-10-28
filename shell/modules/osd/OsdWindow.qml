import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "../../common"
import "../../common/screens.js" as Screens

// One edge pill on one screen. Only its narrow hover target stays interactive
// while the card is hidden; the rest of the transparent layer passes input on.
PanelWindow {
	id: win
	required property var modelData
	required property string edge
	property bool shown: false
	property bool mixerOpen: false
	property bool showPercentage: false
	readonly property bool pointerOverCard: edgeArea.containsMouse || cardHover.hovered || mixerHover.hovered
	readonly property real uiScale: Settings.values["bloom-scale"]
	readonly property bool targetScreen: Screens.isTarget(modelData, HyprState.monitors, Quickshell.screens)
	readonly property int mixerCount: Math.min(12, Audio.mixerRows.length)
	readonly property int mixerColumns: Math.max(1, Math.min(4, mixerCount))
	readonly property real mixerWidth: Math.max(204, mixerColumns * 73 + 12) * uiScale

	function show() {
		if (!win.targetScreen || (win.edge === "right" && !Brightness.available)) return false;
		win.shown = true;
		hoverHideTimer.stop();
		if (!win.pointerOverCard && !win.mixerOpen) hideTimer.restart();
		return true;
	}
	function keepOpen() {
		if (!win.targetScreen || (win.edge === "right" && !Brightness.available)) return;
		win.shown = true;
		hideTimer.stop();
		hoverHideTimer.stop();
	}
	function leaveCard() {
		// Wait until Qt has delivered hover to a neighbouring item.
		Qt.callLater(() => {
			if (win.shown && !win.pointerOverCard) {
				hoverHideTimer.interval = win.mixerOpen ? 700 : 1500;
				hoverHideTimer.restart();
			}
		});
	}
	function stateObject() {
		return { edge: edge, screen: modelData.name, shown: shown, mixerOpen: mixerOpen,
			width: 42 * uiScale, height: 196 * uiScale,
			backlightAvailable: edge === "right" && Brightness.available };
	}

	screen: modelData
	anchors.top: true
	anchors.bottom: true
	anchors.left: edge === "left"
	anchors.right: edge === "right"
	implicitWidth: Math.ceil((edge === "left" ? 360 : 42) * uiScale)
	color: "transparent"
	// Stay mapped so the transparent edge target can receive pointer hover.
	visible: targetScreen && (edge === "left" || Brightness.available)
	exclusiveZone: 0
	WlrLayershell.namespace: "bloom:osd-" + edge
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
	mask: Region {
		item: edgeTarget
		Region { item: win.shown ? pill : null }
		Region { item: win.shown && win.mixerOpen ? mixer : null }
	}

	Timer {
		id: hideTimer
		interval: Settings.values["bloom-osd-timeout"]
		onTriggered: if (!win.pointerOverCard && !win.mixerOpen) win.shown = false
	}
	Timer {
		id: hoverHideTimer
		interval: 1500
		onTriggered: if (!win.pointerOverCard) { win.mixerOpen = false; win.shown = false; }
	}
	Timer { id: percentageTimer; interval: 700; onTriggered: win.showPercentage = false }
	Connections {
		target: Audio
		function onOutputChanged() {
			if (win.edge !== "left") return;
			win.show();
			win.showPercentage = true;
			percentageTimer.restart();
		}
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
		MouseArea {
			id: edgeArea
			anchors.fill: parent
			hoverEnabled: true
			onEntered: win.keepOpen()
			onExited: win.leaveCard()
		}
	}

	EdgeSurface {
		id: pill
		edge: win.edge
		pillWidth: 42 * win.uiScale
		pillHeight: 196 * win.uiScale
		flares: win.shown
		color: Theme.bg
		opacity: win.shown ? Theme.bg.a : 0
		x: win.edge === "right" ? win.width - width : 0
		y: Math.round((win.height - height) / 2)
		Behavior on opacity { NumberAnimation { duration: 180 } }
		HoverHandler {
			id: cardHover
			onHoveredChanged: {
				if (hovered) win.keepOpen();
				else win.leaveCard();
			}
		}
		Item {
			x: 0
			y: pill.pillRect.y
			width: pill.pillRect.width
			height: pill.pillRect.height
			visible: win.shown
			// Bloom's original puts the slider above the action or sun icon.
			Rectangle {
				id: rail
				x: (parent.width - width) / 2
				y: 16 * win.uiScale
				width: 10 * win.uiScale
				height: (win.edge === "left" ? 144 : 136) * win.uiScale
				radius: width / 2
				color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.2)
				clip: true
				Rectangle {
					anchors.bottom: parent.bottom
					width: parent.width
					height: parent.height * Math.max(0, Math.min(1, win.edge === "left" ? (Audio.muted ? 0 : Audio.volume) : Brightness.percent / 100))
					radius: width / 2
					color: Theme.text
					Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
				}
			}
			MouseArea {
				x: rail.x - 8 * win.uiScale
				y: rail.y
				width: rail.width + 16 * win.uiScale
				height: rail.height
				cursorShape: Qt.PointingHandCursor
				function apply(mouseY) {
					const value = Math.max(0, Math.min(1, (height - mouseY) / height));
					if (win.edge === "left") Audio.setVolume(value);
					else Brightness.setPercent(value * 100);
				}
				onPressed: mouse => apply(mouse.y)
				onPositionChanged: mouse => { if (pressed) apply(mouse.y); }
			}
			Item {
				x: (parent.width - width) / 2
				y: 162 * win.uiScale
				width: 24 * win.uiScale
				height: 20 * win.uiScale
				SvgIcon {
					anchors.centerIn: parent
					name: win.edge === "left" ? (Audio.muted ? "sf-speaker.slash.fill" : "sf-speaker.wave.2.fill") : "sun"
					color: Theme.text
					size: (win.edge === "left" ? 16 : 20) * win.uiScale
					visible: win.edge === "right" || (!win.showPercentage && !actionHover.hovered && !win.mixerOpen)
					transform: Rotation {
						origin.x: 10 * win.uiScale
						origin.y: 10 * win.uiScale
						angle: win.edge === "right" ? Brightness.percent * 1.8 : 0
						Behavior on angle { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
					}
				}
				SvgIcon {
					anchors.centerIn: parent
					name: "sliders-horizontal"
					color: Theme.text
					size: 16 * win.uiScale
					visible: win.edge === "left" && !win.showPercentage && (actionHover.hovered || win.mixerOpen)
				}
				Text {
					anchors.centerIn: parent
					visible: win.edge === "left" && win.showPercentage
					text: (Audio.muted ? 0 : Math.round(Audio.volume * 100)) + "%"
					color: Theme.text
					font.pixelSize: 10 * win.uiScale
					font.bold: true
				}
				HoverHandler { id: actionHover; enabled: win.edge === "left" }
				MouseArea {
					anchors.fill: parent
					enabled: win.edge === "left"
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: {
						win.mixerOpen = !win.mixerOpen;
						if (win.mixerOpen) { win.shown = true; hideTimer.stop(); hoverHideTimer.stop(); }
						else if (!win.pointerOverCard) hoverHideTimer.restart();
					}
				}
			}
		}
	}

	Rectangle {
		id: mixer
		visible: win.edge === "left" && win.mixerOpen
		x: 42 * win.uiScale
		y: Math.round((win.height - height) / 2)
		width: win.mixerWidth
		height: 196 * win.uiScale
		topRightRadius: 18 * win.uiScale
		bottomRightRadius: 18 * win.uiScale
		color: Theme.bg
		HoverHandler {
			id: mixerHover
			onHoveredChanged: {
				if (hovered) win.keepOpen();
				else win.leaveCard();
			}
		}
		Grid {
			anchors.fill: parent
			anchors.leftMargin: 8 * win.uiScale
			anchors.rightMargin: 8 * win.uiScale
			anchors.topMargin: 16 * win.uiScale
			anchors.bottomMargin: 14 * win.uiScale
			columns: win.mixerColumns
			rowSpacing: 4 * win.uiScale
			columnSpacing: 4 * win.uiScale
			Repeater {
				model: Audio.mixerRows.slice(0, 12)
				delegate: Item {
					required property var modelData
					width: (mixer.width - 16 * win.uiScale) / win.mixerColumns - 4 * win.uiScale
					height: (mixer.height - 30 * win.uiScale) / Math.max(1, Math.ceil(win.mixerCount / win.mixerColumns)) - 4 * win.uiScale
					Rectangle {
						id: streamRail
						anchors.horizontalCenter: parent.horizontalCenter
						width: 10 * win.uiScale
						height: parent.height - 24 * win.uiScale
						radius: width / 2
						color: Theme.isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.2)
						clip: true
						Rectangle {
							anchors.bottom: parent.bottom
							width: parent.width
							height: parent.height * (modelData.muted ? 0 : Math.max(0, Math.min(1, modelData.volume)))
							radius: width / 2
							color: Theme.text
						}
					}
					MouseArea {
						x: streamRail.x - 8 * win.uiScale
						y: streamRail.y
						width: streamRail.width + 16 * win.uiScale
						height: streamRail.height
						cursorShape: Qt.PointingHandCursor
						function apply(mouseY) { Audio.setStreamVolume(modelData.id, Math.max(0, Math.min(1, (height - mouseY) / height))); }
						onPressed: mouse => apply(mouse.y)
						onPositionChanged: mouse => { if (pressed) apply(mouse.y); }
					}
					Rectangle {
						anchors.horizontalCenter: parent.horizontalCenter
						anchors.bottom: parent.bottom
						width: 20 * win.uiScale
						height: 20 * win.uiScale
						radius: 5 * win.uiScale
						color: Theme.groupBg
						Image {
							id: streamIcon
							anchors.centerIn: parent
							width: 18 * win.uiScale
							height: 18 * win.uiScale
							source: modelData.iconName ? Quickshell.iconPath(modelData.iconName, true) : ""
							visible: status === Image.Ready
							opacity: modelData.muted ? 0.35 : 1
							fillMode: Image.PreserveAspectFit
						}
						Text {
							anchors.centerIn: parent
							text: modelData.name.slice(0, 1).toUpperCase()
							color: Theme.text
							font.pixelSize: 10 * win.uiScale
							font.bold: true
							visible: !streamIcon.visible
						}
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Audio.toggleStreamMute(modelData.id) }
					}
				}
			}
		}
		Text { anchors.centerIn: parent; visible: Audio.mixerRows.length === 0; text: "No apps with audio"; color: Theme.textMuted; font.pixelSize: 11 * win.uiScale }
	}
}
