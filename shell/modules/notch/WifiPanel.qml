import QtQuick
import Quickshell
import qs.services

// The Wi-Fi panel: binds WifiView to NetworkManager. Opening it lists and
// scans, as Bloom's does; the footer opens nm-connection-editor when it is
// installed (owner decision 2, 2026-10-29) and is hidden otherwise.
WifiView {
	id: root

	signal subpanelRequested(string name)

	readonly property string _tool: "nm-connection-editor"

	theme: Theme
	enabled: Network.wifiEnabled
	available: Network.available
	unavailableText: Network.unavailableText
	networks: Network.networks
	scanning: Network.scanning
	busy: Network.busy
	error: Network.lastError
	settingsAvailable: (Apps.revision, DesktopEntries.byId(root._tool) !== null)

	Component.onCompleted: {
		Network.clearError();
		Network.hold("wifi-panel", true);
		if (Network.wifiEnabled) Network.refresh(true);
	}
	Component.onDestruction: Network.hold("wifi-panel", false)
	onEnabledChanged: if (root.enabled) Network.refresh(true)

	onBack: root.subpanelRequested("command-center")
	onToggle: Network.setWifi(!Network.wifiEnabled)
	onScan: Network.refresh(true)
	onConnectRequested: (ssid, password) => Network.connect(ssid, password)
	onDisconnectRequested: ssid => Network.disconnect(ssid)
	onForgetRequested: ssid => Network.forget(ssid)
	onErrorCleared: Network.clearError()
	onOpenSettings: Apps.launch(root._tool)
}
