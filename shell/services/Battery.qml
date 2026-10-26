pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "battery.js" as Logic

// The laptop battery for the notch (UPower display device), with Bloom's
// tooltip text. `available` is false on machines without a laptop battery,
// and the battery widget hides then.
Singleton {
	id: root

	readonly property var device: UPower.displayDevice
	readonly property bool available: root.device?.isLaptopBattery ?? false
	// UPower has answered for this device (its first values are placeholders).
	readonly property bool ready: root.device?.ready ?? false
	readonly property int level: Math.round((root.device?.percentage ?? 0) * 100)
	readonly property bool charging: root.device?.state === UPowerDeviceState.Charging
	readonly property bool pluggedIn: !UPower.onBattery
	readonly property int threshold: Settings.values["bloom-low-battery-threshold"]
	readonly property string powerMode: {
		switch (PowerProfiles.profile) {
		case PowerProfile.PowerSaver:
			return "Power saver";
		case PowerProfile.Performance:
			return "Performance";
		case PowerProfile.Balanced:
			return "Balanced";
		}
		return "";
	}
	readonly property string tooltip: Logic.tooltip({
		level: root.level,
		charging: root.charging,
		pluggedIn: root.pluggedIn,
		secondsLeft: root.device?.timeToEmpty ?? 0,
		secondsToFull: root.device?.timeToFull ?? 0,
		healthPercent: root.device?.healthSupported ? Math.round(root.device.healthPercentage) : null,
		powerMode: root.powerMode,
		energySaver: PowerProfiles.profile === PowerProfile.PowerSaver
	})
}
