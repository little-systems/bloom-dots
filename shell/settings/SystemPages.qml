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
	property var store
	signal cheatsheetRequested()

	width: parent.width
	spacing: 0

	readonly property var _h: root.sys.hypr
	property string _layoutError: ""
	property string _zoneQuery: ""
	property string _appQuery: ""
	function hOpt(path, fallback) {
		const value = Sys.option(root._h, path, undefined);
		return value !== undefined ? value : root.sys.hyprLive[path] ?? fallback;
	}
	readonly property bool _hyprKnown: root.sys.hyprLoaded

	component Page: Column {
		required property string pageId
		objectName: "page:" + pageId
		visible: root.page === pageId
		width: root.width
	}
	// Input and Windows only show what Hyprland reported; without that they show
	// this and lock, rather than offering made-up values.
	component HyprNotice: Text {
		visible: !root.sys.hyprLoaded
		width: parent.width
		bottomPadding: 12
		leftPadding: Tokens.settings.group.label.h
		text: "Couldn't read Hyprland's settings, so these are locked."
		color: "#ff8a80"
		font.family: Fonts.ui
		font.pixelSize: 12
	}

	Page {
		pageId: "display"
		// Nothing a bad mode can't undo by itself: no answer puts it back.
		Rectangle {
			objectName: "keepDisplay"
			visible: root.sys.pendingDisplay !== null
			width: parent.width
			height: visible ? 74 : 0
			radius: 12
			color: root.theme.groupBg
			border.width: 1
			border.color: root.theme.border

			Text {
				x: 14
				y: 12
				text: "Keep these display settings?"
				color: root.theme.text
				font.family: Fonts.uiFor(Font.DemiBold)
				font.pixelSize: 14
				font.weight: Font.DemiBold
			}
			Text {
				objectName: "keepCountdown"
				x: 14
				y: 36
				text: "Reverting in " + root.sys.pendingSeconds + " seconds"
				color: root.theme.textMuted
				font.family: Fonts.ui
				font.pixelSize: 12
			}
			Row {
				x: parent.width - width - 14
				anchors.verticalCenter: parent.verticalCenter
				spacing: 8
				SChip { objectName: "displayRevert"; theme: root.theme; text: "Revert"; onClicked: root.sys.revertDisplay() }
				SChip { objectName: "displayKeep"; theme: root.theme; text: "Keep Changes"; active: true; onClicked: root.sys.keepDisplay() }
			}
		}
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
						SSelect { accessibleName: "Resolution";
							objectName: "mode:" + monitorColumn.modelData.name
							theme: root.theme; popup: root.popup
							options: Sys.modes(monitorColumn.modelData)
							value: Sys.currentMode(monitorColumn.modelData)
							onActivated: value => root.sys.setMonitor(monitorColumn.modelData, value, monitorColumn.modelData.scale)
						}
					}
					SRow {
						theme: root.theme; icon: "maximize-2"; label: "Scale"; desc: "Size of everything on this screen"; divider: false
						SSelect { accessibleName: "Scale";
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
		SGroupLabel { theme: root.theme; text: "Night Light" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "moon"; label: "Night Light"; desc: "Warm the screen for evenings"; divider: root.store.values["bloom-night-light"]
				SToggle { objectName: "nightLight"; accessibleName: "Night Light"; theme: root.theme; checked: root.store.values["bloom-night-light"]; onToggled: value => root.store.set("bloom-night-light", value) }
			}
			SRow {
				visible: root.store.values["bloom-night-light"]
				theme: root.theme; icon: "sun"; label: "Warmth"; desc: root.store.values["bloom-night-temperature"] + " K"; divider: false
				SSlider { accessibleName: "Warmth"; theme: root.theme; from: 2500; to: 6000; step: 100; value: root.store.values["bloom-night-temperature"]; onMoved: value => root.store.set("bloom-night-temperature", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Brightness"; visible: root.sys.brightnessAvailable }
		SGroup {
			visible: root.sys.brightnessAvailable
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sun"; label: "Brightness"; divider: false
				desc: Math.round(root.sys.brightness * 100) + "%"
				SSlider { accessibleName: "Brightness"; theme: root.theme; from: 0.05; to: 1; step: 0.05; value: root.sys.brightness; onMoved: value => root.sys.setBrightness(value) }
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
				SSelect { accessibleName: "Output Device";
					objectName: "sink"; theme: root.theme; popup: root.popup; value: root.sys.sink
					options: root.sys.sinks.map(n => ({ value: n.name, label: n.description || n.name }))
					onActivated: value => root.sys.setSink(value)
				}
			}
			SRow {
				theme: root.theme; icon: "volume-2"; label: "Volume"; divider: false
				desc: Math.round(root.sys.volume * 100) + "%"
				SSlider { accessibleName: "Volume"; objectName: "volume"; theme: root.theme; from: 0; to: 1; step: 0.01; value: root.sys.volume; onMoved: value => root.sys.setVolume(value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Input" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mic"; label: "Input Device"; desc: "Your microphone"; divider: false
				SSelect { accessibleName: "Input Device";
					theme: root.theme; popup: root.popup; value: root.sys.source
					options: root.sys.sources.map(n => ({ value: n.name, label: n.description || n.name }))
					onActivated: value => root.sys.setSource(value)
				}
			}
		}
		SGroupLabel { theme: root.theme; text: "Apps" }
		Text {
			objectName: "noStreams"
			visible: root.sys.mixer.length === 0
			leftPadding: Tokens.settings.group.label.h
			text: "No apps are playing sound"
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: 12
		}
		SGroup {
			visible: root.sys.mixer.length > 0
			theme: root.theme
			Repeater {
				model: root.sys.mixer
				delegate: SRow {
					required property var modelData
					required property int index
					objectName: "stream:" + modelData.name
					theme: root.theme; icon: "music"; label: modelData.name
					desc: Math.round(modelData.volume * 100) + "%"
					divider: index < root.sys.mixer.length - 1
					SSlider { accessibleName: modelData.name + " volume"; theme: root.theme; from: 0; to: 1; step: 0.01; value: modelData.volume; onMoved: value => root.sys.setStreamVolume(modelData.id, value) }
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
				SSelect { accessibleName: "Power Mode";
					objectName: "powerMode"; theme: root.theme; popup: root.popup; value: root.sys.powerMode
					options: [{ value: "power-saver", label: "Power Saver" }, { value: "balanced", label: "Balanced" }, { value: "performance", label: "Performance" }]
					onActivated: value => root.sys.setPowerMode(value)
				}
			}
			SRow {
				visible: root.sys.batteryAvailable
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
		HyprNotice {}
		SGroupLabel { theme: root.theme; text: "Keyboard"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "keyboard"; label: "Repeat Delay"; desc: root.hOpt("input.repeat_delay", 250) + " ms before a held key repeats"
				SSlider { enabled: root._hyprKnown; accessibleName: "Repeat Delay"; theme: root.theme; from: 100; to: 800; step: 25; value: root.hOpt("input.repeat_delay", 250); onMoved: value => root.sys.setHypr("input.repeat_delay", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: "Repeat Rate"; desc: root.hOpt("input.repeat_rate", 35) + " characters a second"; divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: "Repeat Rate"; objectName: "repeatRate"; theme: root.theme; from: 10; to: 60; step: 5; value: root.hOpt("input.repeat_rate", 35); onMoved: value => root.sys.setHypr("input.repeat_rate", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Layouts" }
		SGroup {
			theme: root.theme
			SRow {
				objectName: "layoutRow"
				theme: root.theme; icon: "languages"; label: "Keyboard Layouts"; divider: false
				desc: root._layoutError || "Codes such as us or de, separated by commas"
				SField {
					objectName: "layouts"
					width: 140
					theme: root.theme
					accessibleName: "Keyboard layouts"
					placeholder: "us,de"
					text: root.hOpt("input.kb_layout", "")
					onAccepted: {
						const bad = Sys.badLayouts(text, root.sys.layouts);
						root._layoutError = bad.length ? bad.join(", ") + " isn't a layout" : "";
						if (!bad.length) root.sys.setHypr("input.kb_layout", text.replace(/\s/g, ""));
					}
				}
			}
		}

		SGroupLabel { theme: root.theme; text: "Touchpad" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mouse-pointer-2"; label: "Natural Scrolling"; desc: "Content follows your fingers"
				SToggle { enabled: root._hyprKnown; accessibleName: "Natural Scrolling"; objectName: "natural"; theme: root.theme; checked: root.hOpt("input.touchpad.natural_scroll", true); onToggled: value => root.sys.setHypr("input.touchpad.natural_scroll", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: "Disable While Typing"; desc: "Ignore the touchpad as you type"
				SToggle { enabled: root._hyprKnown; accessibleName: "Disable While Typing"; theme: root.theme; checked: root.hOpt("input.touchpad.disable_while_typing", true); onToggled: value => root.sys.setHypr("input.touchpad.disable_while_typing", value) }
			}
			SRow {
				theme: root.theme; icon: "sliders-vertical"; label: "Scroll Speed"; desc: Math.round(root.hOpt("input.touchpad.scroll_factor", 0.7) * 100) + "%"; divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: "Scroll Speed"; theme: root.theme; from: 0.1; to: 2; step: 0.1; value: root.hOpt("input.touchpad.scroll_factor", 0.7); onMoved: value => root.sys.setHypr("input.touchpad.scroll_factor", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Mouse" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mouse-pointer-2"; label: "Pointer Speed"; desc: root.hOpt("input.sensitivity", 0).toFixed(1); divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: "Pointer Speed"; theme: root.theme; from: -1; to: 1; step: 0.1; value: root.hOpt("input.sensitivity", 0); onMoved: value => root.sys.setHypr("input.sensitivity", value) }
			}
		}
	}

	Page {
		pageId: "hyprland"
		HyprNotice { objectName: "hyprNotice" }
		SGroupLabel { theme: root.theme; text: "Windows"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "layout-grid"; label: "Inner Gaps"; desc: root.hOpt("general.gaps_in", 4) + " px between windows"
				SSlider { enabled: root._hyprKnown; accessibleName: "Inner Gaps"; objectName: "gapsIn"; theme: root.theme; from: 0; to: 30; step: 1; value: root.hOpt("general.gaps_in", 4); onMoved: value => root.sys.setHypr("general.gaps_in", value) }
			}
			SRow {
				theme: root.theme; icon: "layout-grid"; label: "Outer Gaps"; desc: root.hOpt("general.gaps_out", 5) + " px around the screen"
				SSlider { enabled: root._hyprKnown; accessibleName: "Outer Gaps"; theme: root.theme; from: 0; to: 40; step: 1; value: root.hOpt("general.gaps_out", 5); onMoved: value => root.sys.setHypr("general.gaps_out", value) }
			}
			SRow {
				theme: root.theme; icon: "square"; label: "Border Size"; desc: root.hOpt("general.border_size", 1) + " px"
				SSlider { enabled: root._hyprKnown; accessibleName: "Border Size"; theme: root.theme; from: 0; to: 6; step: 1; value: root.hOpt("general.border_size", 1); onMoved: value => root.sys.setHypr("general.border_size", value) }
			}
			SRow {
				theme: root.theme; icon: "square"; label: "Corner Rounding"; desc: root.hOpt("decoration.rounding", 18) + " px"; divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: "Corner Rounding"; theme: root.theme; from: 0; to: 30; step: 1; value: root.hOpt("decoration.rounding", 18); onMoved: value => root.sys.setHypr("decoration.rounding", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: "Effects" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sparkles"; label: "Animations"; desc: "Window and workspace motion"
				SToggle { enabled: root._hyprKnown; accessibleName: "Animations"; objectName: "animations"; theme: root.theme; checked: root.hOpt("animations.enabled", true); onToggled: value => root.sys.setHypr("animations.enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "droplets"; label: "Blur"; desc: "Behind translucent surfaces"; divider: false
				SToggle { enabled: root._hyprKnown; accessibleName: "Blur"; theme: root.theme; checked: root.hOpt("decoration.blur.enabled", true); onToggled: value => root.sys.setHypr("decoration.blur.enabled", value) }
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
					id: defaultRow
					required property var modelData
					required property int index
					readonly property var choices: root.sys.defaultChoices[defaultRow.modelData.id] ?? []
					theme: root.theme; icon: defaultRow.modelData.icon; label: defaultRow.modelData.label
					desc: Sys.appName(root.sys.defaults[defaultRow.modelData.id])
					divider: defaultRow.index < Sys.DEFAULTS.length - 1
					SSelect {
						objectName: "default:" + defaultRow.modelData.id
						accessibleName: defaultRow.modelData.label
						visible: defaultRow.choices.length > 0
						theme: root.theme; popup: root.popup
						options: defaultRow.choices
						value: root.sys.defaults[defaultRow.modelData.id] ?? ""
						onActivated: value => root.sys.setDefault(defaultRow.modelData.id, defaultRow.modelData.mime, value)
					}
				}
			}
		}
		SGroupLabel { theme: root.theme; text: "Startup Apps" }
		Text {
			visible: root.sys.startup.length === 0
			leftPadding: Tokens.settings.group.label.h
			text: "Nothing starts with your session"
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: 12
		}
		SGroup {
			visible: root.sys.startup.length > 0
			theme: root.theme
			Repeater {
				model: root.sys.startup
				delegate: SRow {
					id: startupRow
					required property var modelData
					required property int index
					theme: root.theme; icon: "app-window"; label: startupRow.modelData.name
					divider: startupRow.index < root.sys.startup.length - 1
					SToggle { objectName: "startup:" + startupRow.modelData.id; accessibleName: startupRow.modelData.name; theme: root.theme; checked: startupRow.modelData.state === "on"; onToggled: value => root.sys.setStartup(startupRow.modelData.id, value) }
				}
			}
		}
		SGroupLabel { theme: root.theme; text: "Installed Apps" }
		SField {
			objectName: "appSearch"
			width: parent.width
			theme: root.theme
			placeholder: "Search " + root.sys.installed.length + " apps"
			accessibleName: "Search installed apps"
			onTextChanged: root._appQuery = text.toLowerCase()
		}
		Item { width: 1; height: 8 }
		SGroup {
			id: appList
			readonly property var shown: root.sys.installed.filter(a => a.name.toLowerCase().includes(root._appQuery)).slice(0, 30)
			visible: appList.shown.length > 0
			theme: root.theme
			Repeater {
				model: appList.shown
				delegate: SRow {
					id: appRow
					required property var modelData
					required property int index
					objectName: "app:" + appRow.modelData.id
					theme: root.theme; icon: "app-window"; label: appRow.modelData.name
					divider: appRow.index < appList.shown.length - 1
					Row {
						spacing: 6
						SChip { theme: root.theme; text: "Open"; onClicked: root.sys.launch(appRow.modelData.id) }
						SChip { objectName: "uninstall:" + appRow.modelData.id; theme: root.theme; text: "Uninstall"; onClicked: root.sys.uninstall(appRow.modelData.id) }
					}
				}
			}
		}
	}

	Page {
		pageId: "ai"
		SGroupLabel { theme: root.theme; text: "Gemini"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				objectName: "aiKeyRow"
				theme: root.theme; icon: "lock"; label: "API Key"; divider: false
				desc: root.sys.aiKey === "saved" ? "Saved in your keyring" : root.sys.aiKey === "missing" ? "Not set" : root.sys.aiKey === "unavailable" ? "Your keyring isn't available" : "Checking…"
			}
			Row {
				x: Tokens.settings.row.inset
				spacing: 8
				bottomPadding: 14
				SField {
					id: keyField
					objectName: "aiKey"
					theme: root.theme
					secret: true
					placeholder: "Paste your key"
					accessibleName: "Gemini API key"
					onAccepted: saveKey.clicked()
				}
				SChip {
					id: saveKey
					objectName: "aiSave"
					theme: root.theme; active: true; text: "Save"
					onClicked: {
						if (keyField.text.trim() === "") return;
						root.sys.setAiKey(keyField.text.trim());
						keyField.text = "";
					}
				}
				SChip {
					objectName: "aiRemove"
					visible: root.sys.aiKey === "saved"
					theme: root.theme; text: "Remove"
					onClicked: root.sys.removeAiKey()
				}
			}
		}
		SGroupLabel { theme: root.theme; text: "Chat" }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sparkles"; label: "Model"; desc: "Used by chat in Spotlight"
				SSelect {
					objectName: "aiModel"; accessibleName: "Model"; theme: root.theme; popup: root.popup
					value: root.store.values["bloom-ai-model"]
					options: [{ value: "gemini-2.5-flash", label: "Gemini Flash" }, { value: "gemini-2.5-pro", label: "Gemini Pro" }]
					onActivated: value => root.store.set("bloom-ai-model", value)
				}
			}
			SRow {
				objectName: "aiTest"
				theme: root.theme; icon: "refresh-cw"; action: true; divider: false
				label: "Test Connection"
				desc: root.sys.aiCheck === "" ? "Check that the key works" : root.sys.aiCheck
				onClicked: root.sys.checkAi()
			}
		}
	}

	Page {
		pageId: "time"
		SGroupLabel { theme: root.theme; text: "Date & Time"; above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "languages"; label: "Time Zone"; desc: root.sys.timezone
				SField {
					objectName: "zoneSearch"
					width: 170
					theme: root.theme
					placeholder: "Search cities"
					accessibleName: "Search time zones"
					onTextChanged: root._zoneQuery = text
				}
			}
			Repeater {
				model: Sys.matches(root.sys.timezones, root._zoneQuery, 6)
				delegate: SRow {
					id: zoneRow
					required property string modelData
					objectName: "zone:" + zoneRow.modelData
					theme: root.theme; icon: "clock"; label: zoneRow.modelData; action: true
					onClicked: root.sys.setTimezone(zoneRow.modelData)
				}
			}
			SRow {
				theme: root.theme; icon: "clock"; label: "Set Time Automatically"; desc: "Asks for your password"; divider: false
				SToggle { accessibleName: "Set Time Automatically"; objectName: "ntp"; theme: root.theme; checked: root.sys.ntp; onToggled: value => root.sys.setNtp(value) }
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
				label: Sys.updatesLabel(root.sys.updates)
				desc: "Open a terminal and run pacman"
				onClicked: root.sys.runUpdates()
			}
		}
	}
}
