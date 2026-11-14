import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import "."
import "../../common/tokens.js" as Tokens
import "dock.js" as Logic

// One dock per screen: a full-width bottom layer surface of fixed height (it
// never resizes, spec §3.3) whose input mask is the pill, or the edge band
// while hidden. Fixed mode reserves Bloom's 56 px strip.
PanelWindow {
	id: win

	required property var modelData
	property bool sessionLocked: false
	property bool lockPreparing: false
	readonly property alias view: view
	readonly property string _key: "dock-" + win.modelData.name
	function _reportExtra(result) { if (result && result !== "ok" && !result.startsWith("pending:")) Dock.notify(result); }

	screen: win.modelData
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	implicitHeight: Tokens.dock.surfaceHeight
	color: "transparent"
	exclusiveZone: !win.sessionLocked && view.mode === "fixed" && view.userVisible ? Math.round(Tokens.dock.reserve * view.uiScale) : 0
	visible: !win.sessionLocked
	WlrLayershell.namespace: "bloom:dock"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: view.keyboardWanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	mask: Region {
		item: view.bandActive ? view.bandItem : (view.hidden ? null : view.hitItem)
		// Only the open boxes take clicks under Hyprland (its focus grab closes
		// them on an outside click). Elsewhere the whole surface catches a click
		// that closes them.
		Region { item: view.menuOpen ? (HyprState.available ? view.menuBoxItem : view) : null }
		Region { item: view.menuOpen && HyprState.available ? view.submenuBoxItem : null }
		Region { item: view.keyboardWanted ? view.popupItem : null }
		Region { item: view.previewOpen ? view.previewBoxItem : null }
		Region { item: view.confirmOpen ? (HyprState.available ? view.confirmBoxItem : view) : null }
	}

	Loader {
		id: workspaces
		active: HyprState.available && Settings.values["bloom-dock-workspaces-enabled"]
		source: "WorkspaceData.qml"
		onLoaded: workspaces.item.screen = win.modelData
	}

	Loader {
		id: grab
		active: HyprState.available
		source: "DockFocusGrab.qml"
		onLoaded: {
			grab.item.window = win;
			grab.item.active = Qt.binding(() => view.grabWanted);
		}
	}
	Connections {
		target: grab.item
		ignoreUnknownSignals: true
		function onCleared() { view.closeMenus(); }
	}
	Connections {
		target: Dock
		function onRevealRequested(ms) { view.reveal(ms); }
	}
	Connections {
		target: DockExtras
		function onToastSerialChanged() { Dock.notify(DockExtras.toast); }
	}

	readonly property var _monitor: HyprState.monitors.find(m => m.name === win.modelData.name) ?? null
	readonly property var _focused: win._monitor !== null ? Logic.focusedWindow(HyprState.clients, win._monitor) : null
	readonly property bool _overlapped: view.mode === "smart" && win._monitor !== null
		&& Logic.overlaps(win._focused, Logic.dockRect(win._monitor, view.naturalWidth, view.uiScale), view.uiScale)

	// Smart mode needs window positions every second; otherwise Hyprland's
	// events keep the window list current.
	readonly property string _hyprNeed: view.mode === "smart" ? "poll" : "events"
	on_HyprNeedChanged: HyprState.hold(win._key, win._hyprNeed)
	Component.onCompleted: {
		HyprState.hold(win._key, win._hyprNeed);
		readyTimer.start();
	}
	Component.onDestruction: HyprState.hold(win._key, "")

	Timer {
		id: readyTimer
		interval: 50
		onTriggered: view.ready = true
	}

	DockView {
		id: view
		anchors.fill: parent
		mode: Settings.values["bloom-dock-mode"]
		sessionLocked: win.sessionLocked
		lockPreparing: win.lockPreparing
		edgeDelay: Settings.values["bloom-dock-edge-delay"]
		uiScale: Settings.values["bloom-scale"]
		iconOnly: Settings.values["bloom-dock-icon-only"]
		separatorEnabled: Settings.values["bloom-dock-separator-enabled"]
		previewEnabled: Settings.values["bloom-dock-preview-enabled"]
		captureEnabled: HyprState.available
		previewSources: {
			if (!HyprState.available) return [];
			return ToplevelManager.toplevels.values.map(t => {
				const raw = t.HyprlandToplevel.address;
				return { address: raw ? (raw.startsWith("0x") ? raw : "0x" + raw) : "", toplevel: t };
			});
		}
		adaptiveEnabled: Settings.values["bloom-dock-adaptive"]
		overlapped: win._overlapped
		maximized: Logic.maximized(win._focused)
		items: Dock.items
		trayOnlyItems: Dock.trayOnly
		extraItems: DockExtras.items.map(e => Object.assign({}, e, { icon: Quickshell.iconPath(e.icon, true) }))
		extrasPosition: Settings.values["bloom-dock-extras-position"]
		workspaceCells: workspaces.item ? Logic.workspaceCells(workspaces.item.workspaces, workspaces.item.workspace?.id ?? 0) : []
		menuTarget: id => id.startsWith("extra:") ? DockExtras.menuTarget(id.slice(6)) : Dock.menuTarget(id)
		apps: Apps.all()
		appsLoading: Apps.revision === 0
		bg: Theme.bg
		bgExpanded: Theme.bgExpanded
		border: Theme.border
		groupBg: Theme.groupBg
		textMuted: Theme.textMuted
		accent: Theme.accent
		textColor: Theme.text
		edgeShine: Settings.values["bloom-edge-shine-enabled"] !== false
		light: Theme.isLight
		tooltipBg: Theme.isLight ? Theme.bgExpanded : Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
		tooltipText: Theme.text
		tooltipBorder: Theme.border
		onActivated: id => Dock.activate(id)
		onNewInstance: id => Dock.newInstance(id)
		onPreviewFocus: address => Dock.focusWindow(address)
		onPreviewClose: address => Dock.closeWindow(address)
		onExtraActivated: key => win._reportExtra(DockExtras.action(key, "open"))
		onEmptyTrashConfirmed: win._reportExtra(DockExtras.emptyTrash(true))
		onTrayActivated: (key, x, y) => Dock.trayActivate(key, win, Math.round(x), Math.round(y))
		onTraySecondary: key => Dock.traySecondary(key)
		onTrayMenuRequested: (key, x, y) => Dock.trayMenu(key, win, Math.round(x), Math.round(y))
		toastMessage: Dock.toast
		toastSerial: Dock.toastSerial
		// QML signal arguments can arrive as a Qt list rather than a JS Array.
		// Normalize at the boundary before the service validates the permutation.
		onReordered: ids => win._reportExtra(Dock.reorder(Array.from(ids)))
		onRunningReordered: ids => win._reportExtra(Dock.reorderRunning(Array.from(ids)))
		onPinReordered: (id, index) => Dock.pinAt(id, index)
		onMenuChosen: (id, key) => {
			if (!id.startsWith("extra:")) { Dock.runMenu(id, key); return; }
			const extraKey = id.slice(6);
			if (key === "empty-trash") view.confirmEmptyTrash();
			else if (key === "hide") win._reportExtra(DockExtras.hide(extraKey, error => win._reportExtra(error)));
			else if (key === "remove") win._reportExtra(DockExtras.remove(extraKey, error => win._reportExtra(error)));
			else win._reportExtra(DockExtras.action(extraKey, key));
		}
		onPinRequested: id => Dock.pin(id)
		onSwitchWorkspace: cell => cell.id > 0 ? Dock.switchWorkspace(cell.id) : Dock.switchWorkspaceNamed(cell.tip)
		onStepWorkspace: dir => Dock.stepWorkspace(dir, view.workspaceCells)
		onHideWorkspaces: Settings.set("bloom-dock-workspaces-enabled", false)
	}
}
