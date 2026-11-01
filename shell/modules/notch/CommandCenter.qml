import QtQuick
import qs.services
import "../../common/tokens.js" as Tokens

// The Command Center panel: binds CommandCenterView to the services and runs
// its actions (notification history now lives at the top-right corner).
CommandCenterView {
	id: root

	signal subpanelRequested(string name)

	function _nextMode(mode) {
		return mode === "fixed" ? "smart" : mode === "smart" ? "peek" : "fixed";
	}

	theme: Theme
	light: Theme.isLight
	wifiKnown: Network.available
	wifiEnabled: Network.wifiEnabled
	wifiConnected: Network.connected
	ssid: Network.ssid
	bluetoothPowered: Bluetooth.powered
	bluetoothNames: Bluetooth.devices.filter(d => d.connected).map(d => d.name)
	dockMode: Settings.values["bloom-dock-mode"]
	notchMode: Settings.values["bloom-notch-mode"]
	dnd: !!Settings.values["bloom-notifications-dnd"]
	energySaver: Battery.energySaver
	volume: Audio.volume
	brightness: Brightness.available ? Brightness.percent : -1

	Component.onCompleted: {
		Network.hold("command-center", true);
		Bluetooth.hold("command-center", true);
	}
	Component.onDestruction: {
		Network.hold("command-center", false);
		Bluetooth.hold("command-center", false);
	}

	onWifiToggled: Network.setWifi(!Network.wifiEnabled)
	onWifiOpened: root.subpanelRequested("wifi")
	onBluetoothToggled: Bluetooth.setPowered(!Bluetooth.powered)
	onBluetoothOpened: root.subpanelRequested("bluetooth")
	onDockModeCycled: Settings.set("bloom-dock-mode", root._nextMode(root.dockMode))
	onNotchModeCycled: Settings.set("bloom-notch-mode", root._nextMode(root.notchMode))
	onDndToggled: Settings.set("bloom-notifications-dnd", !root.dnd)
	onEnergySaverToggled: Battery.setEnergySaver(!root.energySaver)
	onTrayRequested: Dock.reveal(Tokens.dock.revealMs)
	// Bloom Settings is Phase 7; until then the button opens settings.json.
	onSettingsRequested: Apps.run(["xdg-open", Settings.path], "bloom-settings")
	onRestartRequested: Dock.restartShell()
	onVolumeChosen: value => Audio.setVolume(value)
	onBrightnessChosen: percent => Brightness.setPercent(percent)
}
