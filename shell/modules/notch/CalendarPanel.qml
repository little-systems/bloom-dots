import QtQuick
import qs.services
import "../../common"
import "calendar.js" as Calendar

Item {
	id: root
	property date shown: new Date()
	property string tab: "calendar"
	readonly property int rows: Calendar.monthRows(shown.getFullYear(), shown.getMonth())
	function moveMonth(amount) { shown = new Date(shown.getFullYear(), shown.getMonth() + amount, 1); }

	Row {
		id: tabs; spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
		Repeater {
			model: ["calendar", "pomodoro", "todo"]
			delegate: Rectangle {
				required property string modelData
				width: 76; height: 24; radius: 8
				color: root.tab === modelData ? Qt.rgba(1, 1, 1, 0.17) : "transparent"
				Text { anchors.centerIn: parent; text: modelData.charAt(0).toUpperCase() + modelData.slice(1); color: Theme.text; font.family: "Inter"; font.pixelSize: 10 }
				MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = modelData }
			}
		}
	}
	Item {
		visible: root.tab === "calendar"; y: 31; width: parent.width; height: parent.height - y
		Row {
			id: monthHeader; width: parent.width; height: 28
			Text { width: parent.width - 64; text: Qt.formatDate(root.shown, "MMMM yyyy"); color: Theme.text; font.family: "Inter"; font.pixelSize: 13; font.weight: Font.DemiBold }
			Text { width: 32; text: "‹"; color: Theme.text; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; MouseArea { anchors.fill: parent; onClicked: root.moveMonth(-1) } }
			Text { width: 32; text: "›"; color: Theme.text; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; MouseArea { anchors.fill: parent; onClicked: root.moveMonth(1) } }
		}
		Grid {
			y: 30; width: parent.width; columns: 7; rowSpacing: 2
			Repeater {
				model: ["S", "M", "T", "W", "T", "F", "S"]
				delegate: Text { required property string modelData; width: 64; height: 20; text: modelData; horizontalAlignment: Text.AlignHCenter; color: Theme.textMuted; font.pixelSize: 10 }
			}
			Repeater {
				model: Calendar.monthGrid(root.shown.getFullYear(), root.shown.getMonth())
				delegate: Rectangle {
					required property var modelData
					width: 64; height: 25; radius: 8
					readonly property bool today: modelData.inMonth && new Date().getDate() === modelData.day && new Date().getMonth() === root.shown.getMonth() && new Date().getFullYear() === root.shown.getFullYear()
					color: today ? Qt.rgba(1, 1, 1, 0.2) : "transparent"
					Text { anchors.centerIn: parent; text: modelData.inMonth ? modelData.day : ""; color: Theme.text; font.family: "Inter"; font.pixelSize: 11; font.weight: today ? Font.Bold : Font.Normal }
				}
			}
		}
	}
	Item {
		visible: root.tab === "pomodoro"; y: 36; width: parent.width; height: parent.height - y
		property real tick: Date.now()
		Timer { interval: 1000; repeat: true; running: parent.visible && CalendarState.running; onTriggered: parent.tick = Date.now() }
		Text { id: countdown; anchors.horizontalCenter: parent.horizontalCenter; y: 27; text: Calendar.timerText(Calendar.remaining(CalendarState.deadlineMs, CalendarState.pausedSec, parent.tick)); color: Theme.text; font.family: "Inter"; font.pixelSize: 35; font.weight: Font.DemiBold }
		Row {
			y: 90; anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
			TextInput { id: digits; width: 75; height: 28; color: Theme.text; font.pixelSize: 13; horizontalAlignment: TextInput.AlignHCenter; verticalAlignment: TextInput.AlignVCenter; maximumLength: 6; inputMethodHints: Qt.ImhDigitsOnly; text: "2500"; onAccepted: { const sec = Calendar.timerDigits(text); if (sec !== null) CalendarState.setDuration(sec); } }
			Rectangle { width: 72; height: 28; radius: 8; color: Theme.groupBg
				Text { anchors.centerIn: parent; text: CalendarState.running ? "Pause" : "Start"; color: Theme.text; font.pixelSize: 11 }
				MouseArea { anchors.fill: parent; onClicked: CalendarState.running ? CalendarState.pause() : CalendarState.start() }
			}
			Rectangle { width: 72; height: 28; radius: 8; color: Theme.groupBg
				Text { anchors.centerIn: parent; text: "Reset"; color: Theme.text; font.pixelSize: 11 }
				MouseArea { anchors.fill: parent; onClicked: CalendarState.reset() }
			}
		}
		Text { y: 135; anchors.horizontalCenter: parent.horizontalCenter; text: "Enter mmss to set a timer"; color: Theme.textMuted; font.pixelSize: 10 }
	}
	Item {
		visible: root.tab === "todo"; y: 34; width: parent.width; height: parent.height - y
		Rectangle { id: inputBg; width: parent.width; height: 30; radius: 8; color: Theme.groupBg
			TextInput { id: todoInput; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font.pixelSize: 11; onAccepted: { if (CalendarState.addTodo(text) === "ok") text = ""; } }
			Text { anchors.verticalCenter: parent.verticalCenter; x: 10; visible: !todoInput.text && !todoInput.activeFocus; text: "Add a task and press Enter"; color: Theme.textMuted; font.pixelSize: 11 }
		}
		Flickable { y: 38; width: parent.width; height: parent.height - y; contentHeight: todoList.implicitHeight; clip: true
			Column { id: todoList; width: parent.width; spacing: 4
				Repeater { model: CalendarState.todos
					delegate: Row { required property var modelData; width: todoList.width; height: 26; spacing: 6
						Text { width: 18; text: modelData.done ? "☑" : "□"; color: Theme.text; font.pixelSize: 15; MouseArea { anchors.fill: parent; onClicked: CalendarState.toggleTodo(modelData.id) } }
						Text { width: parent.width - 54; text: modelData.text; elide: Text.ElideRight; color: modelData.done ? Theme.textMuted : Theme.text; font.pixelSize: 11; font.strikeout: modelData.done }
						Text { text: "×"; color: Theme.textMuted; font.pixelSize: 16; MouseArea { anchors.fill: parent; onClicked: CalendarState.removeTodo(modelData.id) } }
					}
				}
			}
		}
	}
}
