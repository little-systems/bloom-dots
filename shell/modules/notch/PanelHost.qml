import QtQuick
import qs.services
import "../../common"
import "panels.js" as Panels
import "calendar.js" as Calendar
import "../../common/render"

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
	readonly property real listScroll: content.item?.scrollY ?? 0
	readonly property bool subpanel: panel === "wifi" || panel === "bluetooth"
	readonly property bool toolPanel: Panels.ORDER.indexOf(panel) >= 0
	property date now: new Date()
	Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
	readonly property string title: panel === "command-center" ? "Command Center"
		: panel === "wifi" ? "Wi-Fi" : panel === "bluetooth" ? "Bluetooth"
		: panel === "devices" ? "Connected Devices" : panel === "calendar" ? "Calendar" : "Shelf"

	// Bloom's time-center: the notch clock (or timer), with the panel arrows
	// while a tool panel is open.
	NotchClock {
		id: header
		visible: root.panel !== ""
		anchors.horizontalCenter: parent.horizontalCenter
		y: 6
		now: root.now
		use24h: root.use24h
		timerActive: CalendarState.running || CalendarState.pausedSec > 0 || CalendarState.finished
		timerSeconds: Calendar.remaining(CalendarState.deadlineMs, CalendarState.pausedSec, root.now.getTime())
		timerFinished: CalendarState.finished
		textColor: root.textColor
		textMuted: root.textMuted
		arrows: root.toolPanel && Panels.available(root.enabledPanels).length > 1
		onPrevious: root.previousRequested()
		onNext: root.nextRequested()
		// toggleCalendarMode with the notch open: reset a finished timer, else
		// go to the calendar.
		onClicked: CalendarState.finished ? CalendarState.reset() : root.subpanelRequested("calendar")

	}

	// The panel content, crossfading as Bloom's AnimatePresence does.
	PanelStage {
		id: content
		y: 36
		width: parent.width
		height: parent.height - 36
	}
	function _source(panel) {
		return panel === "command-center" ? "CommandCenter.qml"
			: panel === "wifi" ? "WifiPanel.qml"
			: panel === "bluetooth" ? "BluetoothPanel.qml"
			: panel === "calendar" ? "CalendarPanel.qml"
			: panel === "devices" ? "ConnectedDevicesPanel.qml"
			: panel === "shelf" ? "ShelfPanel.qml" : "";
	}
	function _showPanel() {
		const source = root._source(root.panel);
		content.show(source ? Qt.resolvedUrl(source) : "", Panels.inset(root.panel));
	}
	onPanelChanged: root._showPanel()
	Component.onCompleted: root._showPanel()
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
		font.family: Fonts.family
		font.pixelSize: Fonts.px(11)
	}
}
