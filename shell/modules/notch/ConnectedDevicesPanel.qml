import QtQuick
import qs.services
import "../../services/devices.js" as Logic

// The Connected devices panel: binds DevicesView to this PC's battery,
// Bluetooth and wired audio, and saves "Looks like" picks.
DevicesView {
	id: root

	readonly property var _looks: Logic.parseLooks(Settings.values["bloom-device-looks"])
	readonly property var _pc: ({
		present: Battery.available && Battery.ready,
		level: Battery.level,
		charging: Battery.charging,
		pluggedIn: Battery.pluggedIn,
		secondsLeft: Battery.device?.timeToEmpty ?? 0,
		secondsToFull: Battery.device?.timeToFull ?? 0
	})

	theme: Theme
	threshold: Settings.values["bloom-low-battery-threshold"]
	entries: Logic.entries(root._pc, Bluetooth.devices, Devices.wiredAudio, root._looks)
	pcStatus: Logic.pcStatus(root._pc)

	Component.onCompleted: {
		Bluetooth.hold("devices-panel", true);
		Devices.hold("devices-panel", true);
	}
	Component.onDestruction: {
		Bluetooth.hold("devices-panel", false);
		Devices.hold("devices-panel", false);
	}

	onLookChosen: (name, art) => {
		const next = Object.assign({}, root._looks);
		if (art)
			next[name] = art;
		else
			delete next[name];
		Settings.set("bloom-device-looks", JSON.stringify(next));
	}
}
