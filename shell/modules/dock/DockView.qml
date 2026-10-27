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
	property var workspaceCells: []
	property var menuTarget: id => ({ kind: "background" })
	property var apps: []
	property var pinnedIds: []
	property bool appsLoading: false
	property string toastMessage: ""
	property int toastSerial: 0
	property color bg: Qt.rgba(0, 0, 0, 0.8)
	property color bgExpanded: root.bg
	property color border: "transparent"
	property color groupBg: Qt.rgba(1, 1, 1, 0.06)
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property color accent: "#007aff"
	property color textColor: "white"
	property color tooltipBg: Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
	property color tooltipText: "white"
	property color tooltipBorder: "transparent"
	property bool light: false

	signal activated(string id)
	signal newInstance(string id)
	signal reordered(var ids)
	signal menuChosen(string id, string key)
	signal pinRequested(string id)
	signal switchWorkspace(var cell)
	signal stepWorkspace(int dir)
	signal hideWorkspaces()

	readonly property bool keyboardWanted: popup.opened
	readonly property bool grabWanted: menu.opened || popup.opened
	readonly property Item menuItem: menu
	readonly property Item popupItem: popup

	function openAddApp() { menu.close(); popup.open(); }
	function closeMenus() { menu.close(); popup.close(); }
	function _openMenu(id, target, x, y) {
		popup.close();
		menu.forId = id;
		menu.entries = Dock.menuFor(target);
		const p = stage.mapFromItem(null, x, y);
		menu.openAt(p.x, p.y);
	}

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
	property string _dragKey: ""
	property real _dragOrigin: 0
	property real _dragX: 0
	property var _dragOrder: []

	function _pinnedKeys() {
		return root._rows.map(r => r.key).filter(k => (root.items.pinned || []).some(i => i.id === k));
	}

	function _dragStart(key, x) {
		root._dragKey = key;
		root._dragOrigin = x;
		root._dragX = x;
		root._dragOrder = root._pinnedKeys();
	}

	function _dragMove(dx) {
		root._dragX = root._dragOrigin + dx;
		const others = root._dragOrder.filter(k => k !== root._dragKey);
		const centre = k => {
			const row = root._rows.findIndex(r => r.key === k);
			return slotModel.get(row).slotX + Tokens.dock.iconBox / 2;
		};
		const index = Dock.reorderIndex(others.map(centre), root._dragX + Tokens.dock.iconBox / 2);
		const next = Dock.moveKey(root._dragOrder, root._dragKey, index);
		if (JSON.stringify(next) !== JSON.stringify(root._dragOrder)) {
			root._dragOrder = next;
			root._sync();
		}
	}

	function _dragEnd() {
		const order = root._dragOrder;
		const before = (root.items.pinned || []).map(i => i.id);
		root._dragKey = "";
		root._dragOrder = [];
		if (JSON.stringify(order) !== JSON.stringify(before))
			root.reordered(order);
		root._sync();
	}

	function _sync() {
		const ordered = root._dragOrder.length > 0
			? Object.assign({}, root.items, { pinned: root._dragOrder.map(id => root.items.pinned.find(i => i.id === id)).filter(Boolean) })
			: root.items;
		const next = Dock.slots(ordered, root.separatorEnabled, root.workspaceCells);
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
			.filter(r => r.key.startsWith(Dock.dividerKey) || (r.leaving && root._leftAt[r.key] && now - root._leftAt[r.key].at >= root._leftAt[r.key].ms))
			.map(r => r.key);
		const rows = Dock.reconcile(root._rows, next.map(s => s.key), expired);
		const leftAt = {};
		for (const r of rows)
			if (r.leaving)
				leftAt[r.key] = root._leftAt[r.key] ?? { at: now, ms: holdOf(r.key) };
		const lay = Dock.layout(rows.map(r => r.key), root.workspaceCells.length);
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
	onWorkspaceCellsChanged: root._sync()
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
					id: slotRepeater
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

						x: root._dragKey === slot.key ? root._dragX : xSpring.value
						width: Dock._width(slot.key, root.workspaceCells.length)
						height: Tokens.dock.iconBox
						z: root._dragKey === slot.key ? 3 : icon.hovered ? 1 : 0

						DragHandler {
							id: drag
							enabled: slot.kind === "app" && slot.pinned && root.expanded
							xAxis.enabled: true
							yAxis.enabled: false
							target: null
							onActiveChanged: {
								if (drag.active) root._dragStart(slot.key, slot.x);
								else if (root._dragKey === slot.key) root._dragEnd();
							}
							onTranslationChanged: if (drag.active) root._dragMove(drag.translation.x)
						}

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
							dragging: root._dragKey === slot.key
							anyDragging: root._dragKey !== ""
							iconOnly: root.iconOnly
							light: root.light
							textColor: root.textColor
							tooltipBg: root.tooltipBg
							tooltipText: root.tooltipText
							tooltipBorder: root.tooltipBorder
							onClicked: root.activated(slot.key)
							onMiddleClicked: root.newInstance(slot.key)
						}

						WorkspaceSegment {
							visible: slot.kind === "workspaces"
							cells: root.workspaceCells
							iconOnly: root.iconOnly
							light: root.light
							textColor: root.textColor
							tooltipBg: root.tooltipBg
							tooltipText: root.tooltipText
							onSwitchTo: cell => root.switchWorkspace(cell)
							onStep: dir => root.stepWorkspace(dir)
							onMenuRequested: (x, y) => {}
						}
					}
				}
			}
			TapHandler {
				acceptedButtons: Qt.RightButton
				onTapped: eventPoint => {
					const local = eventPoint.position;
					const p = pillArea.mapToItem(null, local.x, local.y);
					for (let i = 0; i < slotRepeater.count; i++) {
						const slot = slotRepeater.itemAt(i);
						if (!slot || !slot.present || slot.kind === "divider") continue;
						const hit = slot.mapFromItem(pillArea, local.x, local.y);
						if (hit.x >= 0 && hit.x < slot.width && hit.y >= 0 && hit.y < slot.height) {
							const target = slot.kind === "workspaces" ? { kind: "workspaces" } : root.menuTarget(slot.key);
							root._openMenu(slot.kind === "workspaces" ? "" : slot.key, target, p.x, p.y);
							return;
						}
					}
					root._openMenu("", { kind: "background" }, p.x, p.y);
				}
			}
		}

		Item {
			anchors.fill: parent
			z: 8
			visible: root.grabWanted
			TapHandler { onTapped: { menu.close(); popup.close(); } }
		}

		AddAppPopup {
			id: popup
			z: 9
			x: (stage.width - width) / 2
			y: pillArea.y + Tokens.dock.popup.tuck - height
			apps: root.apps
			running: (root.items.unpinned || []).filter(i => !i.id.startsWith("class:")).map(i => ({ id: i.id, name: i.name, icon: i.icon }))
			pinned: (root.items.pinned || []).map(i => i.id)
			loading: root.appsLoading
			bg: root.bgExpanded
			border: root.border
			textColor: root.textColor
			textMuted: root.textMuted
			groupBg: root.groupBg
			accent: root.accent
			onPinRequested: id => root.pinRequested(id)
		}

		DockMenu {
			id: menu
			anchors.fill: parent
			z: 10
			viewWidth: stage.width
			light: root.light
			bg: root.bgExpanded
			border: root.border
			textColor: root.textColor
			groupBg: root.groupBg
			property string forId: ""
			onChosen: key => {
				if (key === "add-app") popup.open();
				else if (key === "hide-workspaces") root.hideWorkspaces();
				else root.menuChosen(menu.forId, key);
			}
		}

		DockToast {
			id: toast
			objectName: "dock-toast"
			z: 11
			anchors.horizontalCenter: parent.horizontalCenter
			y: stage.height - Tokens.dock.toast.bottom - height
			message: root.toastMessage
			serial: root.toastSerial
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
