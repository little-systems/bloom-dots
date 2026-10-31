import QtQuick
import "../common/tokens.js" as Tokens

// Bloom's GeneralTab, with low-power mode added: it's Linux Bloom's own setting.
Column {
	id: root
	property QtObject theme
	property var store
	property Item popup
	property bool autostart: false
	signal autostartToggled(bool enabled)
	signal resetRequested()
	signal restartRequested()
	signal quitRequested()

	width: parent.width

	SGroupLabel { theme: root.theme; text: "System"; above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "power"; label: "Launch at Login"; desc: "Open Bloom automatically"
			SToggle { accessibleName: "Launch at Login"; objectName: "autostart"; theme: root.theme; checked: root.autostart; onToggled: value => root.autostartToggled(value) }
		}
		SRow {
			theme: root.theme; icon: "download"; label: "Update Indicator"; desc: "Show green dot when update available"
			SToggle { accessibleName: "Update Indicator"; theme: root.theme; checked: root.store.values["bloom-show-update-indicator"]; onToggled: value => root.store.set("bloom-show-update-indicator", value) }
		}
		SRow {
			theme: root.theme; icon: "clock"; label: "24-Hour Time"; desc: "Use 24-hour clock format"
			SToggle { accessibleName: "24-Hour Time"; objectName: "time24"; theme: root.theme; checked: root.store.values["bloom-time-format-24h"]; onToggled: value => root.store.set("bloom-time-format-24h", value) }
		}
		SRow {
			theme: root.theme; icon: "rotate-ccw"; label: "Reduce Motion"; desc: "Skip animations across Bloom"
			SToggle { objectName: "reduceMotion"; accessibleName: "Reduce Motion"; theme: root.theme; checked: root.store.values["bloom-reduce-motion"]; onToggled: value => root.store.set("bloom-reduce-motion", value) }
		}
		SRow {
			theme: root.theme; icon: "gauge"; label: "Low Power Mode"; desc: "Turn off glow and slow live previews"
			SSelect { accessibleName: "Low Power Mode";
				objectName: "lowPower"
				theme: root.theme
				popup: root.popup
				options: [{ value: "off", label: "Off" }, { value: "auto", label: "On Battery" }, { value: "on", label: "Always" }]
				value: root.store.values["bloom-low-power"]
				onActivated: value => root.store.set("bloom-low-power", value)
			}
		}
		SRow {
			theme: root.theme; icon: "battery-warning"; label: "Low Battery Alert"; divider: false
			desc: "Trigger at " + root.store.values["bloom-low-battery-threshold"] + "%"
			SSlider { accessibleName: "Low Battery Alert"; objectName: "battery"; theme: root.theme; from: 5; to: 50; step: 5; value: root.store.values["bloom-low-battery-threshold"]; onMoved: value => root.store.set("bloom-low-battery-threshold", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: "App" }
	SGroup {
		theme: root.theme
		SRow { objectName: "reset"; theme: root.theme; icon: "rotate-ccw"; label: "Reset to Defaults"; desc: "Restore all settings and restart Bloom"; action: true; danger: true; onClicked: root.resetRequested() }
		SRow { objectName: "restart"; theme: root.theme; icon: "refresh-cw"; label: "Restart Bloom"; desc: "Reinitialize all components"; action: true; onClicked: root.restartRequested() }
		SRow { objectName: "quit"; theme: root.theme; icon: "log-out"; label: "Quit Bloom"; desc: "Exit application completely"; action: true; danger: true; divider: false; onClicked: root.quitRequested() }
	}
}
