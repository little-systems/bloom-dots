import QtQuick
import "../common/tokens.js" as Tokens

// Bloom's OverlaysTab.
Column {
	id: root
	property QtObject theme
	property var store

	readonly property bool _volume: root.store.values["bloom-volume-hud-enabled"]
	readonly property bool _brightness: root.store.values["bloom-brightness-hud-enabled"]

	width: parent.width

	SGroupLabel { theme: root.theme; text: "Overlays"; above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "volume-2"; label: "Volume HUD"; desc: "Bloom volume overlay"
			SToggle { objectName: "volume"; theme: root.theme; checked: root._volume; onToggled: value => root.store.set("bloom-volume-hud-enabled", value) }
		}
		SRow {
			objectName: "volumeEdge"
			visible: root._volume
			height: visible ? implicitHeight : 0
			implicitHeight: 50.8
			theme: root.theme; icon: "arrow-left-to-line"; label: "Show on Edge Hover"; desc: "Slide in from left edge"
			SToggle { theme: root.theme; checked: root.store.values["bloom-volume-edge-enabled"]; onToggled: value => root.store.set("bloom-volume-edge-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "sun"; label: "Brightness HUD"; desc: "Bloom brightness overlay"; divider: root._brightness
			SToggle { theme: root.theme; checked: root._brightness; onToggled: value => root.store.set("bloom-brightness-hud-enabled", value) }
		}
		SRow {
			visible: root._brightness
			height: visible ? implicitHeight : 0
			implicitHeight: 49.8
			theme: root.theme; icon: "arrow-right-to-line"; label: "Show on Edge Hover"; desc: "Slide in from right edge"; divider: false
			SToggle { theme: root.theme; checked: root.store.values["bloom-brightness-edge-enabled"]; onToggled: value => root.store.set("bloom-brightness-edge-enabled", value) }
		}
	}
}
