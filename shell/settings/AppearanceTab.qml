import QtQuick
import "../common/render"
import "../common/tokens.js" as Tokens
import "../common/i18n"

// Bloom's AppearanceTab.
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

	SGroupLabel { theme: root.theme; text: I18n.t("settings.groups.theme"); above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "palette"; label: I18n.t("settings.appearance.themeMode"); desc: I18n.t("settings.appearance.themeModeDesc")
			SSelect { accessibleName: I18n.t("settings.appearance.themeMode");
				objectName: "themeMode"
				theme: root.theme
				popup: root.popup
				options: [{ value: "dark", label: I18n.t("settings.appearance.themeDark") }, { value: "light", label: I18n.t("settings.appearance.themeLight") }, { value: "custom", label: I18n.t("settings.appearance.themeCustom") }, { value: "adaptive", label: I18n.t("settings.appearance.themeAdaptive") }]
				value: root._mode
				onActivated: value => root.store.set("bloom-theme-mode", value)
			}
		}
		SRow {
			visible: root._custom
			theme: root.theme; icon: "droplet"; label: I18n.t("settings.appearance.customColor"); desc: I18n.t("settings.appearance.customColorDesc")
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
					font.pixelSize: Fonts.px(Tokens.settings.color.text)
					font.weight: Font.DemiBold
				}
			}
		}
		SRow {
			theme: root.theme; icon: "contrast"; label: I18n.t("settings.appearance.opacity"); divider: root._advanced
			desc: I18n.t("linux.settings.backgroundOpacity", { percent: Math.round(root.store.values["bloom-theme-opacity"] * 100) })
			SSlider { accessibleName: I18n.t("settings.appearance.opacity"); objectName: "opacity"; theme: root.theme; from: 0.6; to: 1; step: 0.05; value: root.store.values["bloom-theme-opacity"]; onMoved: value => root.store.set("bloom-theme-opacity", value) }
		}
		SRow {
			visible: root._advanced
			theme: root.theme; icon: "droplets"; label: I18n.t("settings.appearance.saturation")
			desc: I18n.t("linux.settings.backgroundSaturation", { percent: Math.round(root.store.values["bloom-theme-saturation"] * 100) })
			SSlider { theme: root.theme; from: 0; to: 1; step: 0.02; value: root.store.values["bloom-theme-saturation"]; onMoved: value => root.store.set("bloom-theme-saturation", value) }
		}
		SRow {
			visible: root._advanced
			theme: root.theme; icon: "sun"; label: I18n.t("settings.appearance.brightness"); divider: false
			desc: I18n.t("linux.settings.backgroundBrightness", { percent: Math.round(root.store.values["bloom-theme-brightness"] * 100) })
			SSlider { accessibleName: I18n.t("settings.appearance.brightness"); theme: root.theme; from: 0; to: 1; step: 0.02; value: root.store.values["bloom-theme-brightness"]; onMoved: value => root.store.set("bloom-theme-brightness", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.screen") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "sparkles"; label: I18n.t("ui.appearanceTab.edgeShine"); desc: I18n.t("ui.appearanceTab.softReflectionsAroundTheDockAndNotchTurnOffIf")
			SToggle { objectName: "edgeShine"; accessibleName: I18n.t("ui.appearanceTab.edgeShine"); theme: root.theme; checked: root.store.values["bloom-edge-shine-enabled"]; onToggled: value => root.store.set("bloom-edge-shine-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "square"; label: I18n.t("settings.appearance.corners"); desc: I18n.t("linux.settings.roundedCornersHiddenOverFullscreen"); divider: false
			SToggle { objectName: "screenCorners"; accessibleName: I18n.t("settings.appearance.corners"); theme: root.theme; checked: root.store.values["bloom-corners-enabled"]; onToggled: value => root.store.set("bloom-corners-enabled", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.text") }
	SGroup {
		theme: root.theme
		SRow {
			objectName: "fontRow"
			theme: root.theme; icon: "type"; label: I18n.t("linux.settings.font"); divider: false
			readonly property string family: root.store.values["bloom-font-family"]
			desc: root._fontMissing ? I18n.t("linux.settings.thatFontIsnTInstalled") : family === "" ? I18n.t("linux.settings.bloomSOwn") : family
			SField {
				objectName: "font"
				width: 160
				theme: root.theme
				placeholder: I18n.t("linux.settings.fontName")
				accessibleName: I18n.t("linux.settings.font")
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

	SGroupLabel { theme: root.theme; text: I18n.t("settings.groups.display") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "maximize-2"; label: I18n.t("linux.settings.uiScale"); divider: true
			desc: I18n.t("linux.settings.uiScaleDescription", { percent: Math.round(root._scale * 100) })
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
								visible: !cell.isValue
								text: cell.modelData.glyph || ""
								opacity: cell.isValue || cell.usable ? 1 : 0.25
								color: root.theme.text
								font.family: Fonts.uiFor(cell.isValue ? Font.DemiBold : Font.Bold)
								font.pixelSize: Fonts.px(Tokens.settings.scale.size)
								font.weight: cell.isValue ? Font.DemiBold : Font.Bold
							}
							SNumber {
								visible: cell.isValue
								anchors.centerIn: parent; width: 60; height: 26
								theme: root.theme; from: 0.8; to: 1.3; value: root._scale; factor: 100; suffix: "%"
								accessibleName: I18n.t("linux.settings.uiScale2")
								onEdited: value => root.store.set("bloom-scale", value)
							}
							HoverHandler { id: cellHover; cursorShape: cell.isValue ? Qt.ArrowCursor : Qt.PointingHandCursor }
							TapHandler { enabled: cell.usable; onTapped: root.store.set("bloom-scale", cell.next) }
						}
					}
				}
			}
		}
		SRow {
			theme: root.theme; icon: "type"; label: I18n.t("linux.settings.fontScale"); divider: false
			desc: I18n.t("linux.settings.textSizeIndependentOfPanelSize")
			SSlider {
				objectName: "fontScale"; accessibleName: I18n.t("linux.settings.fontScale2")
				displayFactor: 100; displaySuffix: "%"
				theme: root.theme; from: 0.8; to: 1.6; step: 0.05
				value: root.store.values["bloom-font-scale"] || 1.15
				onMoved: value => root.store.set("bloom-font-scale", value)
			}
		}

	}
}
