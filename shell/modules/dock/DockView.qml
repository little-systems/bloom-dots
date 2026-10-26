import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "dock.js" as Dock

// Bloom's dock (Dock.tsx @ b5fb962): a bottom-edge pill that drops in, then
// expands into the app row; fixed/smart/peek modes with an edge reveal and
// an adaptive full width. Pure UI: DockWindow feeds it items and overlap.
Item {
	id: root

	property string mode: "smart"
	property int edgeDelay: 200
	property real uiScale: 1
	property bool overlapped: false
	property bool maximized: false
	property bool adaptiveEnabled: false
	property bool userVisible: true
	property bool suppressed: false
	property bool iconOnly: false
	property bool separatorEnabled: true
	property var items: ({ pinned: [], unpinned: [] })
	property color bg: Qt.rgba(0, 0, 0, 0.8)
	property color textColor: "white"
	property color tooltipBg: Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
	property color tooltipText: "white"
	property color tooltipBorder: "transparent"
	property bool light: false

	signal activated(string id)
	signal newInstance(string id)

	property bool ready: false
	property bool impacted: false
	property bool expanded: false
	property bool startupAnimating: false
	property bool edgeArmed: false
	property string interaction: "none"

	readonly property bool pillHovered: pillHover.hovered
	readonly property bool hidden: Dock.isHidden(root.mode, root.overlapped, root.interaction, root.startupAnimating)
	readonly property real naturalWidth: root._layout.width + 2 * Tokens.dock.padding
	readonly property bool adaptive: root.adaptiveEnabled && root.mode === "fixed" && root.maximized
		&& root.expanded && !root.hidden && root.userVisible
	readonly property var target: Dock.geometry({
		ready: root.ready, visible: root.userVisible, hidden: root.hidden, expanded: root.expanded,
		impacted: root.impacted, contentWidth: root.naturalWidth, adaptive: root.adaptive,
		adaptiveWidth: Dock.adaptiveWidth(root.width, root.uiScale)
	})
	readonly property bool bandActive: root.hidden && root.mode !== "fixed" && root.userVisible && !root.suppressed
	readonly property Item hitItem: pillArea
	readonly property Item bandItem: band

	function stateObject() {
		return {
			mode: root.mode, hidden: root.hidden, interaction: root.interaction, overlapped: root.overlapped,
			visible: root.userVisible, expanded: root.expanded, adaptive: root.adaptive,
			width: root.target.width, height: root.target.height, y: root.target.y,
			keys: root._rows.map(r => r.key)
		};
	}

	// Startup (Bloom: impacted at 280 ms, expanded at 350 ms, done at 1500 ms).
	onReadyChanged: {
		if (!root.ready)
			return;
		root.startupAnimating = true;
		impactTimer.restart();
		expandTimer.restart();
		startupTimer.restart();
	}
	Timer { id: impactTimer; interval: Tokens.dock.startup.impactMs; onTriggered: root.impacted = true }
	Timer { id: expandTimer; interval: Tokens.dock.startup.expandMs; onTriggered: root.expanded = true }
	Timer { id: startupTimer; interval: Tokens.dock.startup.animatingMs; onTriggered: root.startupAnimating = false }

	// Interaction and its 800 ms grace (Bloom interactionState).
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
	Timer { id: graceTimer; interval: Tokens.dock.graceMs; onTriggered: root.interaction = "none" }

	// An edge reveal lets go once the pointer reaches the pill, or after the
	// hand-off time if it never does (Wayland reports hover only on movement).
	onBandActiveChanged: if (!root.bandActive && root.edgeArmed) handoff.restart()
	onPillHoveredChanged: if (root.pillHovered) { handoff.stop(); root.edgeArmed = false; }
	Timer { id: handoff; interval: Tokens.dock.edgeHandoffMs; onTriggered: root.edgeArmed = false }

	// Slots: the row's items with framer AnimatePresence. A leaving slot keeps
	// its place until its exit has played (exitMs), then the row closes up.
	ListModel { id: slotModel }
	property var _rows: []
	property var _leftAt: ({})
	property var _layout: ({ xs: [], width: 0 })

	function _sync() {
		const next = Dock.slots(root.items, root.separatorEnabled);
		const byKey = {};
		for (const s of next)
			byKey[s.key] = s;
		const now = Date.now();
		// Bloom: a pinned item's exit waits 150 ms then springs; a running
		// app's exit is a 120 ms tween with no delay.
		const holdOf = key => {
			for (let k = 0; k < slotModel.count; k++)
				if (slotModel.get(k).key === key)
					return slotModel.get(k).pinned ? Tokens.dock.exitMs : Tokens.dock.quickExitHoldMs;
			return Tokens.dock.exitMs;
		};
		const expired = root._rows
			.filter(r => r.key === Dock.dividerKey || (r.leaving && root._leftAt[r.key] && now - root._leftAt[r.key].at >= root._leftAt[r.key].ms))
			.map(r => r.key);
		const rows = Dock.reconcile(root._rows, next.map(s => s.key), expired);
		const leftAt = {};
		for (const r of rows)
			if (r.leaving)
				leftAt[r.key] = root._leftAt[r.key] ?? { at: now, ms: holdOf(r.key) };
		const lay = Dock.layout(rows.map(r => r.key));
		// Positions are relative to the row's centre (the pill's centre), so a
		// width change moves no one until each slot's layout spring runs.
		const xs = lay.xs.map(x => x - lay.width / 2);
		if (JSON.stringify(lay) !== JSON.stringify(root._layout))
			root._layout = lay;

		for (let i = slotModel.count - 1; i >= 0; i--)
			if (!rows.some(r => r.key === slotModel.get(i).key))
				slotModel.remove(i);
		rows.forEach((r, i) => {
			let j = -1;
			for (let k = 0; k < slotModel.count; k++)
				if (slotModel.get(k).key === r.key) { j = k; break; }
			const s = byKey[r.key];
			if (j < 0) {
				slotModel.insert(i, { key: r.key, kind: s.kind, pinned: s.pinned, name: s.name, icon: s.icon, windows: s.windows, present: true, slotX: xs[i] });
				return;
			}
			if (j !== i)
				slotModel.move(j, i, 1);
			if (s) {
				if (slotModel.get(i).pinned !== s.pinned) slotModel.setProperty(i, "pinned", s.pinned);
				if (slotModel.get(i).name !== s.name) slotModel.setProperty(i, "name", s.name);
				if (slotModel.get(i).icon !== s.icon) slotModel.setProperty(i, "icon", s.icon);
				if (slotModel.get(i).windows !== s.windows) slotModel.setProperty(i, "windows", s.windows);
			}
			if (slotModel.get(i).present !== !r.leaving) slotModel.setProperty(i, "present", !r.leaving);
			if (slotModel.get(i).slotX !== xs[i]) slotModel.setProperty(i, "slotX", xs[i]);
		});

		root._rows = rows;
		root._leftAt = leftAt;
		const waits = Object.keys(leftAt).map(k => leftAt[k].at + leftAt[k].ms - now);
		if (waits.length > 0) {
			exitTimer.interval = Math.max(1, Math.min.apply(null, waits));
			exitTimer.restart();
		}
	}
	onItemsChanged: root._sync()
	onSeparatorEnabledChanged: root._sync()
	Component.onCompleted: root._sync()
	Timer { id: exitTimer; onTriggered: root._sync() }

	Spring {
		id: wS
		stiffness: Tokens.springs.dockSize.stiffness
		damping: Tokens.springs.dockSize.damping
		mass: Tokens.springs.dockSize.mass
		initial: Tokens.dock.collapsed
		target: root.target.width
	}
	Spring {
		id: hS
		stiffness: Tokens.springs.dockSize.stiffness
		damping: Tokens.springs.dockSize.damping
		mass: Tokens.springs.dockSize.mass
		initial: Tokens.dock.collapsed
		target: root.target.height
	}
	Spring {
		id: yS
		stiffness: Tokens.springs.dockY.stiffness
		damping: Tokens.springs.dockY.damping
		mass: Tokens.springs.dockY.mass
		initial: -800
		target: root.target.y
	}
	Spring {
		id: edgeR
		stiffness: Tokens.springs.dockRadius.stiffness
		damping: Tokens.springs.dockRadius.damping
		initial: 17
		target: root.target.edgeRadius
	}
	Spring {
		id: farR
		stiffness: Tokens.springs.dockRadius.stiffness
		damping: Tokens.springs.dockRadius.damping
		initial: 17
		target: root.target.farRadius
	}

	Item {
		id: stage
		anchors.fill: parent
		scale: root.uiScale
		transformOrigin: Item.Bottom

		Item {
			id: pillLayer
			anchors.fill: parent
			opacity: root.target.opacity
			Behavior on opacity {
				NumberAnimation { duration: Tokens.dock.opacityMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
			}

			EdgeSurface {
				x: (stage.width - width) / 2
				y: stage.height - height + yS.value
				edge: "bottom"
				pillWidth: Math.max(0, wS.value)
				pillHeight: Math.max(0, hS.value)
				edgeRadius: edgeR.value
				farRadius: farR.value
				flares: root.expanded && !root.hidden
				color: root.bg
			}
		}

		// The pill's box: hover, input mask and the app row.
		Item {
			id: pillArea
			x: (stage.width - width) / 2
			y: stage.height - height + yS.value
			width: Math.max(0, wS.value)
			height: Math.max(0, hS.value)
			opacity: pillLayer.opacity

			HoverHandler { id: pillHover }

			Item {
				id: row
				// Slots sit relative to the pill's centre (see _sync).
				x: pillArea.width / 2
				y: Tokens.dock.padding
				width: 0
				height: Tokens.dock.iconBox
				opacity: root.expanded ? 1 : 0
				Behavior on opacity {
					NumberAnimation { duration: Tokens.dock.contentFadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: [0, 0, 0.58, 1, 1, 1] }
				}

				Repeater {
					model: slotModel

					delegate: Item {
						id: slot
						objectName: "dock-slot-" + slot.key
						required property string key
						required property string kind
						required property bool pinned
						required property string name
						required property string icon
						required property int windows
						required property bool present
						required property real slotX

						x: xSpring.value
						width: slot.kind === "divider" ? 5 : Tokens.dock.iconBox
						height: Tokens.dock.iconBox
						z: icon.hovered ? 1 : 0

						Spring {
							id: xSpring
							stiffness: Tokens.springs.dockLayout.stiffness
							damping: Tokens.springs.dockLayout.damping
							initial: slot.slotX
							target: slot.slotX
						}

						Rectangle {
							visible: slot.kind === "divider"
							x: Tokens.dock.divider.margin
							anchors.verticalCenter: parent.verticalCenter
							width: Tokens.dock.divider.width
							height: Tokens.dock.divider.height
							radius: 1
							color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, Tokens.dock.divider.alpha)
						}

						DockIcon {
							id: icon
							anchors.fill: parent
							visible: slot.kind === "app"
							name: slot.name
							iconSource: slot.icon
							windows: slot.windows
							present: slot.present && root.expanded
							quickExit: !slot.pinned
							iconOnly: root.iconOnly
							light: root.light
							textColor: root.textColor
							tooltipBg: root.tooltipBg
							tooltipText: root.tooltipText
							tooltipBorder: root.tooltipBorder
							onClicked: root.activated(slot.key)
							onMiddleClicked: root.newInstance(slot.key)
						}
					}
				}
			}
		}

		// Reveal band: a 2 px strip across the resting dock (Wayland only
		// senses the pointer inside our input region).
		Item {
			id: band
			x: (stage.width - width) / 2
			y: stage.height - height
			width: root.naturalWidth
			height: Tokens.dock.edgeBand.height
			HoverHandler { id: bandHover }
			Timer {
				interval: root.edgeDelay
				running: root.bandActive && bandHover.hovered
				onTriggered: root.edgeArmed = true
			}
		}
	}
}
