import QtQuick
import "../common"
import "../common/tokens.js" as Tokens
import "../common/i18n"
import "../common/render"

// Bloom's GeneralTab, with low-power mode added: it's Linux Bloom's own setting.
Column {
	id: root
	property QtObject theme
	property var store
	property Item popup
	property bool autostart: false
	// Minutes; 0 turns that step off.
	readonly property var idleOptions: [{ value: 0, label: I18n.t("linux.settings.never") }, { value: 1, label: I18n.t("linux.settings.1Minute") },
		{ value: 2, label: I18n.t("linux.settings.2Minutes") }, { value: 5, label: I18n.t("linux.settings.5Minutes") }, { value: 10, label: I18n.t("linux.settings.10Minutes") },
		{ value: 15, label: I18n.t("linux.settings.15Minutes") }, { value: 30, label: I18n.t("linux.settings.30Minutes") }, { value: 60, label: I18n.t("linux.settings.1Hour") }]
	signal autostartToggled(bool enabled)
	signal resetRequested()
	signal restartRequested()
	signal quitRequested()
	signal setupRequested()

	width: parent.width

	SGroupLabel { theme: root.theme; text: I18n.t("settings.groups.system"); above: 0 }
	SGroup {
		theme: root.theme
		// Bloom's Language row (GeneralTab.tsx, clock icon included).
		SRow {
			theme: root.theme; icon: "clock"; label: I18n.t("settings.general.language"); desc: I18n.t("settings.general.languageFallbackDesc")
			SSelect {
				objectName: "language"; accessibleName: I18n.t("settings.general.language"); theme: root.theme; popup: root.popup
				options: [{ value: "system", label: I18n.t("settings.general.languageSystem") }]
					.concat(I18n.locales.map(locale => ({ value: locale.code, label: locale.nativeName })))
				value: root.store.values["bloom-language"] ?? "system"
				onActivated: value => root.store.set("bloom-language", value)
			}
		}
		SRow {
			theme: root.theme; icon: "power"; label: I18n.t("settings.general.launchAtLogin"); desc: I18n.t("settings.general.launchAtLoginDesc")
			SToggle { accessibleName: I18n.t("settings.general.launchAtLogin"); objectName: "autostart"; theme: root.theme; checked: root.autostart; onToggled: value => root.autostartToggled(value) }
		}
		SRow {
			theme: root.theme; icon: "download"; label: I18n.t("settings.general.updateIndicator"); desc: I18n.t("settings.general.updateIndicatorDesc")
			SToggle { accessibleName: I18n.t("settings.general.updateIndicator"); theme: root.theme; checked: root.store.values["bloom-show-update-indicator"]; onToggled: value => root.store.set("bloom-show-update-indicator", value) }
		}
		SRow {
			theme: root.theme; icon: "clock"; label: I18n.t("settings.general.time24h"); desc: I18n.t("settings.general.time24hDesc")
			SToggle { accessibleName: I18n.t("settings.general.time24h"); objectName: "time24"; theme: root.theme; checked: root.store.values["bloom-time-format-24h"]; onToggled: value => root.store.set("bloom-time-format-24h", value) }
		}
		SRow {
			theme: root.theme; icon: "bell"; label: I18n.t("linux.settings.batterySound"); desc: I18n.t("linux.settings.playASoundAtTheAlertLevel")
			SToggle { accessibleName: I18n.t("linux.settings.batterySound"); theme: root.theme; checked: root.store.values["bloom-battery-sound-enabled"]; onToggled: value => root.store.set("bloom-battery-sound-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "rotate-ccw"; label: I18n.t("linux.settings.reduceMotion"); desc: I18n.t("linux.settings.skipAnimationsAcrossBloom")
			SToggle { objectName: "reduceMotion"; accessibleName: I18n.t("linux.settings.reduceMotion"); theme: root.theme; checked: root.store.values["bloom-reduce-motion"]; onToggled: value => root.store.set("bloom-reduce-motion", value) }
		}
		SRow {
			theme: root.theme; icon: "gauge"; label: I18n.t("linux.settings.lowPowerMode"); desc: I18n.t("linux.settings.turnOffGlowAndSlowLivePreviews")
			SSelect { accessibleName: I18n.t("linux.settings.lowPowerMode");
				objectName: "lowPower"
				theme: root.theme
				popup: root.popup
				options: [{ value: "off", label: I18n.t("notch.commandCenter.off") }, { value: "auto", label: I18n.t("notch.status.onBattery") }, { value: "on", label: I18n.t("linux.settings.always") }]
				value: root.store.values["bloom-low-power"]
				onActivated: value => root.store.set("bloom-low-power", value)
			}
		}
		SRow {
			theme: root.theme; icon: "battery-warning"; label: I18n.t("settings.general.lowBattery"); divider: false
			desc: I18n.t("settings.general.lowBatteryDesc", { percent: root.store.values["bloom-low-battery-threshold"] })
			SSlider { accessibleName: I18n.t("settings.general.lowBattery"); objectName: "battery"; theme: root.theme; from: 5; to: 50; step: 5; value: root.store.values["bloom-low-battery-threshold"]; onMoved: value => root.store.set("bloom-low-battery-threshold", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.lockScreen") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "lock"; label: I18n.t("linux.settings.lockAfter"); desc: I18n.t("linux.settings.whenYouReAway")
			SSelect {
				objectName: "idleLock"; accessibleName: I18n.t("linux.settings.lockAfter"); theme: root.theme; popup: root.popup
				options: root.idleOptions
				value: root.store.values["bloom-idle-lock"]
				onActivated: value => root.store.set("bloom-idle-lock", value)
			}
		}
		SRow {
			theme: root.theme; icon: "monitor"; label: I18n.t("linux.settings.turnScreenOffAfter"); desc: I18n.t("linux.settings.whenYouReAway")
			SSelect {
				objectName: "idleScreenOff"; accessibleName: I18n.t("linux.settings.turnScreenOffAfter"); theme: root.theme; popup: root.popup
				options: root.idleOptions
				value: root.store.values["bloom-idle-screen-off"]
				onActivated: value => root.store.set("bloom-idle-screen-off", value)
			}
		}
		SRow {
			theme: root.theme; icon: "moon"; label: I18n.t("linux.settings.sleepAfter"); desc: I18n.t("linux.settings.locksFirst")
			SSelect {
				objectName: "idleSleep"; accessibleName: I18n.t("linux.settings.sleepAfter"); theme: root.theme; popup: root.popup
				options: root.idleOptions
				value: root.store.values["bloom-idle-sleep"]
				onActivated: value => root.store.set("bloom-idle-sleep", value)
			}
		}
		SRow {
			theme: root.theme; icon: "music"; label: I18n.t("linux.settings.mediaPlayer"); desc: I18n.t("linux.settings.artworkAndPlaybackControlsWhileLocked"); divider: false
			SToggle { objectName: "lockMedia"; accessibleName: I18n.t("linux.settings.lockScreenMediaPlayer"); theme: root.theme; checked: root.store.values["bloom-lock-media-enabled"]; onToggled: value => root.store.set("bloom-lock-media-enabled", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.translation") }
	SGroup {
		theme: root.theme
		SRow {
			objectName: "translateRow"
			theme: root.theme; icon: "languages"; label: I18n.t("linux.settings.translateTo"); desc: I18n.t("linux.settings.screenTextGoesToGoogleToTranslate"); divider: false
			SSelect {
				objectName: "translateTo"; accessibleName: I18n.t("linux.settings.translateTo"); theme: root.theme; popup: root.popup
				value: root.store.values["bloom-translate-to"]
				options: [{ value: "en", label: I18n.t("linux.settings.english") }, { value: "hi", label: I18n.t("linux.settings.hindi") }, { value: "es", label: I18n.t("linux.settings.spanish") }, { value: "fr", label: I18n.t("linux.settings.french") }, { value: "de", label: I18n.t("linux.settings.german") }, { value: "ja", label: I18n.t("linux.settings.japanese") }, { value: "zh", label: I18n.t("linux.settings.chinese") }, { value: "ar", label: I18n.t("linux.settings.arabic") }]
				onActivated: value => root.store.set("bloom-translate-to", value)
			}
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("settings.groups.app") }
	SGroup {
		theme: root.theme
		SRow {
			objectName: "welcomeRow"
			theme: root.theme; icon: "compass"; label: I18n.t("ui.generalTab.welcomeToBloom"); desc: I18n.t("ui.generalTab.replaySetupAndTheQuickGuide")
			// Bloom's .onboarding-settings-launch.
			Rectangle {
				objectName: "openSetup"
				activeFocusOnTab: true
				Accessible.role: Accessible.Button
				Accessible.name: setupLabel.text
				Keys.onSpacePressed: root.setupRequested()
				Keys.onReturnPressed: root.setupRequested()
				SFocusRing {}
				width: setupLabel.implicitWidth + 22
				height: setupLabel.implicitHeight + 14
				radius: 8
				border.width: 1
				border.color: root.theme.border
				color: root.theme.groupBg
				Text {
					id: setupLabel
					objectName: "openSetupLabel"
					anchors.centerIn: parent
					text: I18n.t("ui.generalTab.openSetup")
					color: root.theme.text
					font.family: Fonts.ui
					font.pixelSize: Fonts.px(11)
				}
				HoverHandler { cursorShape: Qt.PointingHandCursor }
				TapHandler { onTapped: root.setupRequested() }
			}
		}
		SRow { objectName: "reset"; theme: root.theme; icon: "rotate-ccw"; label: I18n.t("settings.general.reset"); desc: I18n.t("settings.general.resetDesc"); action: true; danger: true; onClicked: root.resetRequested() }
		SRow { objectName: "restart"; theme: root.theme; icon: "refresh-cw"; label: I18n.t("settings.general.restart"); desc: I18n.t("settings.general.restartDesc"); action: true; onClicked: root.restartRequested() }
		SRow { objectName: "quit"; theme: root.theme; icon: "log-out"; label: I18n.t("settings.general.quit"); desc: I18n.t("settings.general.quitDesc"); action: true; danger: true; divider: false; onClicked: root.quitRequested() }
	}
}
