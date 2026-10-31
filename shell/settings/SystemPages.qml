import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "system.js" as Sys

// The Windows-style pages, one Column per `page`. `sys` is SystemStore, or a
// stand-in in tests.
Column {
	id: root
	property QtObject theme
	property Item popup
	required property string page
	property var sys
	signal cheatsheetRequested()

	width: parent.width
	spacing: 0

	readonly property var _h: root.sys.hypr
	function hOpt(path, fallback) { return Sys.option(root._h, path, fallback); }

	component Page: Column {
		required property string pageId
		objectName: "page:" + pageId
		visible: root.page === pageId
		width: root.width
	}
	Page {
		pageId: "display"
		Repeater {
			model: root.sys.monitors
			delegate: Column {
				id: monitorColumn
				required property var modelData
				width: parent.width
				SGroupLabel { theme: root.theme; text: monitorColumn.modelData.name; above: 0 }
				SGroup {
					theme: root.theme
					SRow {
						theme: root.theme; icon: "monitor"; label: "Resolution"; desc: monitorColumn.modelData.description
						SSelect {
							objectName: "mode:" + monitorColumn.modelData.name
							theme: root.theme; popup: root.popup
							options: Sys.modes(monitorColumn.modelData)
							value: Sys.currentMode(monitorColumn.modelData)
							onActivated: value => root.sys.setMonitor(monitorColumn.modelData, value, monitorColumn.modelData.scale)
						}
					}
					SRow {
						theme: root.theme; icon: "maximize-2"; label: "Scale"; desc: "Size of everything on this screen"; divider: false
						SSelect {
							objectName: "scale:" + monitorColumn.modelData.name
							theme: root.theme; popup: root.popup
							options: [{ value: "1", label: "100%" }, { value: "1.25", label: "125%" }, { value: "1.5", label: "150%" }, { value: "2", label: "200%" }]
							value: String(monitorColumn.modelData.scale)
							onActivated: value => root.sys.setMonitor(monitorColumn.modelData, Sys.currentMode(monitorColumn.modelData), value)
						}
					}
				}
			}
		}
		SGroupLabel { theme: root.theme; text: "Brightness"; visible: root.sys.brightnessAvailable }
		SGroup {
			visible: root.sys.brightnessAvailable
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sun"; label: "Brightness"; divider: false
				desc: Math.round(root.sys.brightness * 100) + "%"
				SSlider { theme: root.theme; from: 0.05; to: 1; step: 0.05; value: root.sys.brightness; onMoved: value => root.sys.setBrightness(value) }
			}
		}
	}

	Page {
		pageId: "sound"
		SGroupLabel { theme: root.theme; text: "Output"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "volume-2"; label: "Output Device"; desc: "Where sound plays"
				SSelect {
					objectName: "sink"; theme: root.theme; popup: root.popup; value: root.sys.sink
					options: root.sys.sinks.map(n => ({ value: n.name, label: n.description || n.name }))
					onActivated: value => root.sys.setSink(value)
				}
			}
			SRow {
				theme: root.theme; icon: "volume-2"; label: "Volume"; divider: false
				desc: Math.round(root.sys.volume * 100) + "%"
				SSlider { objectName: "volume"; theme: root.theme; from: 0; to: 1; step: 0.01; value: root.sys.volume; onMoved: value => root.sys.setVolume(value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Input" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mic"; label: "Input Device"; desc: "Your microphone"; divider: false
				SSelect {
					theme: root.theme; popup: root.popup; value: root.sys.source
					options: root.sys.sources.map(n => ({ value: n.name, label: n.description || n.name }))
					onActivated: value => root.sys.setSource(value)
				}
			}
		}
	}

	Page {
		pageId: "power"
		SGroupLabel { theme: root.theme; text: "Power"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "gauge"; label: "Power Mode"; desc: "Balance speed against battery life"; divider: root.sys.batteryAvailable
				SSelect {
					objectName: "powerMode"; theme: root.theme; popup: root.popup; value: root.sys.powerMode
					options: [{ value: "power-saver", label: "Power Saver" }, { value: "balanced", label: "Balanced" }, { value: "performance", label: "Performance" }]
					onActivated: value => root.sys.setPowerMode(value)
				}
			}
			SRow {
				visible: root.sys.batteryAvailable; height: visible ? implicitHeight : 0; implicitHeight: 49.8
				theme: root.theme; icon: "battery-full"; label: "Battery"; desc: root.sys.batteryLevel + "%"; divider: false
			}
		}
	}

	Page {
		pageId: "storage"
		SGroupLabel { theme: root.theme; text: "Disks"; above: 0 }
		SGroup {
			theme: root.theme
			Repeater {
				model: root.sys.disks
				delegate: SRow {
					required property var modelData
					required property int index
					objectName: "disk:" + modelData.path
					theme: root.theme; icon: "hard-drive"; label: modelData.path
					desc: Sys.gigabytes(modelData.used) + " used of " + Sys.gigabytes(modelData.size)
					divider: index < root.sys.disks.length - 1
					Rectangle {
						width: 100
						height: 4
						radius: 2
						color: root.theme.scrollbarThumb
						Rectangle { width: parent.width * modelData.used / modelData.size; height: parent.height; radius: 2; color: root.theme.text }
					}
				}
			}
		}
	}

	Page {
		pageId: "device"
		SGroupLabel { theme: root.theme; text: "Device"; above: 0 }
		SGroup {
			theme: root.theme
			SRow { theme: root.theme; icon: "monitor"; label: "Device Name"; desc: root.sys.hostname }
			SRow { theme: root.theme; icon: "cpu"; label: "Processor"; desc: root.sys.cpu }
			SRow { theme: root.theme; icon: "memory-stick"; label: "Memory"; desc: root.sys.memory }
			SRow { theme: root.theme; icon: "info"; label: "Kernel"; desc: root.sys.kernel; divider: false }
		}
	}

	Page {
		pageId: "input"
		SGroupLabel { theme: root.theme; text: "Keyboard"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "keyboard"; label: "Repeat Delay"; desc: root.hOpt("input.repeat_delay", 250) + " ms before a held key repeats"
				SSlider { theme: root.theme; from: 100; to: 800; step: 25; value: root.hOpt("input.repeat_delay", 250); onMoved: value => root.sys.setHypr("input.repeat_delay", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: "Repeat Rate"; desc: root.hOpt("input.repeat_rate", 35) + " characters a second"; divider: false
				SSlider { objectName: "repeatRate"; theme: root.theme; from: 10; to: 60; step: 5; value: root.hOpt("input.repeat_rate", 35); onMoved: value => root.sys.setHypr("input.repeat_rate", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Touchpad" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mouse-pointer-2"; label: "Natural Scrolling"; desc: "Content follows your fingers"
				SToggle { objectName: "natural"; theme: root.theme; checked: root.hOpt("input.touchpad.natural_scroll", true); onToggled: value => root.sys.setHypr("input.touchpad.natural_scroll", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: "Disable While Typing"; desc: "Ignore the touchpad as you type"
				SToggle { theme: root.theme; checked: root.hOpt("input.touchpad.disable_while_typing", true); onToggled: value => root.sys.setHypr("input.touchpad.disable_while_typing", value) }
			}
			SRow {
				theme: root.theme; icon: "sliders-vertical"; label: "Scroll Speed"; desc: Math.round(root.hOpt("input.touchpad.scroll_factor", 0.7) * 100) + "%"; divider: false
				SSlider { theme: root.theme; from: 0.1; to: 2; step: 0.1; value: root.hOpt("input.touchpad.scroll_factor", 0.7); onMoved: value => root.sys.setHypr("input.touchpad.scroll_factor", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Mouse" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mouse-pointer-2"; label: "Pointer Speed"; desc: root.hOpt("input.sensitivity", 0).toFixed(1); divider: false
				SSlider { theme: root.theme; from: -1; to: 1; step: 0.1; value: root.hOpt("input.sensitivity", 0); onMoved: value => root.sys.setHypr("input.sensitivity", value) }
			}
		}
	}

	Page {
		pageId: "hyprland"
		SGroupLabel { theme: root.theme; text: "Windows"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "layout-grid"; label: "Inner Gaps"; desc: root.hOpt("general.gaps_in", 4) + " px between windows"
				SSlider { objectName: "gapsIn"; theme: root.theme; from: 0; to: 30; step: 1; value: root.hOpt("general.gaps_in", 4); onMoved: value => root.sys.setHypr("general.gaps_in", value) }
			}
			SRow {
				theme: root.theme; icon: "layout-grid"; label: "Outer Gaps"; desc: root.hOpt("general.gaps_out", 5) + " px around the screen"
				SSlider { theme: root.theme; from: 0; to: 40; step: 1; value: root.hOpt("general.gaps_out", 5); onMoved: value => root.sys.setHypr("general.gaps_out", value) }
			}
			SRow {
				theme: root.theme; icon: "square"; label: "Border Size"; desc: root.hOpt("general.border_size", 1) + " px"
				SSlider { theme: root.theme; from: 0; to: 6; step: 1; value: root.hOpt("general.border_size", 1); onMoved: value => root.sys.setHypr("general.border_size", value) }
			}
			SRow {
				theme: root.theme; icon: "square"; label: "Corner Rounding"; desc: root.hOpt("decoration.rounding", 18) + " px"; divider: false
				SSlider { theme: root.theme; from: 0; to: 30; step: 1; value: root.hOpt("decoration.rounding", 18); onMoved: value => root.sys.setHypr("decoration.rounding", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Effects" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sparkles"; label: "Animations"; desc: "Window and workspace motion"
				SToggle { objectName: "animations"; theme: root.theme; checked: root.hOpt("animations.enabled", true); onToggled: value => root.sys.setHypr("animations.enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "droplets"; label: "Blur"; desc: "Behind translucent surfaces"; divider: false
				SToggle { theme: root.theme; checked: root.hOpt("decoration.blur.enabled", true); onToggled: value => root.sys.setHypr("decoration.blur.enabled", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Keyboard Shortcuts" }
		SGroup {
			theme: root.theme
			SRow { objectName: "keybinds"; theme: root.theme; icon: "keyboard"; label: "View Keybinds"; desc: "Open the cheatsheet"; action: true; divider: false; onClicked: root.cheatsheetRequested() }
		}
	}

	Page {
		pageId: "apps"
		SGroupLabel { theme: root.theme; text: "Default Apps"; above: 0 }
		SGroup {
			theme: root.theme
			Repeater {
				model: Sys.DEFAULTS
				delegate: SRow {
					required property var modelData
					required property int index
					theme: root.theme; icon: modelData.icon; label: modelData.label
					desc: Sys.appName(root.sys.defaults[modelData.id])
					divider: index < Sys.DEFAULTS.length - 1
				}
			}
		}
	}

	Page {
		pageId: "time"
		SGroupLabel { theme: root.theme; text: "Date & Time"; above: 0 }
		SGroup {
			theme: root.theme
			SRow { theme: root.theme; icon: "languages"; label: "Time Zone"; desc: root.sys.timezone }
			SRow {
				theme: root.theme; icon: "clock"; label: "Set Time Automatically"; desc: "Asks for your password"; divider: false
				SToggle { objectName: "ntp"; theme: root.theme; checked: root.sys.ntp; onToggled: value => root.sys.setNtp(value) }
			}
		}
	}

	Page {
		pageId: "updates"
		SGroupLabel { theme: root.theme; text: "System Updates"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				objectName: "runUpdates"
				theme: root.theme; icon: "package"; action: true; divider: false
				label: root.sys.updates < 0 ? "Checking for Updates" : root.sys.updates === 0 ? "Up to Date" : root.sys.updates + " Updates Available"
				desc: "Open a terminal and run pacman"
				onClicked: root.sys.runUpdates()
			}
		}
	}
}
