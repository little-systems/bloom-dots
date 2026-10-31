import QtQuick
import "../common/render"
import "../common/tokens.js" as Tokens

// Bloom's AppearanceTab. Screen Corners stays out: Hyprland rounds them.
Column {
	id: root
	property QtObject theme
	property var store
	property Item popup
	signal colorRequested()
	property bool _fontMissing: false

	readonly property string _mode: root.store.values["bloom-theme-mode"]
	readonly property bool _custom: root._mode === "custom"
	readonly property bool _advanced: root._mode === "custom" || root._mode === "adaptive"
	readonly property real _scale: root.store.values["bloom-scale"]

	width: parent.width

	SGroupLabel { theme: root.theme; text: "Theme"; above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "palette"; label: "Theme Mode"; desc: "Configure visual styling"
			SSelect { accessibleName: "Theme Mode";
				objectName: "themeMode"
				theme: root.theme
				popup: root.popup
				options: [{ value: "dark", label: "Dark (Translucent)" }, { value: "light", label: "Light (Translucent)" }, { value: "custom", label: "Custom Color" }, { value: "adaptive", label: "Adaptive Accent" }]
				value: root._mode
				onActivated: value => root.store.set("bloom-theme-mode", value)
			}
		}
		SRow {
			visible: root._custom
			theme: root.theme; icon: "droplet"; label: "Custom Theme Color"; desc: "Choose layout background color"
			Row {
				spacing: Tokens.settings.color.gap
				Rectangle {
					objectName: "color"
					width: Tokens.settings.color.size
					height: width
					radius: width / 2
					color: root.store.values["bloom-theme-color"]
					TapHandler { onTapped: root.colorRequested() }
					HoverHandler { cursorShape: Qt.PointingHandCursor }
				}
				Text {
					anchors.verticalCenter: parent.verticalCenter
					text: String(root.store.values["bloom-theme-color"]).toUpperCase()
					color: root.theme.textMuted
					font.family: Fonts.uiFor(Font.DemiBold)
					font.pixelSize: Tokens.settings.color.text
					font.weight: Font.DemiBold
				}
			}
		}
		SRow {
			theme: root.theme; icon: "contrast"; label: "Background Opacity"
			desc: "Adjust theme transparency (" + Math.round(root.store.values["bloom-theme-opacity"] * 100) + "%)"
			SSlider { accessibleName: "Background Opacity"; objectName: "opacity"; theme: root.theme; from: 0.1; to: 1; step: 0.05; value: root.store.values["bloom-theme-opacity"]; onMoved: value => root.store.set("bloom-theme-opacity", value) }
		}
		SRow {
			theme: root.theme; icon: "layers"; label: "Translucent Apps"; divider: root._advanced
			desc: "Use this opacity and blur on windows and the terminal"
			SToggle { objectName: "translucent"; accessibleName: "Translucent Apps"; theme: root.theme; checked: root.store.values["bloom-translucent-apps"]; onToggled: value => root.store.set("bloom-translucent-apps", value) }
		}
		SRow {
			visible: root._advanced
			theme: root.theme; icon: "droplets"; label: "Color Saturation"
			desc: "Adjust theme color vibrancy (" + Math.round(root.store.values["bloom-theme-saturation"] * 100) + "%)"
			SSlider { theme: root.theme; from: 0; to: 1; step: 0.02; value: root.store.values["bloom-theme-saturation"]; onMoved: value => root.store.set("bloom-theme-saturation", value) }
		}
		SRow {
			visible: root._advanced
			theme: root.theme; icon: "sun"; label: "Background Brightness"; divider: false
			desc: "Adjust background lightness (" + Math.round(root.store.values["bloom-theme-brightness"] * 100) + "%)"
			SSlider { accessibleName: "Background Brightness"; theme: root.theme; from: 0; to: 1; step: 0.02; value: root.store.values["bloom-theme-brightness"]; onMoved: value => root.store.set("bloom-theme-brightness", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: "Text" }
	SGroup {
		theme: root.theme
		SRow {
			objectName: "fontRow"
			theme: root.theme; icon: "type"; label: "Font"; divider: false
			readonly property string family: root.store.values["bloom-font-family"]
			desc: root._fontMissing ? "That font isn't installed" : family === "" ? "Bloom's own" : family
			SField {
				objectName: "font"
				width: 160
				theme: root.theme
				placeholder: "Font name"
				accessibleName: "Font"
				text: root.store.values["bloom-font-family"]
				onAccepted: {
					const name = text.trim();
					// A font that isn't there would silently fall back, so it isn't saved.
					root._fontMissing = name !== "" && Qt.fontFamilies().indexOf(name) < 0;
					if (!root._fontMissing) root.store.set("bloom-font-family", name);
				}
			}
		}
	}

	SGroupLabel { theme: root.theme; text: "Display" }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "maximize-2"; label: "UI & Font Scale"; divider: false
			desc: "Adjust desktop size (" + Math.round(root._scale * 100) + "%)"
			Rectangle {
				width: scaleRow.width + 2 * Tokens.settings.scale.paddingH + 2
				height: scaleRow.height + 2 * Tokens.settings.scale.paddingV + 2
				radius: Tokens.settings.scale.radius
				color: root.theme.groupBg
				border.width: 1
				border.color: root.theme.border
				Row {
					id: scaleRow
					anchors.centerIn: parent
					spacing: Tokens.settings.scale.gap
					Repeater {
						model: [{ id: "down", glyph: "—", step: -0.1 }, { id: "value" }, { id: "up", glyph: "+", step: 0.1 }]
						delegate: Item {
							id: cell
							required property var modelData
							readonly property bool isValue: cell.modelData.id === "value"
							readonly property real next: cell.isValue ? 0 : Math.round((root._scale + cell.modelData.step) * 10) / 10
							readonly property bool usable: !cell.isValue && cell.next >= 0.8 && cell.next <= 1.3
							objectName: "scale:" + cell.modelData.id
							width: cell.isValue ? Tokens.settings.scale.value : Tokens.settings.scale.button
							height: Tokens.settings.scale.button
							Rectangle {
								anchors.fill: parent
								radius: 4
								visible: !cell.isValue && cellHover.hovered && cell.usable
								color: root.theme.border
							}
							Text {
								anchors.centerIn: parent
								text: cell.isValue ? Math.round(root._scale * 100) + "%" : cell.modelData.glyph
								opacity: cell.isValue || cell.usable ? 1 : 0.25
								color: root.theme.text
								font.family: Fonts.uiFor(cell.isValue ? Font.DemiBold : Font.Bold)
								font.pixelSize: Tokens.settings.scale.size
								font.weight: cell.isValue ? Font.DemiBold : Font.Bold
							}
							HoverHandler { id: cellHover; cursorShape: cell.isValue ? Qt.ArrowCursor : Qt.PointingHandCursor }
							TapHandler { enabled: cell.usable; onTapped: root.store.set("bloom-scale", cell.next) }
						}
					}
				}
			}
		}
	}
}
