import QtQuick
import Quickshell
import qs.services
import "../../services/devices.js" as Devices

// The Bluetooth panel: binds BluetoothView to BlueZ. "Looks like" picks are
// saved in bloom-device-looks, shared with Connected devices and the device
// alerts. The footer opens Blueman or KDE's Bluetooth settings when one is
// installed (owner decision 2, 2026-10-29) and is hidden otherwise.
BluetoothView {
	id: root

	signal subpanelRequested(string name)

	readonly property var _looks: Devices.parseLooks(Settings.values["bloom-device-looks"])
	readonly property string _tool: (Apps.revision, ["blueman-manager", "kcm_bluetooth"].find(id => DesktopEntries.byId(id) !== null) ?? "")

	theme: Theme
	enabled: Bluetooth.powered
	available: Bluetooth.available
	devices: Bluetooth.paired
	nearby: Bluetooth.nearby
	busy: Bluetooth.busy
	pairing: Bluetooth.pairing
	prompt: Bluetooth.prompt
	error: Bluetooth.lastError
	looks: root._looks
	settingsAvailable: root._tool !== ""

	Component.onCompleted: {
		Bluetooth.clearError();
		Bluetooth.hold("bluetooth-panel", true);
	}
	Component.onDestruction: {
		Bluetooth.discover(false);
		Bluetooth.hold("bluetooth-panel", false);
	}

	onBack: root.subpanelRequested("command-center")
	onToggle: Bluetooth.setPowered(!Bluetooth.powered)
	onDiscover: active => Bluetooth.discover(active)
	onPairRequested: path => Bluetooth.pair(path)
	onRespond: (accept, pin) => Bluetooth.respond(accept, pin)
	onConnectRequested: (path, connected) => Bluetooth.setConnected(path, connected)
	onRemoveRequested: path => Bluetooth.unpair(path)
	onErrorCleared: Bluetooth.clearError()
	onOpenSettings: Apps.launch(root._tool)
	onLookChosen: (name, art) => {
		const next = Object.assign({}, root._looks);
		if (art)
			next[name] = art;
		else
			delete next[name];
		Settings.set("bloom-device-looks", JSON.stringify(next));
	}
}
