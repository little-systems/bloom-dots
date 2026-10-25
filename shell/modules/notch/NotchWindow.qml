import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import "."
import "../../common/tokens.js" as Tokens
import "notch.js" as Logic

// One notch per screen: a fixed-size top layer surface (it never resizes,
// spec §3.3) whose input mask is the pill, or the edge band while hidden.
// Feeds NotchView from the services and computes smart-mode overlap.
PanelWindow {
	id: win

	required property var modelData
	readonly property alias view: view
	readonly property string _key: "notch-" + win.modelData.name

	screen: win.modelData
	anchors.top: true
	exclusiveZone: 0
	implicitWidth: Tokens.notch.surface.width
	implicitHeight: Tokens.notch.surface.height
	color: "transparent"
	WlrLayershell.namespace: "bloom:notch"
	WlrLayershell.layer: WlrLayer.Top
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

	mask: Region {
		item: view.hidden ? null : view.hitItem
		Region { item: view.bandActive ? view.bandItem : null }
	}

	readonly property var _monitor: HyprState.monitors.find(m => m.name === win.modelData.name) ?? null
	readonly property bool _overlapped: view.mode === "smart" && win._monitor !== null
		&& Logic.overlaps(Logic.focusedWindow(HyprState.clients, win._monitor),
			Logic.notchRect(win._monitor, Logic.statusWidth(false, view.widgetCount, 0, view.use24h), view.uiScale))

	readonly property bool _wantsHypr: view.mode === "smart"
	on_WantsHyprChanged: HyprState.hold(win._key, win._wantsHypr)
	Component.onCompleted: {
		HyprState.hold(win._key, win._wantsHypr);
		readyTimer.start();
	}
	Component.onDestruction: {
		HyprState.hold(win._key, false);
		SystemStats.hold(win._key, false);
	}

	// Let the surface map before the drop-in starts.
	Timer {
		id: readyTimer
		interval: 50
		onTriggered: view.ready = true
	}

	Timer {
		interval: 1000
		repeat: true
		running: true
		onTriggered: view.now = new Date()
	}

	NotchView {
		id: view
		anchors.fill: parent
		mode: Settings.values["bloom-notch-mode"]
		edgeDelay: Settings.values["bloom-notch-edge-delay"]
		widgets: Settings.values["bloom-status-widgets"]
		use24h: Settings.values["bloom-time-format-24h"]
		uiScale: Settings.values["bloom-scale"]
		overlapped: win._overlapped
		bg: Theme.bg
		bgExpanded: Theme.bgExpanded
		textColor: Theme.text
		textMuted: Theme.textMuted
		weather: ({ shown: Weather.shown, label: Weather.label, icon: Weather.icon, tooltip: Weather.tooltip })
		battery: ({ available: Battery.available, level: Battery.level, charging: Battery.charging, threshold: Battery.threshold, tooltip: Battery.tooltip })
		stats: ({ cpu: SystemStats.cpu, ram: SystemStats.ram, disk: SystemStats.disk, up: SystemStats.up, down: SystemStats.down })
		onStatsWanted: wanted => SystemStats.hold(win._key, wanted)
	}
}
