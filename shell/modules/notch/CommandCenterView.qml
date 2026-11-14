import QtQuick
import "../../common/tokens.js" as Tokens
import "qp"

// Bloom's Command Center (App.tsx .command-center-content-minimal): four
// tiles, five round buttons and two sliders, spread top to bottom with
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
	property bool muted: false
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
	signal settingsRequested()
	signal restartRequested()
	signal volumeChosen(real value)
	signal brightnessChosen(int percent)

	// Bloom's displayVolume, and the levels the icons restore (Bloom's
	// previousVolume / previousBrightness: the level before the last change).
	readonly property real _displayVolume: root.muted ? 0 : root.volume
	property real _previousVolume: 0.5
	property int _previousBrightness: 50

	function volumeIcon(v, muted) {
		const shown = muted ? 0 : v;
		return shown === 0 ? "volume-x" : shown < 0.33 ? "volume" : shown < 0.67 ? "volume-1" : "volume-2";
	}

	function brightnessIcon(p) {
		return p < 34 ? "sun-dim" : p < 67 ? "sun-medium" : "sun";
	}

	function _chooseVolume(v) {
		if (root.volume > 0 && !root.muted)
			root._previousVolume = root.volume;
		root.volumeChosen(v);
	}

	function _chooseBrightness(p) {
		if (root.brightness > 0)
			root._previousBrightness = root.brightness;
		root.brightnessChosen(p);
	}

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

		readonly property real step: (width - Tokens.cc.round.size) / 4

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
			objectName: "round-settings"
			x: roundRow.step * 3
			theme: root.theme
			icon: "bloom-settings"
			glyphOpacity: 0.9
			onClicked: root.settingsRequested()
		}

		CcRoundButton {
			objectName: "round-restart"
			x: roundRow.step * 4
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
			icon: root.volumeIcon(root.volume, root.muted)
			value: root._displayVolume
			percentText: Math.round(root._displayVolume * 100) + "%"
			pressedLevel: root._displayVolume === 0
			onChosen: fraction => root._chooseVolume(fraction)
			onToggled: root._chooseVolume(root._displayVolume > 0 ? 0 : root.muted && root.volume > 0 ? root.volume : root._previousVolume)
		}

		CcSlider {
			objectName: "slider-brightness"
			width: parent.width
			theme: root.theme
			light: root.light
			label: "Brightness"
			icon: root.brightnessIcon(root.brightness)
			available: root.brightness >= 0
			value: root.brightness / 100
			percentText: root.brightness >= 0 ? root.brightness + "%" : "—"
			pressedLevel: root.brightness === 0
			onChosen: fraction => root._chooseBrightness(Math.round(fraction * 100))
			onToggled: root._chooseBrightness(root.brightness > 0 ? 0 : root._previousBrightness)
		}
	}
}
