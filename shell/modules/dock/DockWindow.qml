import QtQuick
import Quickshell
import Quickshell.Wayland
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
	readonly property alias view: view
	readonly property string _key: "dock-" + win.modelData.name

	screen: win.modelData
	anchors.bottom: true
	anchors.left: true
	anchors.right: true
	implicitHeight: Tokens.dock.surfaceHeight
	color: "transparent"
	exclusiveZone: view.mode === "fixed" && view.userVisible ? Math.round(Tokens.dock.reserve * view.uiScale) : 0
	WlrLayershell.namespace: "bloom:dock"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: view.keyboardWanted ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

	mask: Region {
		item: view.bandActive ? view.bandItem : (view.hidden ? null : view.hitItem)
		Region { item: view.grabWanted ? view.menuItem : null }
		Region { item: view.grabWanted ? view.popupItem : null }
	}

	Loader {
		id: workspaces
		active: HyprState.available && Settings.values["bloom-dock-workspaces-enabled"]
		source: "../notch/WorkspaceData.qml"
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
		edgeDelay: Settings.values["bloom-dock-edge-delay"]
		uiScale: Settings.values["bloom-scale"]
		iconOnly: Settings.values["bloom-dock-icon-only"]
		separatorEnabled: Settings.values["bloom-dock-separator-enabled"]
		adaptiveEnabled: Settings.values["bloom-dock-adaptive"]
		overlapped: win._overlapped
		maximized: Logic.maximized(win._focused)
		items: Dock.items
		workspaceCells: workspaces.item ? Logic.workspaceCells(workspaces.item.workspaces, workspaces.item.workspace?.id ?? 0) : []
		menuTarget: id => Dock.menuTarget(id)
		apps: Apps.all()
		appsLoading: Apps.revision === 0
		bg: Theme.bg
		bgExpanded: Theme.bgExpanded
		border: Theme.border
		groupBg: Theme.groupBg
		textMuted: Theme.textMuted
		accent: Theme.accent
		textColor: Theme.text
		light: Theme.isLight
		tooltipBg: Theme.isLight ? Theme.bgExpanded : Qt.rgba(0, 0, 0, Tokens.dock.tooltip.alpha)
		tooltipText: Theme.text
		tooltipBorder: Theme.border
		onActivated: id => Dock.activate(id)
		onNewInstance: id => Dock.newInstance(id)
		toastMessage: Dock.toast
		toastSerial: Dock.toastSerial
		onReordered: ids => Dock.reorder(ids)
		onMenuChosen: (id, key) => Dock.runMenu(id, key)
		onPinRequested: id => Dock.pin(id)
		onSwitchWorkspace: cell => cell.id > 0 ? Dock.switchWorkspace(cell.id) : Dock.switchWorkspaceNamed(cell.tip)
		onStepWorkspace: dir => Dock.stepWorkspace(dir, view.workspaceCells)
		onHideWorkspaces: Settings.set("bloom-dock-workspaces-enabled", false)
	}
}
