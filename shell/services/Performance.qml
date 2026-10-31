pragma Singleton
import QtQuick
import Quickshell
import "performance.js" as Logic

// Whether surfaces should save power. Glow and blur go, live previews slow
// down, springs stay.
Singleton {
	readonly property string mode: Settings.values["bloom-low-power"]
	readonly property bool lowPower: Logic.isLow(mode, !Battery.pluggedIn)
}
