import QtQuick
import qs.services
import "../../common"
import "calendar.js" as Calendar

// The original Bloom calendar and timer share a split surface.
Item {
	id: root
	readonly property date shown: new Date()
	readonly property var dates: Calendar.monthGrid((new Date()).getFullYear(), (new Date()).getMonth())
	readonly property int rows: dates.length / 7
	property bool editing: false
	property real tick: Date.now()
	readonly property int remaining: Calendar.remaining(CalendarState.deadlineMs, CalendarState.pausedSec, tick)
	readonly property bool finished: !CalendarState.running && CalendarState.pausedSec === 0
	Timer { interval: 1000; repeat: true; running: root.visible && CalendarState.running; onTriggered: root.tick = Date.now() }

	Item {
		id: calendarColumn
		x: 16; y: 16; width: Math.max(0, Math.round((root.width - 48) * 0.54)); height: Math.max(0, root.height - 32)
		Text { id: month; text: Qt.formatDate(root.shown, "MMMM yyyy"); color: Theme.text; opacity: 0.9; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold }
		Grid {
			y: month.height + 8; width: parent.width; columns: 7; rowSpacing: 2; columnSpacing: 2
			Repeater {
				model: ["S", "M", "T", "W", "T", "F", "S"]
				delegate: Text { required property string modelData; width: Math.max(0, (calendarColumn.width - 12) / 7); height: 14; text: modelData; horizontalAlignment: Text.AlignHCenter; color: Theme.textMuted; opacity: 0.65; font.family: "Inter"; font.pixelSize: 9; font.weight: Font.DemiBold }
			}
			Repeater {
				id: datesRepeater
				model: root.dates.length
				delegate: Rectangle {
					required property int index
					readonly property var dayInfo: root.dates[index]
					width: Math.max(0, (calendarColumn.width - 12) / 7); height: width; radius: 4
					readonly property bool today: dayInfo.inMonth && new Date().getDate() === dayInfo.day
						&& new Date().getMonth() === root.shown.getMonth() && new Date().getFullYear() === root.shown.getFullYear()
					color: today ? Theme.text : "transparent"
					Text { anchors.centerIn: parent; text: dayInfo.inMonth ? dayInfo.day : ""; color: today ? Theme.bgExpanded : Theme.text; font.family: "Inter"; font.pixelSize: 10; font.weight: today ? Font.DemiBold : Font.Normal }
				}
			}
		}
	}
	Rectangle { x: calendarColumn.x + calendarColumn.width + 16; y: 16; width: 1; height: root.height - 32; color: Theme.border }
	Item {
		id: side
		x: calendarColumn.x + calendarColumn.width + 33; y: 16; width: Math.max(0, root.width - x - 16); height: Math.max(0, root.height - 32)
		Text {
			text: root.editing ? "Set duration" : root.finished ? "Time's up"
				: CalendarState.running ? "ends " + Qt.formatTime(new Date(CalendarState.deadlineMs), "h:mm AP")
				: CalendarState.pausedSec !== CalendarState.durationSec ? "Paused" : "Click to edit"
			color: Theme.textMuted; font.family: "Inter"; font.pixelSize: 10
		}
		Item {
			anchors.fill: parent
			Text {
				id: countdown; y: 28; anchors.horizontalCenter: parent.horizontalCenter
				text: Calendar.timerText(root.remaining); color: root.finished ? "#ff453a" : Theme.text
				font.family: "Inter"; font.pixelSize: 36; font.weight: Font.DemiBold
				MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: { root.editing = true; digits.text = String(Math.floor(root.remaining / 60)) + String(root.remaining % 60).padStart(2, "0"); digits.forceActiveFocus(); digits.selectAll(); } }
			}
			TextInput {
				id: digits; x: countdown.x; y: countdown.y; width: countdown.width; height: countdown.height
				visible: root.editing; color: Theme.text; font.family: "Inter"; font.pixelSize: 36; font.weight: Font.DemiBold
				horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter
				maximumLength: 6; inputMethodHints: Qt.ImhDigitsOnly
				onAccepted: commit()
				onActiveFocusChanged: if (!activeFocus && root.editing) commit()
				function commit() { const sec = Calendar.timerDigits(text); if (sec !== null) CalendarState.setDuration(sec); root.editing = false; }
			}
			Rectangle { x: countdown.x + 15; y: 76; width: countdown.width - 30; height: 2; radius: 1; color: Theme.text; opacity: root.editing ? 0.3 : 0 }
			Row {
				y: 102; width: parent.width; spacing: 8
				Item { width: 24; height: 44 }
				Rectangle {
					width: side.width - 64; height: 44; radius: 22; color: Theme.text
					Row { anchors.centerIn: parent; spacing: 7
						SvgIcon { anchors.verticalCenter: parent.verticalCenter; name: CalendarState.running ? "sf-pause.fill" : "sf-play.fill"; color: Theme.bgExpanded; size: 14 }
						Text { text: CalendarState.running ? "Pause" : root.finished ? "Restart" : "Start"; color: Theme.bgExpanded; font.family: "Inter"; font.pixelSize: 12; font.weight: Font.DemiBold }
					}
					MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: CalendarState.running ? CalendarState.pause() : CalendarState.start() }
				}
				PressArea { width: 32; height: 44; onClicked: CalendarState.reset(); SvgIcon { anchors.centerIn: parent; name: "rotate-ccw"; color: Theme.textMuted; size: 14 } }
			}
			Row {
				y: 162; width: parent.width; spacing: 4
				Repeater { model: [5, 15, 25, 50]
					delegate: Rectangle { required property int modelData; width: (side.width - 12) / 4; height: 24; radius: 7; color: CalendarState.durationSec === modelData * 60 ? Theme.text : Theme.groupBg
						Text { anchors.centerIn: parent; text: modelData + "m"; color: CalendarState.durationSec === modelData * 60 ? Theme.bgExpanded : Theme.textMuted; font.family: "Inter"; font.pixelSize: 10; font.weight: Font.DemiBold }
						MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { CalendarState.setDuration(modelData * 60); CalendarState.start(); } }
					}
				}
			}
		}
	}
}
