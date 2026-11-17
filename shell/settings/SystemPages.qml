import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "system.js" as Sys
import "../common/i18n"

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
		text: I18n.t("linux.settings.couldnTReadHyprlandSSettingsSoThese")
		color: "#ff8a80"
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(14)
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
				text: I18n.t("linux.settings.keepTheseDisplaySettings")
				color: root.theme.text
				font.family: Fonts.uiFor(Font.DemiBold)
				font.pixelSize: Fonts.px(16)
				font.weight: Font.DemiBold
			}
			Text {
				objectName: "keepCountdown"
				x: 14
				y: 36
				text: root.sys.displayBusy ? I18n.t("linux.settings.applyingDisplaySettings") : I18n.t("linux.settings.revertingIn", { seconds: root.sys.pendingSeconds })
				color: root.theme.textMuted
				font.family: Fonts.ui
				font.pixelSize: Fonts.px(14)
			}
			Row {
				x: parent.width - width - 14
				anchors.verticalCenter: parent.verticalCenter
				spacing: 8
				SChip { objectName: "displayRevert"; enabled: !root.sys.displayBusy; theme: root.theme; text: I18n.t("linux.settings.revert"); onClicked: root.sys.revertDisplay() }
				SChip { objectName: "displayKeep"; enabled: !root.sys.displayBusy; theme: root.theme; text: I18n.t("linux.settings.keepChanges"); active: true; onClicked: root.sys.keepDisplay() }
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
						theme: root.theme; icon: "monitor"; label: I18n.t("linux.settings.resolution"); desc: monitorColumn.modelData.description
						SSelect { accessibleName: I18n.t("linux.settings.resolution");
							objectName: "mode:" + monitorColumn.modelData.name
							theme: root.theme; popup: root.popup
							options: Sys.modes(monitorColumn.modelData)
							value: Sys.currentMode(monitorColumn.modelData)
							onActivated: value => root.sys.setMonitor(monitorColumn.modelData, value, monitorColumn.modelData.scale)
						}
					}
					SRow {
						theme: root.theme; icon: "maximize-2"; label: I18n.t("linux.settings.scale"); desc: I18n.t("linux.settings.sizeOfEverythingOnThisScreen"); divider: false
						SSelect { accessibleName: I18n.t("linux.settings.scale");
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
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.nightLight") }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "moon"; label: I18n.t("linux.settings.nightLight"); desc: I18n.t("linux.settings.warmTheScreenForEvenings"); divider: root.store.values["bloom-night-light"]
				SToggle { objectName: "nightLight"; accessibleName: I18n.t("linux.settings.nightLight"); theme: root.theme; checked: root.store.values["bloom-night-light"]; onToggled: value => root.store.set("bloom-night-light", value) }
			}
			SRow {
				visible: root.store.values["bloom-night-light"]
				theme: root.theme; icon: "sun"; label: I18n.t("linux.settings.warmth"); desc: root.store.values["bloom-night-temperature"] + " K"; divider: false
				SSlider { accessibleName: I18n.t("linux.settings.warmth"); theme: root.theme; from: 2500; to: 6000; step: 100; value: root.store.values["bloom-night-temperature"]; onMoved: value => root.store.set("bloom-night-temperature", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("notch.commandCenter.brightness"); visible: root.sys.brightnessAvailable }
		SGroup {
			visible: root.sys.brightnessAvailable
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sun"; label: I18n.t("notch.commandCenter.brightness"); divider: false
				desc: Math.round(root.sys.brightness * 100) + "%"
				SSlider { accessibleName: I18n.t("notch.commandCenter.brightness"); theme: root.theme; from: 0.05; to: 1; step: 0.05; value: root.sys.brightness; onMoved: value => root.sys.setBrightness(value) }
			}
		}
	}

	Page {
		pageId: "sound"
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.output"); above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "volume-2"; label: I18n.t("linux.settings.outputDevice"); desc: I18n.t("linux.settings.whereSoundPlays")
				SSelect { accessibleName: I18n.t("linux.settings.outputDevice");
					objectName: "sink"; theme: root.theme; popup: root.popup; value: root.sys.sink
					options: root.sys.sinks.map(n => ({ value: n.name, label: n.description || n.name }))
					onActivated: value => root.sys.setSink(value)
				}
			}
			SRow {
				theme: root.theme; icon: "volume-2"; label: I18n.t("notch.music.volume"); divider: false
				desc: Math.round(root.sys.volume * 100) + "%"
				SSlider { accessibleName: I18n.t("notch.music.volume"); objectName: "volume"; theme: root.theme; from: 0; to: 1; step: 0.01; value: root.sys.volume; onMoved: value => root.sys.setVolume(value) }
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.input") }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mic"; label: I18n.t("linux.settings.inputDevice"); desc: I18n.t("linux.settings.yourMicrophone"); divider: false
				SSelect { accessibleName: I18n.t("linux.settings.inputDevice");
					theme: root.theme; popup: root.popup; value: root.sys.source
					options: root.sys.sources.map(n => ({ value: n.name, label: n.description || n.name }))
					onActivated: value => root.sys.setSource(value)
				}
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.apps") }
		Text {
			objectName: "noStreams"
			visible: root.sys.mixer.length === 0
			leftPadding: Tokens.settings.group.label.h
			text: I18n.t("linux.settings.noAppsArePlayingSound")
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: Fonts.px(14)
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
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.power"); above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "gauge"; label: I18n.t("linux.settings.powerMode"); desc: I18n.t("linux.settings.balanceSpeedAgainstBatteryLife"); divider: root.sys.batteryAvailable
				SSelect { accessibleName: I18n.t("linux.settings.powerMode");
					objectName: "powerMode"; theme: root.theme; popup: root.popup; value: root.sys.powerMode
					options: [{ value: "power-saver", label: I18n.t("linux.settings.powerSaver") }, { value: "balanced", label: I18n.t("linux.settings.balanced") }, { value: "performance", label: I18n.t("linux.settings.performance") }]
					onActivated: value => root.sys.setPowerMode(value)
				}
			}
			SRow {
				visible: root.sys.batteryAvailable
				theme: root.theme; icon: "battery-full"; label: I18n.t("settings.widgets.battery"); desc: root.sys.batteryLevel + "%"; divider: false
			}
		}
	}

	Page {
		pageId: "storage"
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.disks"); above: 0 }
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
		pageId: "input"
		HyprNotice {}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.keyboard"); above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "keyboard"; label: I18n.t("linux.settings.repeatDelay"); desc: root.hOpt("input.repeat_delay", 250) + " ms before a held key repeats"
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.repeatDelay"); theme: root.theme; from: 100; to: 800; step: 25; value: root.hOpt("input.repeat_delay", 250); onMoved: value => root.sys.setHypr("input.repeat_delay", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: I18n.t("linux.settings.repeatRate"); desc: root.hOpt("input.repeat_rate", 35) + " characters a second"; divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.repeatRate"); objectName: "repeatRate"; theme: root.theme; from: 10; to: 60; step: 5; value: root.hOpt("input.repeat_rate", 35); onMoved: value => root.sys.setHypr("input.repeat_rate", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.layouts") }
		SGroup {
			theme: root.theme
			SRow {
				objectName: "layoutRow"
				theme: root.theme; icon: "languages"; label: I18n.t("linux.settings.keyboardLayouts"); divider: false
				desc: root._layoutError || I18n.t("linux.settings.codesSuchAsUsOrDeSeparatedBy")
				SField {
					objectName: "layouts"
					width: 140
					theme: root.theme
					accessibleName: I18n.t("linux.settings.keyboardLayouts2")
					placeholder: I18n.t("linux.settings.usDe")
					text: root.hOpt("input.kb_layout", "")
					onAccepted: {
						const bad = Sys.badLayouts(text, root.sys.layouts);
						root._layoutError = bad.length ? bad.join(", ") + " isn't a layout" : "";
						if (!bad.length) root.sys.setHypr("input.kb_layout", text.replace(/\s/g, ""));
					}
				}
			}
		}

		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.touchpad") }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mouse-pointer-2"; label: I18n.t("linux.settings.naturalScrolling"); desc: I18n.t("linux.settings.contentFollowsYourFingers")
				SToggle { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.naturalScrolling"); objectName: "natural"; theme: root.theme; checked: root.hOpt("input.touchpad.natural_scroll", true); onToggled: value => root.sys.setHypr("input.touchpad.natural_scroll", value) }
			}
			SRow {
				theme: root.theme; icon: "keyboard"; label: I18n.t("linux.settings.disableWhileTyping"); desc: I18n.t("linux.settings.ignoreTheTouchpadAsYouType")
				SToggle { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.disableWhileTyping"); theme: root.theme; checked: root.hOpt("input.touchpad.disable_while_typing", true); onToggled: value => root.sys.setHypr("input.touchpad.disable_while_typing", value) }
			}
			SRow {
				theme: root.theme; icon: "sliders-vertical"; label: I18n.t("linux.settings.scrollSpeed"); desc: Math.round(root.hOpt("input.touchpad.scroll_factor", 0.7) * 100) + "%"; divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.scrollSpeed"); theme: root.theme; from: 0.1; to: 2; step: 0.1; value: root.hOpt("input.touchpad.scroll_factor", 0.7); onMoved: value => root.sys.setHypr("input.touchpad.scroll_factor", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.mouse") }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "mouse-pointer-2"; label: I18n.t("linux.settings.pointerSpeed"); desc: root.hOpt("input.sensitivity", 0).toFixed(1); divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.pointerSpeed"); theme: root.theme; from: -1; to: 1; step: 0.1; value: root.hOpt("input.sensitivity", 0); onMoved: value => root.sys.setHypr("input.sensitivity", value) }
			}
		}
	}

	Page {
		pageId: "hyprland"
		HyprNotice { objectName: "hyprNotice" }
		SGroupLabel { theme: root.theme; text: I18n.t("settings.dock.iconWindows"); above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "layout-grid"; label: I18n.t("linux.settings.innerGaps"); desc: root.hOpt("general.gaps_in", 4) + " px between windows"
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.innerGaps"); objectName: "gapsIn"; theme: root.theme; from: 0; to: 30; step: 1; value: root.hOpt("general.gaps_in", 4); onMoved: value => root.sys.setHypr("general.gaps_in", value) }
			}
			SRow {
				theme: root.theme; icon: "layout-grid"; label: I18n.t("linux.settings.outerGaps"); desc: root.hOpt("general.gaps_out", 5) + " px around the screen"
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.outerGaps"); theme: root.theme; from: 0; to: 40; step: 1; value: root.hOpt("general.gaps_out", 5); onMoved: value => root.sys.setHypr("general.gaps_out", value) }
			}
			SRow {
				theme: root.theme; icon: "square"; label: I18n.t("linux.settings.borderSize"); desc: root.hOpt("general.border_size", 1) + " px"
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.borderSize"); theme: root.theme; from: 0; to: 6; step: 1; value: root.hOpt("general.border_size", 1); onMoved: value => root.sys.setHypr("general.border_size", value) }
			}
			SRow {
				theme: root.theme; icon: "square"; label: I18n.t("linux.settings.cornerRounding"); desc: root.hOpt("decoration.rounding", 18) + " px"; divider: false
				SSlider { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.cornerRounding"); theme: root.theme; from: 0; to: 30; step: 1; value: root.hOpt("decoration.rounding", 18); onMoved: value => root.sys.setHypr("decoration.rounding", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.effects") }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sparkles"; label: I18n.t("linux.settings.animations"); desc: I18n.t("linux.settings.windowAndWorkspaceMotion")
				SToggle { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.animations"); objectName: "animations"; theme: root.theme; checked: root.hOpt("animations.enabled", true); onToggled: value => root.sys.setHypr("animations.enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "droplets"; label: I18n.t("linux.settings.blur"); desc: I18n.t("linux.settings.behindTranslucentSurfaces"); divider: false
				SToggle { enabled: root._hyprKnown; accessibleName: I18n.t("linux.settings.blur"); theme: root.theme; checked: root.hOpt("decoration.blur.enabled", true); onToggled: value => root.sys.setHypr("decoration.blur.enabled", value) }
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.keyboardShortcuts") }
		SGroup {
			theme: root.theme
			SRow { objectName: "keybinds"; theme: root.theme; icon: "keyboard"; label: I18n.t("linux.settings.viewKeybinds"); desc: I18n.t("linux.settings.openTheCheatsheet"); action: true; divider: false; onClicked: root.cheatsheetRequested() }
		}
	}

	Page {
		pageId: "apps"
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.defaultApps"); above: 0 }
		SGroup {
			theme: root.theme
			Repeater {
				model: Sys.DEFAULTS
				delegate: SRow {
					id: defaultRow
					required property var modelData
					required property int index
					readonly property var choices: root.sys.defaultChoices[defaultRow.modelData.id] ?? []
					theme: root.theme; icon: defaultRow.modelData.icon; label: I18n.t(defaultRow.modelData.key)
					desc: Sys.appName(root.sys.defaults[defaultRow.modelData.id])
					divider: defaultRow.index < Sys.DEFAULTS.length - 1
					SSelect {
						objectName: "default:" + defaultRow.modelData.id
						accessibleName: I18n.t(defaultRow.modelData.key)
						visible: defaultRow.choices.length > 0
						theme: root.theme; popup: root.popup
						options: defaultRow.choices
						value: root.sys.defaults[defaultRow.modelData.id] ?? ""
						onActivated: value => root.sys.setDefault(defaultRow.modelData.id, defaultRow.modelData.mime, value)
					}
				}
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.startupApps") }
		Text {
			visible: root.sys.startup.length === 0
			leftPadding: Tokens.settings.group.label.h
			text: I18n.t("linux.settings.nothingStartsWithYourSession")
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: Fonts.px(14)
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
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.installedApps") }
		SField {
			objectName: "appSearch"
			width: parent.width
			theme: root.theme
			placeholder: I18n.t("linux.settings.search") + root.sys.installed.length + " apps"
			accessibleName: I18n.t("linux.settings.searchInstalledApps")
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
						SChip { theme: root.theme; text: I18n.t("ui.dock.open"); onClicked: root.sys.launch(appRow.modelData.id) }
						SChip { objectName: "uninstall:" + appRow.modelData.id; theme: root.theme; text: I18n.t("linux.settings.uninstall"); onClicked: root.sys.uninstall(appRow.modelData.id) }
					}
				}
			}
		}
	}

	Page {
		pageId: "ai"
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.gemini"); above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				objectName: "aiKeyRow"
				theme: root.theme; icon: "lock"; label: I18n.t("linux.settings.apiKey"); divider: false
				desc: root.sys.aiKey === "saved" ? I18n.t("linux.settings.savedInYourKeyring") : root.sys.aiKey === "missing" ? I18n.t("linux.settings.notSet") : root.sys.aiKey === "unavailable" ? I18n.t("linux.settings.yourKeyringIsnTAvailable") : I18n.t("linux.settings.checking")
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
					placeholder: I18n.t("linux.settings.pasteYourKey")
					accessibleName: I18n.t("linux.settings.geminiApiKey")
					onAccepted: saveKey.clicked()
				}
				SChip {
					id: saveKey
					objectName: "aiSave"
					theme: root.theme; active: true; text: I18n.t("linux.settings.save")
					onClicked: {
						if (keyField.text.trim() === "") return;
						root.sys.setAiKey(keyField.text.trim());
						keyField.text = "";
					}
				}
				SChip {
					objectName: "aiRemove"
					visible: root.sys.aiKey === "saved"
					theme: root.theme; text: I18n.t("common.remove")
					onClicked: root.sys.removeAiKey()
				}
			}
		}
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.chat") }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "sparkles"; label: I18n.t("linux.settings.model"); desc: I18n.t("linux.settings.usedByChatInSpotlight")
				SSelect {
					objectName: "aiModel"; accessibleName: I18n.t("linux.settings.model"); theme: root.theme; popup: root.popup
					value: root.store.values["bloom-ai-model"]
					options: [{ value: "gemini-2.5-flash", label: I18n.t("linux.settings.geminiFlash") }, { value: "gemini-2.5-pro", label: I18n.t("linux.settings.geminiPro") }]
					onActivated: value => root.store.set("bloom-ai-model", value)
				}
			}
			SRow {
				objectName: "aiTest"
				theme: root.theme; icon: "refresh-cw"; action: true; divider: false
				label: I18n.t("linux.settings.testConnection")
				desc: root.sys.aiCheck === "" ? I18n.t("linux.settings.checkThatTheKeyWorks") : root.sys.aiCheck
				onClicked: root.sys.checkAi()
			}
		}
	}

	Page {
		pageId: "time"
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.dateTime"); above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "languages"; label: I18n.t("linux.settings.timeZone"); desc: root.sys.timezone
				SField {
					objectName: "zoneSearch"
					width: 170
					theme: root.theme
					placeholder: I18n.t("linux.settings.searchCities")
					accessibleName: I18n.t("linux.settings.searchTimeZones")
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
				theme: root.theme; icon: "clock"; label: I18n.t("linux.settings.setTimeAutomatically"); desc: I18n.t("linux.settings.asksForYourPassword"); divider: false
				SToggle { accessibleName: I18n.t("linux.settings.setTimeAutomatically"); objectName: "ntp"; theme: root.theme; checked: root.sys.ntp; onToggled: value => root.sys.setNtp(value) }
			}
		}
	}

	Page {
		pageId: "updates"
		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.systemUpdates"); above: 0 }
		SGroup {
			theme: root.theme
			SRow {
				objectName: "runUpdates"
				theme: root.theme; icon: "package"; action: true; divider: false
				label: Sys.updatesLabel(root.sys.updates)
				desc: I18n.t("linux.settings.openATerminalAndRunPacman")
				onClicked: root.sys.runUpdates()
			}
		}
	}
}
