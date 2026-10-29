import QtQuick
import "../../common"
import "panels.js" as Panels

// Content inside the fixed-size notch surface. The outer NotchView owns the
// spring geometry, input mask and panel memory; this host is created on open.
Item {
	id: root
	property string panel: ""
	property var enabledPanels: ({ calendar: true, "command-center": true, devices: true })
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	signal closeRequested()
	signal nextRequested()
	signal previousRequested()
	signal subpanelRequested(string name)
	readonly property int calendarRowCount: root.panel === "calendar" ? (content.item?.rows ?? 5) : 5
	readonly property bool subpanel: panel === "wifi" || panel === "bluetooth"
	readonly property bool toolPanel: Panels.ORDER.indexOf(panel) >= 0
	readonly property string title: panel === "command-center" ? "Command Center"
		: panel === "wifi" ? "Wi-Fi" : panel === "bluetooth" ? "Bluetooth"
		: panel === "devices" ? "Connected Devices" : panel === "calendar" ? "Calendar" : "Shelf"

	Item {
		id: header
		x: 12
		y: 4
		width: parent.width - 24
		height: 30
		WheelHandler { onWheel: event => event.angleDelta.y < 0 ? root.nextRequested() : root.previousRequested() }

		PressArea {
			x: 0; y: 4; width: 22; height: 22
			hoverScale: 1.1
			visible: root.subpanel || root.toolPanel
			onClicked: root.subpanel ? root.subpanelRequested("command-center") : root.previousRequested()
			SvgIcon { anchors.centerIn: parent; name: "chevron-left"; color: root.textColor; size: 15 }
		}
		Text {
			anchors.centerIn: parent
			text: root.title
			color: root.textColor
			font.family: "Inter"
			font.pixelSize: 12
			font.weight: Font.DemiBold
		}
		PressArea {
			anchors.right: parent.right
			anchors.rightMargin: 27
			y: 4; width: 22; height: 22
			hoverScale: 1.1
			visible: root.toolPanel
			onClicked: root.nextRequested()
			SvgIcon { anchors.centerIn: parent; name: "chevron-right"; color: root.textColor; size: 15 }
		}
		PressArea {
			anchors.right: parent.right
			y: 4; width: 22; height: 22
			hoverScale: 1.1
			onClicked: root.closeRequested()
			SvgIcon { anchors.centerIn: parent; name: "x"; color: root.textMuted; size: 15 }
		}
	}

	Loader {
		id: content
		x: 12
		y: 36
		width: parent.width - 24
		height: parent.height - 44
		source: root.panel === "command-center" ? "CommandCenter.qml"
			: root.panel === "wifi" ? "WifiPanel.qml"
			: root.panel === "bluetooth" ? "BluetoothPanel.qml"
			: root.panel === "calendar" ? "CalendarPanel.qml"
			: root.panel === "devices" ? "ConnectedDevicesPanel.qml"
			: root.panel === "shelf" ? "ShelfPanel.qml" : ""
	}
	Connections {
		target: content.item
		ignoreUnknownSignals: true
		function onSubpanelRequested(name) { root.subpanelRequested(name); }
	}
	Text {
		anchors.centerIn: content
		visible: content.status === Loader.Error
		text: root.title + " is unavailable"
		color: root.textMuted
		font.family: "Inter"
		font.pixelSize: 11
	}
}
