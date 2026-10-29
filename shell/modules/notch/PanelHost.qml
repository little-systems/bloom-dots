import QtQuick
import qs.services
import "../../common"
import "panels.js" as Panels
import "calendar.js" as Calendar

// Content inside the fixed-size notch surface. The outer NotchView owns the
// spring geometry, input mask and panel memory; this host is created on open.
Item {
	id: root
	property string panel: ""
	property var enabledPanels: ({ calendar: true, "command-center": true, devices: true })
	property color textColor: "white"
	property color textMuted: Qt.rgba(1, 1, 1, 0.6)
	property bool use24h: false
	signal closeRequested()
	signal nextRequested()
	signal previousRequested()
	signal subpanelRequested(string name)
	readonly property int calendarRowCount: root.panel === "calendar" ? (content.item?.rows ?? 5) : 5
	// The open panel is being typed into (it says so with `pinned`).
	readonly property bool pinned: content.item?.pinned ?? false
	readonly property real devicesHeight: content.item?.panelHeight ?? 150
	readonly property bool subpanel: panel === "wifi" || panel === "bluetooth"
	readonly property bool toolPanel: Panels.ORDER.indexOf(panel) >= 0
	property date now: new Date()
	Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
	readonly property string title: panel === "command-center" ? "Command Center"
		: panel === "wifi" ? "Wi-Fi" : panel === "bluetooth" ? "Bluetooth"
		: panel === "devices" ? "Connected Devices" : panel === "calendar" ? "Calendar" : "Shelf"

	Item {
		id: header
		anchors.horizontalCenter: parent.horizontalCenter
		y: 6
		width: 96
		height: 24
		WheelHandler { onWheel: event => event.angleDelta.y < 0 ? root.nextRequested() : root.previousRequested() }

		PressArea {
			x: -22; y: 3; width: 18; height: 18
			hoverScale: 1.1
			visible: root.toolPanel && Panels.available(root.enabledPanels).length > 1
			onClicked: root.previousRequested()
			SvgIcon { anchors.centerIn: parent; name: "chevron-left"; color: root.textMuted; size: 12 }
		}
		Text {
			anchors.centerIn: parent
			text: CalendarState.running || CalendarState.pausedSec > 0
				? Calendar.timerText(Calendar.remaining(CalendarState.deadlineMs, CalendarState.pausedSec, root.now.getTime()))
				: Qt.formatTime(root.now, root.use24h ? "HH:mm" : "h:mm AP")
			color: root.textColor
			font.family: "Inter"
			font.pixelSize: 13
			font.weight: Font.Medium
			MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.subpanelRequested("calendar") }
		}
		PressArea {
			x: parent.width + 4; y: 3; width: 18; height: 18
			hoverScale: 1.1
			visible: root.toolPanel && Panels.available(root.enabledPanels).length > 1
			onClicked: root.nextRequested()
			SvgIcon { anchors.centerIn: parent; name: "chevron-right"; color: root.textMuted; size: 12 }
		}
	}

	Loader {
		id: content
		x: root.panel === "calendar" || root.subpanel ? 0 : root.panel === "command-center" || root.panel === "shelf" ? 14 : 12
		y: 36
		width: parent.width - 2 * x
		height: parent.height - 36
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
