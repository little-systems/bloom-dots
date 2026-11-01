import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "logic.js" as Logic

// Bloom's NotchTab. Timer Sound stays out until the port has a chime.
Column {
	id: root
	property QtObject theme
	property var store
	property Item popup
	property var cityResults: []
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

	SGroupLabel { theme: root.theme; text: "Notch"; above: 0 }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "panel-top"; label: "Notch Behavior"; desc: "Choose how the notch appears"; divider: root._peek
			SSelect { accessibleName: "Notch Behavior";
				objectName: "notchMode"; theme: root.theme; popup: root.popup; value: root._v["bloom-notch-mode"]
				options: [{ value: "fixed", label: "Fixed" }, { value: "smart", label: "Smart" }, { value: "peek", label: "Peek" }]
				onActivated: value => root.set("bloom-notch-mode", value)
			}
		}
		SRow {
			objectName: "notchPeek"
			visible: root._peek
			theme: root.theme; icon: "timer"; label: "Peek Delay"; divider: false
			desc: root._delay === 0 ? "Reveal instantly on top-edge contact" : "Rest on the top edge for " + root._delay + "ms to reveal"
			SSlider { accessibleName: "Peek Delay"; theme: root.theme; from: 0; to: 800; step: 50; value: root._delay; onMoved: value => root.set("bloom-notch-edge-delay", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: "Panels" }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "calendar"; label: "Calendar & Timer"; desc: "Enable productivity split-view"
			SToggle { accessibleName: "Calendar & Timer"; objectName: "calendar"; theme: root.theme; enabled: !(root._calendar && root._lastPanel); checked: root._calendar; onToggled: value => root.set("bloom-calendar-enabled", value) }
		}
		SRow {
			objectName: "timerSound"
			visible: root._calendar
			theme: root.theme; icon: "bell-ring"; label: "Timer Sound"; desc: "Play a chime when the timer finishes"
			SToggle { accessibleName: "Timer Sound"; theme: root.theme; checked: root._v["bloom-timer-sound-enabled"]; onToggled: value => root.set("bloom-timer-sound-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "sliders-horizontal"; label: "Command Center"; desc: "Quick toggles, Wi-Fi and Bluetooth"
			SToggle { accessibleName: "Command Center"; theme: root.theme; enabled: !(root._command && root._lastPanel); checked: root._command; onToggled: value => root.set("bloom-notch-command-center-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "headphones"; label: "Connected Devices"; desc: "Batteries and audio of your connected devices"
			SToggle { accessibleName: "Connected Devices"; theme: root.theme; enabled: !(root._devices && root._lastPanel); checked: root._devices; onToggled: value => root.set("bloom-notch-devices-enabled", value) }
		}
		SRow {
			theme: root.theme; icon: "panel-top"; label: "Remember Last Panel"; desc: "Reopen the panel you last used; turn off to choose a fixed default"; divider: !root._memory
			SToggle { accessibleName: "Remember Last Panel"; objectName: "memory"; theme: root.theme; checked: root._memory; onToggled: value => root.set("bloom-notch-panel-memory", value) }
		}
		SRow {
			objectName: "defaultPanel"
			visible: !root._memory
			theme: root.theme; icon: "panel-top"; label: "Default Panel"; desc: "Open this panel when you click the notch"; divider: false
			SSelect { accessibleName: "Default Panel";
				theme: root.theme; popup: root.popup; value: root._v["bloom-notch-default-panel"]
				options: [
					{ value: "calendar", label: "Calendar & Timer", on: root._calendar },
					{ value: "command-center", label: "Command Center", on: root._command },
					{ value: "devices", label: "Connected Devices", on: root._devices }
				].filter(o => o.on)
				onActivated: value => root.set("bloom-notch-default-panel", value)
			}
		}
	}

	SGroupLabel { theme: root.theme; text: "Music" }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "music"; label: "Music Mode"; desc: "Interactive live music widget"; divider: false
			SToggle { accessibleName: "Music Mode"; objectName: "music"; theme: root.theme; checked: root._music; onToggled: value => root.set("bloom-music-mode-enabled", value) }
		}
		SDisclosure {
			visible: root._music
			theme: root.theme; summary: "Music options"; hint: "Layout and visual effects"
			SRow {
				theme: root.theme; icon: "minimize-2"; label: "Compact Mode"; desc: "Show visualizer & artwork when collapsed"
				SToggle { accessibleName: "Compact Mode"; theme: root.theme; checked: root._v["bloom-music-compact-notch"]; onToggled: value => root.set("bloom-music-compact-notch", value) }
			}
			SRow {
				theme: root.theme; icon: "layout-list"; label: "Media Layout"; desc: "Choose expanded player style"
				SUnitToggle {
					theme: root.theme; wide: true; value: root._v["bloom-media-layout"]
					options: [{ value: "classic", label: "Classic" }, { value: "compact", label: "Compact" }]
					onActivated: value => root.set("bloom-media-layout", value)
				}
			}
			SRow {
				theme: root.theme; icon: "sliders-vertical"; label: "Visualizer"; desc: "Show the audio bars"
				SToggle { accessibleName: "Visualizer"; theme: root.theme; checked: root._v["bloom-media-visualizer-enabled"]; onToggled: value => root.set("bloom-media-visualizer-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "music"; label: "Album Art"; desc: "Show artwork in the notch"
				SToggle { accessibleName: "Album Art"; theme: root.theme; checked: root._v["bloom-media-album-art-enabled"]; onToggled: value => root.set("bloom-media-album-art-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "sparkles"; label: "Ambient Glow"; desc: "Colored glow behind expanded album art"
				SToggle { accessibleName: "Ambient Glow"; theme: root.theme; checked: root._v["bloom-media-ambience-enabled"]; onToggled: value => root.set("bloom-media-ambience-enabled", value) }
			}
			SRow {
				theme: root.theme; icon: "circle"; label: "Compact Glow"; desc: "Glow around collapsed thumbnail"; divider: false
				SToggle { accessibleName: "Compact Glow"; theme: root.theme; checked: root._v["bloom-media-compact-glow-enabled"]; onToggled: value => root.set("bloom-media-compact-glow-enabled", value) }
			}
		}
	}

	SGroupLabel { theme: root.theme; text: "Shelf" }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "archive"; label: "Keep Items"; desc: "Keep shelf items after Bloom closes"; divider: false
			SToggle { accessibleName: "Keep Items"; theme: root.theme; checked: root._v["bloom-shelf-persist"]; onToggled: value => root.set("bloom-shelf-persist", value) }
		}
	}

	SGroupLabel { theme: root.theme; text: "Weather" }
	SGroup {
		theme: root.theme
		SRow {
			theme: root.theme; icon: "cloud-sun"; label: "Weather Status"; desc: root._city || "Auto-detect location"; divider: root._weather
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
					root.set("bloom-weather-city", text);
					root.cityQueried(text);
				}
				Keys.onReturnPressed: if (root.cityResults.length) root._pick(root.cityResults[0])
				Keys.onEscapePressed: root.cityQueried("")

				Text {
					visible: cityField.text === ""
					anchors.verticalCenter: parent.verticalCenter
					text: "Search city..."
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
							HoverHandler { id: cityHover; cursorShape: Qt.PointingHandCursor }
							TapHandler { onTapped: root._pick(cityItem.modelData) }
						}
					}
				}
			}
		}
	}

	SGroupLabel { theme: root.theme; text: "Widgets" }
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
