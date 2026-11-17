import QtQuick
import "../common/tokens.js" as Tokens
import "../common/i18n"

// Bloom's OverlaysTab.
Column {
	id: root
	property QtObject theme
	property var store

	readonly property bool _volume: root.store.values["bloom-volume-hud-enabled"]
	readonly property bool _protect: root.store.values["bloom-volume-protection-enabled"]
	readonly property bool _brightness: root.store.values["bloom-brightness-hud-enabled"]

	width: parent.width

	SGroupLabel { theme: root.theme; text: I18n.t("settings.tabs.overlays"); above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "volume-2"; label: I18n.t("settings.overlays.volume"); desc: I18n.t("settings.overlays.volumeDesc")
			SToggle { accessibleName: I18n.t("settings.overlays.volume"); objectName: "volume"; theme: root.theme; checked: root._volume; onToggled: value => root.store.set("bloom-volume-hud-enabled", value) }
		}
		SRow {
			objectName: "volumeEdge"
			visible: root._volume
			theme: root.theme; icon: "arrow-left-to-line"; label: I18n.t("settings.overlays.volumeEdge"); desc: I18n.t("settings.overlays.volumeEdgeDesc")
			SToggle { accessibleName: I18n.t("settings.overlays.volumeEdge"); theme: root.theme; checked: root.store.values["bloom-volume-edge-enabled"]; onToggled: value => root.store.set("bloom-volume-edge-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "sun"; label: I18n.t("settings.overlays.brightness"); desc: I18n.t("settings.overlays.brightnessDesc"); divider: root._brightness
			SToggle { accessibleName: I18n.t("settings.overlays.brightness"); theme: root.theme; checked: root._brightness; onToggled: value => root.store.set("bloom-brightness-hud-enabled", value) }
		}
		SRow {
			visible: root._brightness
			theme: root.theme; icon: "arrow-right-to-line"; label: I18n.t("settings.overlays.volumeEdge"); desc: I18n.t("settings.overlays.brightnessEdgeDesc"); divider: false
			SToggle { accessibleName: I18n.t("settings.overlays.volumeEdge"); theme: root.theme; checked: root.store.values["bloom-brightness-edge-enabled"]; onToggled: value => root.store.set("bloom-brightness-edge-enabled", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.timing") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "timer"; label: I18n.t("linux.settings.hudTimeout"); divider: false
			desc: I18n.t("linux.settings.hideAfter", { seconds: (root.store.values["bloom-osd-timeout"] / 1000).toFixed(1) })
			SSlider { objectName: "osdTimeout"; accessibleName: I18n.t("linux.settings.hudTimeout"); theme: root.theme; from: 500; to: 5000; step: 250; value: root.store.values["bloom-osd-timeout"]; onMoved: value => root.store.set("bloom-osd-timeout", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.notifications") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "bell-off"; label: I18n.t("linux.settings.doNotDisturb"); desc: I18n.t("linux.settings.keepNotificationsQuiet")
			SToggle { objectName: "dnd"; accessibleName: I18n.t("linux.settings.doNotDisturb"); theme: root.theme; checked: root.store.values["bloom-notifications-dnd"]; onToggled: value => root.store.set("bloom-notifications-dnd", value) }
		}
		SRow {
			theme: root.theme; icon: "timer"; label: I18n.t("linux.settings.bannerTimeout"); desc: I18n.t("linux.settings.hideAfter", { seconds: (root.store.values["bloom-notifications-timeout"] / 1000).toFixed(1) })
			SSlider { accessibleName: I18n.t("linux.settings.bannerTimeout"); theme: root.theme; from: 1000; to: 30000; step: 500; value: root.store.values["bloom-notifications-timeout"]; onMoved: value => root.store.set("bloom-notifications-timeout", value) }
		}
		SRow {
			theme: root.theme; icon: "archive"; label: I18n.t("linux.settings.history"); desc: I18n.t("linux.settings.keepHistory", { count: root.store.values["bloom-notifications-history-limit"] }); divider: false
			SSlider { accessibleName: I18n.t("linux.settings.history"); theme: root.theme; from: 0; to: 500; step: 10; value: root.store.values["bloom-notifications-history-limit"]; onMoved: value => root.store.set("bloom-notifications-history-limit", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.volumeProtection") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "volume-2"; label: I18n.t("linux.settings.protectMyEars"); desc: I18n.t("linux.settings.stopSuddenJumpsAndLimitTheMaximum"); divider: root._protect
			SToggle { objectName: "protect"; accessibleName: I18n.t("linux.settings.protectMyEars"); theme: root.theme; checked: root._protect; onToggled: value => root.store.set("bloom-volume-protection-enabled", value) }
		}
		SRow {
			objectName: "maxJump"
			visible: root._protect
			theme: root.theme; icon: "sliders-vertical"; label: I18n.t("linux.settings.largestJump"); desc: I18n.t("linux.settings.volumeJump", { percent: root.store.values["bloom-volume-max-jump"] })
			SSlider { accessibleName: I18n.t("linux.settings.largestJump"); theme: root.theme; from: 1; to: 50; step: 1; value: root.store.values["bloom-volume-max-jump"]; onMoved: value => root.store.set("bloom-volume-max-jump", value) }
		}
		SRow {
			visible: root._protect
			theme: root.theme; icon: "volume-2"; label: I18n.t("linux.settings.volumeLimit"); desc: root.store.values["bloom-volume-max-level"] + "%"; divider: false
			SSlider { accessibleName: I18n.t("linux.settings.volumeLimit"); theme: root.theme; from: 20; to: 150; step: 1; value: root.store.values["bloom-volume-max-level"]; onMoved: value => root.store.set("bloom-volume-max-level", value) }
		}
	}
}
