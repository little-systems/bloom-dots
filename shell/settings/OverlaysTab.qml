import QtQuick
import "../common/tokens.js" as Tokens

// Bloom's OverlaysTab.
Column {
	id: root
	property QtObject theme
	property var store

	readonly property bool _volume: root.store.values["bloom-volume-hud-enabled"]
	readonly property bool _protect: root.store.values["bloom-volume-protection-enabled"]
	readonly property bool _brightness: root.store.values["bloom-brightness-hud-enabled"]

	width: parent.width

	SGroupLabel { theme: root.theme; text: "Overlays"; above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "volume-2"; label: "Volume HUD"; desc: "Bloom volume overlay"
			SToggle { accessibleName: "Volume HUD"; objectName: "volume"; theme: root.theme; checked: root._volume; onToggled: value => root.store.set("bloom-volume-hud-enabled", value) }
		}
		SRow {
			objectName: "volumeEdge"
			visible: root._volume
			theme: root.theme; icon: "arrow-left-to-line"; label: "Show on Edge Hover"; desc: "Slide in from left edge"
			SToggle { accessibleName: "Show on Edge Hover"; theme: root.theme; checked: root.store.values["bloom-volume-edge-enabled"]; onToggled: value => root.store.set("bloom-volume-edge-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "sun"; label: "Brightness HUD"; desc: "Bloom brightness overlay"; divider: root._brightness
			SToggle { accessibleName: "Brightness HUD"; theme: root.theme; checked: root._brightness; onToggled: value => root.store.set("bloom-brightness-hud-enabled", value) }
		}
		SRow {
			visible: root._brightness
			theme: root.theme; icon: "arrow-right-to-line"; label: "Show on Edge Hover"; desc: "Slide in from right edge"; divider: false
			SToggle { accessibleName: "Show on Edge Hover"; theme: root.theme; checked: root.store.values["bloom-brightness-edge-enabled"]; onToggled: value => root.store.set("bloom-brightness-edge-enabled", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: "Timing" }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "timer"; label: "HUD Timeout"; divider: false
			desc: "Hide after " + (root.store.values["bloom-osd-timeout"] / 1000).toFixed(1) + " s"
			SSlider { objectName: "osdTimeout"; accessibleName: "HUD Timeout"; theme: root.theme; from: 500; to: 5000; step: 250; value: root.store.values["bloom-osd-timeout"]; onMoved: value => root.store.set("bloom-osd-timeout", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: "Volume Protection" }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "volume-2"; label: "Protect My Ears"; desc: "Stop sudden jumps and limit the maximum"; divider: root._protect
			SToggle { objectName: "protect"; accessibleName: "Protect My Ears"; theme: root.theme; checked: root._protect; onToggled: value => root.store.set("bloom-volume-protection-enabled", value) }
		}
		SRow {
			objectName: "maxJump"
			visible: root._protect
			theme: root.theme; icon: "sliders-vertical"; label: "Largest Jump"; desc: root.store.values["bloom-volume-max-jump"] + "% at a time"
			SSlider { accessibleName: "Largest Jump"; theme: root.theme; from: 1; to: 50; step: 1; value: root.store.values["bloom-volume-max-jump"]; onMoved: value => root.store.set("bloom-volume-max-jump", value) }
		}
		SRow {
			visible: root._protect
			theme: root.theme; icon: "volume-2"; label: "Volume Limit"; desc: root.store.values["bloom-volume-max-level"] + "%"; divider: false
			SSlider { accessibleName: "Volume Limit"; theme: root.theme; from: 20; to: 150; step: 1; value: root.store.values["bloom-volume-max-level"]; onMoved: value => root.store.set("bloom-volume-max-level", value) }
		}
	}
}
