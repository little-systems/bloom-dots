import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "logic.js" as Logic
import "../common/i18n"

// Bloom's NotchTab. Timer Sound stays out until the port has a chime.
Column {
	id: root
	property QtObject theme
	property var store
	property Item popup
	property var cityResults: []

	TypingGuard { id: hoverGuard }
	signal cityQueried(string text)

	readonly property var _v: root.store.values
	readonly property bool _peek: root._v["bloom-notch-mode"] !== "fixed"
	readonly property int _delay: root._v["bloom-notch-edge-delay"]
	readonly property bool _calendar: root._v["bloom-calendar-enabled"]
	readonly property bool _command: root._v["bloom-notch-command-center-enabled"]
	readonly property bool _devices: root._v["bloom-notch-devices-enabled"]
	readonly property bool _lastPanel: Logic.enabledPanels(root._calendar, root._command, root._devices) === 1
	readonly property bool _memory: root._v["bloom-notch-panel-memory"]
	readonly property bool _music: root._v["bloom-music-mode-enabled"]
	readonly property bool _weather: root._v["bloom-weather-enabled"]
	readonly property string _city: root._v["bloom-weather-city"]
	function set(key, value) { root.store.set(key, value); }

	width: parent.width

	SGroupLabel { theme: root.theme; text: I18n.t("settings.tabs.notch"); above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "panel-top"; label: I18n.t("settings.notch.behavior"); desc: I18n.t("settings.notch.behaviorDesc"); divider: root._peek
			SSelect { accessibleName: I18n.t("settings.notch.behavior");
				objectName: "notchMode"; theme: root.theme; popup: root.popup; value: root._v["bloom-notch-mode"]
				options: [{ value: "fixed", label: I18n.t("common.behavior.fixed") }, { value: "smart", label: I18n.t("common.behavior.smart") }, { value: "peek", label: I18n.t("common.behavior.peek") }]
				onActivated: value => root.set("bloom-notch-mode", value)
			}
		}
		SRow {
			objectName: "notchPeek"
			visible: root._peek
			theme: root.theme; icon: "timer"; label: I18n.t("settings.notch.peekDelay"); divider: false
			desc: root._delay === 0 ? I18n.t("settings.notch.peekInstant") : I18n.t("ui.notchTab.restOnTheTopEdgeForNotchedgedelayMsToReveal", { notchEdgeDelay: root._delay })
			SSlider { accessibleName: I18n.t("settings.notch.peekDelay"); theme: root.theme; from: 0; to: 800; step: 50; value: root._delay; onMoved: value => root.set("bloom-notch-edge-delay", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("ui.notchTab.panels") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "calendar"; label: I18n.t("settings.notch.calendar"); desc: I18n.t("settings.notch.calendarDesc")
			SToggle { accessibleName: I18n.t("settings.notch.calendar"); objectName: "calendar"; theme: root.theme; enabled: !(root._calendar && root._lastPanel); checked: root._calendar; onToggled: value => root.set("bloom-calendar-enabled", value) }
		}
		SRow {
			objectName: "mondayFirstRow"
			visible: root._calendar
			theme: root.theme; icon: "calendar"; label: I18n.t("ui.notchTab.mondayFirstCalendar"); desc: I18n.t("ui.notchTab.startEachWeekOnMondayInsteadOfSunday")
			SToggle { objectName: "mondayFirst"; accessibleName: I18n.t("ui.notchTab.mondayFirstCalendar"); theme: root.theme; checked: root._v["bloom-calendar-monday-first"]; onToggled: value => root.set("bloom-calendar-monday-first", value) }
		}
		SRow {
			objectName: "timerSound"
			visible: root._calendar
			theme: root.theme; icon: "bell-ring"; label: I18n.t("settings.notch.timerSound"); desc: I18n.t("settings.notch.timerSoundDesc")
			SToggle { accessibleName: I18n.t("settings.notch.timerSound"); theme: root.theme; checked: root._v["bloom-timer-sound-enabled"]; onToggled: value => root.set("bloom-timer-sound-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "sliders-horizontal"; label: I18n.t("ui.notchTab.commandCenter"); desc: I18n.t("ui.notchTab.quickTogglesWiFiAndBluetooth")
			SToggle { accessibleName: I18n.t("ui.notchTab.commandCenter"); theme: root.theme; enabled: !(root._command && root._lastPanel); checked: root._command; onToggled: value => root.set("bloom-notch-command-center-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "headphones"; label: I18n.t("ui.notchTab.connectedDevices"); desc: I18n.t("ui.notchTab.batteriesAndAudioOfYourConnectedDevices")
			SToggle { accessibleName: I18n.t("ui.notchTab.connectedDevices"); theme: root.theme; enabled: !(root._devices && root._lastPanel); checked: root._devices; onToggled: value => root.set("bloom-notch-devices-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "panel-top"; label: I18n.t("ui.notchTab.rememberLastPanel"); desc: I18n.t("ui.notchTab.reopenThePanelYouLastUsedTurnOffToChoose"); divider: !root._memory
			SToggle { accessibleName: I18n.t("ui.notchTab.rememberLastPanel"); objectName: "memory"; theme: root.theme; checked: root._memory; onToggled: value => root.set("bloom-notch-panel-memory", value) }
		}
		SRow {
			objectName: "defaultPanel"
			visible: !root._memory
			theme: root.theme; icon: "panel-top"; label: I18n.t("ui.notchTab.defaultPanel"); desc: I18n.t("ui.notchTab.openThisPanelWhenYouClickTheNotch"); divider: false
			SSelect { accessibleName: I18n.t("ui.notchTab.defaultPanel");
				theme: root.theme; popup: root.popup; value: root._v["bloom-notch-default-panel"]
				options: [
					{ value: "calendar", label: I18n.t("settings.notch.calendar"), on: root._calendar },
					{ value: "command-center", label: I18n.t("ui.notchTab.commandCenter"), on: root._command },
					{ value: "devices", label: I18n.t("ui.notchTab.connectedDevices"), on: root._devices }
				].filter(o => o.on)
				onActivated: value => root.set("bloom-notch-default-panel", value)
			}
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("ui.dockExtras.music") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "music"; label: I18n.t("settings.notch.music"); desc: I18n.t("settings.notch.musicDesc"); divider: false
			SToggle { accessibleName: I18n.t("settings.notch.music"); objectName: "music"; theme: root.theme; checked: root._music; onToggled: value => root.set("bloom-music-mode-enabled", value) }
		}
		SDisclosure {
			visible: root._music
			theme: root.theme; summary: "Music options"; hint: "Layout and visual effects"
			SRow {
				theme: root.theme; icon: "minimize-2"; label: I18n.t("settings.notch.compact"); desc: I18n.t("settings.notch.compactDesc")
				SToggle { accessibleName: I18n.t("settings.notch.compact"); theme: root.theme; checked: root._v["bloom-music-compact-notch"]; onToggled: value => root.set("bloom-music-compact-notch", value) }
			}
			SRow {
				theme: root.theme; icon: "layout-list"; label: I18n.t("settings.notch.mediaLayout"); desc: I18n.t("settings.notch.mediaLayoutDesc")
				SUnitToggle {
					theme: root.theme; wide: true; value: root._v["bloom-media-layout"]
					options: [{ value: "classic", label: I18n.t("common.mediaLayout.classic") }, { value: "compact", label: I18n.t("common.mediaLayout.compact") }]
					onActivated: value => root.set("bloom-media-layout", value)
				}
			}
			SRow {
				theme: root.theme; icon: "sliders-vertical"; label: I18n.t("linux.settings.visualizer"); desc: I18n.t("linux.settings.showTheAudioBars")
				SToggle { accessibleName: I18n.t("linux.settings.visualizer"); theme: root.theme; checked: root._v["bloom-media-visualizer-enabled"]; onToggled: value => root.set("bloom-media-visualizer-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "music"; label: I18n.t("linux.settings.albumArt"); desc: I18n.t("linux.settings.showArtworkInTheNotch")
				SToggle { accessibleName: I18n.t("linux.settings.albumArt"); theme: root.theme; checked: root._v["bloom-media-album-art-enabled"]; onToggled: value => root.set("bloom-media-album-art-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "sparkles"; label: I18n.t("settings.notch.ambience"); desc: I18n.t("settings.notch.ambienceDesc")
				SToggle { accessibleName: I18n.t("settings.notch.ambience"); theme: root.theme; checked: root._v["bloom-media-ambience-enabled"]; onToggled: value => root.set("bloom-media-ambience-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "circle"; label: I18n.t("settings.notch.compactGlow"); desc: I18n.t("settings.notch.compactGlowDesc"); divider: false
				SToggle { accessibleName: I18n.t("settings.notch.compactGlow"); theme: root.theme; checked: root._v["bloom-media-compact-glow-enabled"]; onToggled: value => root.set("bloom-media-compact-glow-enabled", value) }
			}
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("ui.notchTab.shelf") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "archive"; label: I18n.t("ui.notchTab.keepItems"); desc: I18n.t("ui.notchTab.keepShelfItemsAfterBloomCloses"); divider: false
			SToggle { accessibleName: I18n.t("ui.notchTab.keepItems"); theme: root.theme; checked: root._v["bloom-shelf-persist"]; onToggled: value => root.set("bloom-shelf-persist", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("settings.groups.weather") }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "cloud-sun"; label: I18n.t("settings.notch.weather"); desc: root._city || I18n.t("settings.notch.weatherAuto"); divider: root._weather
			Row {
				spacing: 12
				SUnitToggle {
					anchors.verticalCenter: parent.verticalCenter
					theme: root.theme; value: root._v["bloom-temp-unit"]
					options: [{ value: "celsius", label: "C" }, { value: "fahrenheit", label: "F" }]
					onActivated: value => root.set("bloom-temp-unit", value)
				}
				SToggle { objectName: "weather"; theme: root.theme; checked: root._weather; onToggled: value => root.set("bloom-weather-enabled", value) }
			}
		}
		Item {
			visible: root._weather
			width: parent.width
			height: visible ? cityField.height + 8 + (cityList.visible ? cityList.height + 4 : 0) : 0

			TextInput {
				id: cityField
				objectName: "city"
				x: Tokens.settings.row.inset
				y: 4
				width: parent.width - Tokens.settings.row.inset - 34
				height: 24
				verticalAlignment: TextInput.AlignVCenter
				text: root._city
				color: root.theme.text
				clip: true
				font.family: Fonts.ui
				font.pixelSize: Fonts.px(14)
				onTextEdited: {
					hoverGuard.typed();
					root.set("bloom-weather-city", text);
					root.cityQueried(text);
				}
				Keys.onReturnPressed: if (root.cityResults.length) root._pick(root.cityResults[0])
				Keys.onEscapePressed: root.cityQueried("")

				Text {
					visible: cityField.text === ""
					anchors.verticalCenter: parent.verticalCenter
					text: I18n.t("settings.notch.cityPlaceholder")
					color: root.theme.textMuted
					font: cityField.font
				}
			}
			Item {
				objectName: "cityClear"
				visible: root._city !== ""
				x: parent.width - 14 - width
				y: cityField.y + (cityField.height - height) / 2
				width: 14
				height: 14
				SvgIcon { anchors.centerIn: parent; name: "x"; size: 10; strokeWidth: 2.5; color: root.theme.textMuted }
				HoverHandler { cursorShape: Qt.PointingHandCursor }
				TapHandler {
					onTapped: {
						root.set("bloom-weather-lat", null);
						root.set("bloom-weather-lon", null);
						root.set("bloom-weather-city", "");
						root.cityQueried("");
					}
				}
			}
			Rectangle {
				id: cityList
				visible: root.cityResults.length > 0
				x: Tokens.settings.row.inset
				y: cityField.y + cityField.height + 4
				width: parent.width - Tokens.settings.row.inset - 14
				height: cityColumn.implicitHeight + 8
				radius: 8
				color: root.theme.groupBg
				border.width: 1
				border.color: root.theme.border
				Column {
					id: cityColumn
					x: 4
					y: 4
					width: parent.width - 8
					Repeater {
						model: root.cityResults
						delegate: Rectangle {
							id: cityItem
							required property var modelData
							objectName: "cityResult:" + cityItem.modelData.name
							width: cityColumn.width
							height: 27
							radius: 5
							color: cityHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
							Text {
								x: 8
								anchors.verticalCenter: parent.verticalCenter
								text: cityItem.modelData.name
								textFormat: Text.PlainText
								color: root.theme.text
								font.family: Fonts.uiFor(Font.Medium)
								font.pixelSize: Fonts.px(14)
								font.weight: Font.Medium
							}
							Text {
								x: parent.width - width - 8
								anchors.verticalCenter: parent.verticalCenter
								text: cityItem.modelData.country
								textFormat: Text.PlainText
								color: root.theme.textMuted
								font.family: Fonts.ui
								font.pixelSize: Fonts.px(12)
							}
							HoverHandler { id: cityHover; enabled: !hoverGuard.typing; cursorShape: Qt.PointingHandCursor }
							TapHandler { onTapped: root._pick(cityItem.modelData) }
						}
					}
				}
			}
		}
	}

	SGroupLabel { theme: root.theme; text: I18n.t("settings.groups.widgets") }
	SGroup {
		theme: root.theme
		SDisclosure {
			theme: root.theme; standalone: true; summary: "Choose status widgets"; hint: "Arrange what appears beside the clock"
			StatusWidgets {
				objectName: "widgets"
				theme: root.theme
				config: root._v["bloom-status-widgets"]
				onChanged: config => root.set("bloom-status-widgets", config)
			}
		}
	}

	function _pick(city) {
		root.set("bloom-weather-city", city.name);
		root.set("bloom-weather-lat", city.latitude);
		root.set("bloom-weather-lon", city.longitude);
		root.cityQueried("");
	}
}
