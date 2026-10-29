import QtQuick
import "../../common/tokens.js" as Tokens
import "qp"

// Bloom's Command Center (App.tsx .command-center-content-minimal): four
// tiles, six round buttons and two sliders, spread top to bottom with
// justify-content: space-between. Pure: CommandCenter.qml binds the services.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property bool light: false

	// Wi-Fi: `wifiKnown` is false until the first status arrives (Bloom's "…").
	property bool wifiKnown: false
	property bool wifiEnabled: false
	property bool wifiConnected: false
	property string ssid: ""
	property bool bluetoothPowered: false
	property var bluetoothNames: []
	property string dockMode: "smart"
	property string notchMode: "smart"
	property bool dnd: false
	property bool energySaver: false
	property real volume: 0
	// A whole percent, or -1 when there's no backlight to set.
	property int brightness: -1

	signal wifiToggled()
	signal wifiOpened()
	signal bluetoothToggled()
	signal bluetoothOpened()
	signal dockModeCycled()
	signal notchModeCycled()
	signal dndToggled()
	signal energySaverToggled()
	signal trayRequested()
	signal notificationsRequested()
	signal settingsRequested()
	signal restartRequested()
	signal volumeChosen(real value)
	signal brightnessChosen(int percent)

	function _modeName(mode) {
		return mode === "fixed" ? "Fixed" : mode === "smart" ? "Smart" : "Peek";
	}

	readonly property real _top: Tokens.cc.padding.v
	readonly property real _slidersHeight: Tokens.cc.sliders.rowHeight * 2 + Tokens.cc.sliders.gap
	// space-between: the room left over splits into the two gaps.
	readonly property real _gap: Math.max(0, (root.height - Tokens.cc.padding.v * 2 - Tokens.cc.grid.height - Tokens.cc.round.size - root._slidersHeight) / 2)
	readonly property real _tileWidth: (root.width - Tokens.cc.grid.gap) / 2

	Grid {
		y: root._top
		columns: 2
		columnSpacing: Tokens.cc.grid.gap
		rowSpacing: Tokens.cc.grid.height - Tokens.cc.tile.height * 2

		ControlTile {
			objectName: "tile-wifi"
			width: root._tileWidth
			height: Tokens.cc.tile.height
			theme: root.theme
			title: "Wi-Fi"
			icon: "bloom-wifi"
			glyphOpacity: !root.wifiEnabled ? 0.4 : root.wifiConnected ? 1 : 0.7
			status: !root.wifiKnown ? "…" : !root.wifiEnabled ? "Off" : root.wifiConnected ? (root.ssid || "Connected") : "Not connected"
			active: root.wifiEnabled
			hasMore: true
			onClicked: root.wifiToggled()
			onRightClicked: root.wifiOpened()
			onMoreClicked: root.wifiOpened()
		}

		ControlTile {
			objectName: "tile-dock"
			width: root._tileWidth
			height: Tokens.cc.tile.height
			theme: root.theme
			title: "Dock Mode"
			icon: "bloom-dock"
			status: root._modeName(root.dockMode)
			active: root.dockMode === "fixed"
			onClicked: root.dockModeCycled()
		}

		ControlTile {
			objectName: "tile-bluetooth"
			width: root._tileWidth
			height: Tokens.cc.tile.height
			theme: root.theme
			title: "Bluetooth"
			icon: "bloom-bluetooth"
			status: !root.bluetoothPowered ? "Off"
				: root.bluetoothNames.length === 1 ? root.bluetoothNames[0]
				: root.bluetoothNames.length > 1 ? `${root.bluetoothNames.length} connected`
				: "On"
			active: root.bluetoothPowered
			hasMore: true
			onClicked: root.bluetoothToggled()
			onRightClicked: root.bluetoothOpened()
			onMoreClicked: root.bluetoothOpened()
		}

		ControlTile {
			objectName: "tile-notch"
			width: root._tileWidth
			height: Tokens.cc.tile.height
			theme: root.theme
			title: "Notch Mode"
			icon: "bloom-notch"
			status: root._modeName(root.notchMode)
			active: root.notchMode === "fixed"
			onClicked: root.notchModeCycled()
		}
	}

	// .cc-circular-actions-row: padding 0 4px, justify-content: space-between.
	Item {
		id: roundRow
		x: Tokens.cc.round.sidePad
		y: root._top + Tokens.cc.grid.height + root._gap
		width: root.width - Tokens.cc.round.sidePad * 2
		height: Tokens.cc.round.size

		readonly property real step: (width - Tokens.cc.round.size) / 5

		CcRoundButton {
			objectName: "round-dnd"
			x: 0
			theme: root.theme
			icon: "bloom-moon"
			glyphSize: 18
			active: root.dnd
			onClicked: root.dndToggled()
		}

		CcRoundButton {
			objectName: "round-energy"
			x: roundRow.step
			theme: root.theme
			icon: "bloom-battery-saver"
			glyphSize: 18
			active: root.energySaver
			onClicked: root.energySaverToggled()
		}

		CcRoundButton {
			objectName: "round-tray"
			x: roundRow.step * 2
			theme: root.theme
			icon: "bloom-tray"
			onClicked: root.trayRequested()
		}

		CcRoundButton {
			objectName: "round-notifications"
			x: roundRow.step * 3
			theme: root.theme
			icon: "bloom-bell"
			onClicked: root.notificationsRequested()
		}

		CcRoundButton {
			objectName: "round-settings"
			x: roundRow.step * 4
			theme: root.theme
			icon: "bloom-settings"
			glyphOpacity: 0.9
			onClicked: root.settingsRequested()
		}

		CcRoundButton {
			objectName: "round-restart"
			x: roundRow.step * 5
			theme: root.theme
			icon: "bloom-reload"
			onClicked: root.restartRequested()
		}
	}

	Column {
		y: roundRow.y + Tokens.cc.round.size + root._gap
		width: root.width
		spacing: Tokens.cc.sliders.gap

		CcSlider {
			objectName: "slider-volume"
			width: parent.width
			theme: root.theme
			light: root.light
			label: "Volume"
			icon: "sf-speaker.wave.1.fill"
			value: root.volume
			percentText: Math.round(root.volume * 100) + "%"
			onChosen: fraction => root.volumeChosen(fraction)
		}

		CcSlider {
			objectName: "slider-brightness"
			width: parent.width
			theme: root.theme
			light: root.light
			label: "Brightness"
			icon: "bloom-brightness-low"
			available: root.brightness >= 0
			value: root.brightness / 100
			percentText: root.brightness >= 0 ? root.brightness + "%" : "—"
			onChosen: fraction => root.brightnessChosen(Math.round(fraction * 100))
		}
	}
}
