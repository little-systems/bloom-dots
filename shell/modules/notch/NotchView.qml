import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../services/stats.js" as Stats
import "notch.js" as Logic

// The notch (Bloom App.tsx): a pill on the screen edge that springs between
// its startup drop-in, the collapsed clock, the hovered status strip and its
// hidden state in smart and peek modes. Pure UI: NotchWindow feeds it data
// and uses hitItem/bandItem for the layer surface's input mask. Sizes are in
// unscaled px; the stage scales them from the top centre.
Item {
	id: root

	property string mode: "fixed"
	property int edgeDelay: 200
	property var widgets: ({ left: ["weather"], right: ["battery"] })
	property bool use24h: false
	property real uiScale: 1
	property bool overlapped: false
	property bool userVisible: true
	property color bg: Qt.rgba(0, 0, 0, 0.8)
	property color bgExpanded: Qt.rgba(0, 0, 0, 0.92)
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property var now: new Date()
	property var weather: ({ shown: false, label: "", icon: "thermometer", tooltip: "" })
	property var battery: ({ available: false, level: 0, charging: false, threshold: 20, tooltip: "" })
	property var stats: ({ cpu: 0, ram: 0, disk: 0, up: 0, down: 0 })
	// Set once the surface is on screen; starts the drop-in.
	property bool ready: false

	signal statsWanted(bool wanted)
	signal batteryHovered()

	property bool impacted: false
	property bool expanded: false
	property bool startupAnimating: false
	property bool edgeArmed: false
	property bool eventPeek: false
	property string interaction: "none"
	property real fitWidth: 0

	readonly property bool pillHovered: pillHover.hovered
	readonly property bool hidden: Logic.isHidden(root.mode, root.overlapped, root.interaction, root.eventPeek, root.startupAnimating)
	// Bloom isHovered: the strip opens on the shown, expanded pill.
	readonly property bool statusHover: root.pillHovered && root.expanded && !root.hidden && root.userVisible
	readonly property int widgetCount: root.widgets.left.length + root.widgets.right.length
	readonly property var target: Logic.geometry(
		{ ready: root.ready, visible: root.userVisible, hidden: root.hidden, expanded: root.expanded, impacted: root.impacted },
		{ width: Logic.statusWidth(root.statusHover, root.widgetCount, root.fitWidth, root.use24h), height: Tokens.sizes.mainRow })

	readonly property Item hitItem: pillArea
	readonly property Item bandItem: band
	// A fullscreen app on this monitor: the top edge is the app's (Bloom drops
	// its edge input while a fullscreen window is in front).
	property bool suppressed: false
	readonly property bool bandActive: root.hidden && root.mode !== "fixed" && root.userVisible && !root.suppressed

	readonly property bool _statsShown: root.statusHover && ["cpu", "ram", "disk", "net"].some(w => root.widgets.left.indexOf(w) >= 0 || root.widgets.right.indexOf(w) >= 0)
	property bool _statsHeld: false

	function peek(ms) {
		root.eventPeek = true;
		peekTimer.interval = ms;
		peekTimer.restart();
	}

	function stateObject() {
		return {
			mode: root.mode, hidden: root.hidden, hovered: root.statusHover, interaction: root.interaction,
			overlapped: root.overlapped, visible: root.userVisible,
			width: root.target.width, height: root.target.height, y: root.target.y
		};
	}

	on_StatsShownChanged: {
		root._statsHeld = root._statsShown;
		root.statsWanted(root._statsShown);
	}
	Component.onDestruction: if (root._statsHeld) root.statsWanted(false)

	onReadyChanged: {
		if (!root.ready)
			return;
		root.startupAnimating = true;
		impactTimer.restart();
		startupTimer.restart();
	}

	Timer {
		id: impactTimer
		interval: Tokens.notch.startup.impactDelayMs
		onTriggered: {
			root.impacted = true;
			root.expanded = true;
		}
	}

	Timer {
		id: startupTimer
		interval: Tokens.notch.startup.animatingMs
		onTriggered: root.startupAnimating = false
	}

	Timer {
		id: peekTimer
		onTriggered: root.eventPeek = false
	}

	// Bloom interactionState: active while hovered, then an 800 ms grace.
	readonly property bool _anyInteraction: root.pillHovered || root.edgeArmed
	on_AnyInteractionChanged: {
		if (root._anyInteraction) {
			graceTimer.stop();
			root.interaction = "active";
		} else if (root.interaction !== "none") {
			root.interaction = "grace";
			graceTimer.restart();
		}
	}

	Timer {
		id: graceTimer
		interval: Tokens.notch.graceMs
		onTriggered: root.interaction = "none"
	}

	onStatusHoverChanged: {
		if (!root.statusHover)
			root.fitWidth = 0;
		tooltip.hideNow();
	}

	// After an edge reveal the pill takes over once the pointer reaches it; if
	// it never does (no movement), the reveal lets go after the hand-off time.
	onBandActiveChanged: if (!root.bandActive && root.edgeArmed) handoff.restart()
	onPillHoveredChanged: {
		if (root.pillHovered) {
			handoff.stop();
			root.edgeArmed = false;
		}
	}

	Timer {
		id: handoff
		interval: Tokens.notch.edgeHandoffMs
		onTriggered: root.edgeArmed = false
	}

	Spring {
		id: wS
		stiffness: Tokens.springs.pillWidth.stiffness
		damping: Tokens.springs.pillWidth.damping
		mass: Tokens.springs.pillWidth.mass
		initial: Tokens.notch.startup.width
		target: root.target.width
	}

	Spring {
		id: hS
		stiffness: Tokens.springs.pillHeight.stiffness
		damping: Tokens.springs.pillHeight.damping
		mass: Tokens.springs.pillHeight.mass
		initial: Tokens.notch.startup.height
		target: root.target.height
	}

	Spring {
		id: yS
		stiffness: Tokens.springs.pillY.stiffness
		damping: Tokens.springs.pillY.damping
		mass: Tokens.springs.pillY.mass
		restDelta: Tokens.springs.pillY.restDelta
		initial: Tokens.notch.startup.y
		target: root.target.y
	}

	Spring {
		id: rS
		stiffness: Tokens.springs.radius.stiffness
		damping: Tokens.springs.radius.damping
		mass: Tokens.springs.radius.mass
		initial: Tokens.sizes.farRadius
		target: root.target.edgeRadius
	}

	Item {
		id: stage
		anchors.fill: parent
		scale: root.uiScale
		transformOrigin: Item.Top

		Item {
			id: pillLayer
			anchors.fill: parent
			opacity: root.target.opacity
			Behavior on opacity {
				NumberAnimation {
					duration: Tokens.notch.opacityMs
					easing.type: Easing.BezierSpline
					easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
				}
			}

			EdgeSurface {
				x: (stage.width - width) / 2
				y: yS.value
				edge: "top"
				pillWidth: Math.max(0, wS.value)
				pillHeight: Math.max(0, hS.value)
				edgeRadius: rS.value
				farRadius: Tokens.sizes.farRadius
				flares: root.impacted
				color: root.statusHover ? root.bgExpanded : root.bg
				Behavior on color {
					ColorAnimation {
						duration: Tokens.notch.colorFadeMs
						easing.type: Easing.BezierSpline
						easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
					}
				}
			}
		}

		// The pill's box: hover, input mask and content.
		Item {
			id: pillArea
			x: (stage.width - width) / 2
			y: yS.value
			width: Math.max(0, wS.value)
			height: Math.max(0, hS.value)
			opacity: pillLayer.opacity

			HoverHandler { id: pillHover }

			Item {
				id: mainRow
				x: Tokens.sizes.padding
				width: Math.max(0, parent.width - 2 * Tokens.sizes.padding)
				height: Tokens.sizes.mainRow
				clip: true
				opacity: root.expanded && !root.hidden ? 1 : 0
				Behavior on opacity {
					NumberAnimation {
						duration: Tokens.easing.framerDefaultMs
						easing.type: Easing.BezierSpline
						easing.bezierCurve: [0.25, 0.1, 0.35, 1, 1, 1]
					}
				}

				Row {
					id: leftGroup
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					spacing: Tokens.statusStrip.groupGap
					opacity: root.statusHover ? 1 : 0
					visible: opacity > 0
					Behavior on opacity {
						NumberAnimation {
							duration: Tokens.statusStrip.fadeMs
							easing.type: Easing.BezierSpline
							easing.bezierCurve: [0, 0, 0.58, 1, 1, 1]
						}
					}
					Repeater {
						model: root.widgets.left
						delegate: widgetDelegate
					}
				}

				Text {
					id: clock
					anchors.centerIn: parent
					text: Logic.clockText(root.now, root.use24h)
					color: clockHover.hovered ? root.textMuted : root.textColor
					Behavior on color { ColorAnimation { duration: 200 } }
					font.family: Tokens.type.family
					font.pixelSize: Tokens.type.clock.size
					font.weight: Font.Medium
					font.letterSpacing: Tokens.type.clock.tracking
					scale: clockTap.pressed ? 0.95 : 1
					Behavior on scale { NumberAnimation { duration: 100 } }
					HoverHandler { id: clockHover }
					TapHandler { id: clockTap }
				}

				Row {
					id: rightGroup
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					spacing: Tokens.statusStrip.groupGap
					opacity: leftGroup.opacity
					visible: opacity > 0
					Repeater {
						model: root.widgets.right
						delegate: widgetDelegate
					}
				}
			}
		}

		// Bloom statusFitWidth: grows during a hover so a shrinking live label
		// doesn't make the notch jitter.
		readonly property real _needed: Logic.fitWidth(clock.implicitWidth, leftGroup.implicitWidth, rightGroup.implicitWidth)
		on_NeededChanged: if (root.statusHover && stage._needed > root.fitWidth) root.fitWidth = stage._needed

		StatusTooltip {
			id: tooltip
			bg: root.bgExpanded
			textColor: root.textColor
			pillBottom: yS.value + hS.value
		}

		// Edge reveal band (Wayland stand-in for Bloom's top-edge hook).
		Item {
			id: band
			x: (stage.width - width) / 2
			y: 0
			width: Tokens.notch.edgeBand.width
			height: Tokens.notch.edgeBand.height
			enabled: root.bandActive

			HoverHandler {
				id: bandHover
				onHoveredChanged: {
					if (bandHover.hovered) {
						if (root.edgeDelay <= 0)
							root.edgeArmed = true;
						else
							dwell.restart();
					} else if (root.bandActive) {
						// A real leave while hidden. Once the notch shows, the band
						// switches off under the pointer, and that is not a leave.
						dwell.stop();
						root.edgeArmed = false;
					}
				}
			}

			Timer {
				id: dwell
				interval: Math.max(1, root.edgeDelay)
				onTriggered: root.edgeArmed = true
			}
		}
	}

	Component {
		id: widgetDelegate

		// Only widgets with data exist at all, so a missing battery leaves no
		// gap in the row (Bloom renders nothing for it).
		Loader {
			id: slot
			required property string modelData
			readonly property bool hasData: (slot.modelData === "weather" && root.weather.shown)
				|| (slot.modelData === "battery" && root.battery.available)
				|| ["cpu", "ram", "disk", "net"].indexOf(slot.modelData) >= 0
			active: slot.hasData
			visible: slot.active

			sourceComponent: StatusWidget {
				id: w
				widgetId: slot.modelData
				textColor: root.textColor
				battery: root.battery
				icon: {
					switch (slot.modelData) {
					case "weather": return root.weather.icon;
					case "cpu": return "cpu";
					case "ram": return "memory-stick";
					case "disk": return "hard-drive";
					case "net": return "arrow-up-down";
					}
					return "";
				}
				strokeWidth: slot.modelData === "weather" ? 2.2 : 2
				label: {
					switch (slot.modelData) {
					case "weather": return root.weather.label;
					case "battery": return `${root.battery.level}%`;
					case "cpu": return `${root.stats.cpu}%`;
					case "ram": return `${Math.round(root.stats.ram)}%`;
					case "disk": return `${root.stats.disk}GB`;
					case "net": return `↑${Stats.formatBytes(root.stats.up)} ↓${Stats.formatBytes(root.stats.down)}`;
					}
					return "";
				}
				readonly property string tip: {
					switch (slot.modelData) {
					case "weather": return root.weather.tooltip;
					case "battery": return root.battery.tooltip;
					case "cpu": return "CPU Usage";
					case "ram": return "RAM Usage";
					case "disk": return "Free Disk Space";
					case "net": return "Network Speed";
					}
					return "";
				}
				onHoveredChanged: {
					if (w.hovered) {
						if (slot.modelData === "battery")
							root.batteryHovered();
						tooltip.text = w.tip;
						tooltip.showFor(w);
					} else {
						tooltip.hideNow();
					}
				}
			}
		}
	}
}
