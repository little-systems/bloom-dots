import QtQuick
import qs.services
import "calendar.js" as Calendar

// The Calendar panel: binds CalendarView to CalendarState. `rows` sizes the
// panel (PanelHost).
CalendarView {
	id: root

	theme: Theme
	use24h: Settings.values["bloom-time-format-24h"] === true
	durationSec: CalendarState.durationSec
	running: CalendarState.running
	finished: CalendarState.finished
	remainingSec: Calendar.remaining(CalendarState.deadlineMs, CalendarState.pausedSec, root.now.getTime())
	viewYear: CalendarState.viewYear
	viewMonth: CalendarState.viewMonth
	mondayFirst: Settings.values["bloom-calendar-monday-first"] === true
	onMonthChosen: (year, month) => {
		CalendarState.viewYear = year;
		CalendarState.viewMonth = month;
	}

	// Bloom refreshes "today" every minute.
	Timer {
		interval: 60000
		repeat: true
		running: root.visible
		onTriggered: root.now = new Date()
	}

	// Ticks while a run counts down (the clock and its "ends" time).
	Timer {
		interval: 1000
		repeat: true
		running: root.visible && CalendarState.running
		triggeredOnStart: true
		onTriggered: root.now = new Date()
	}

	onPrimaryRequested: CalendarState.running ? CalendarState.pause() : CalendarState.start()
	onResetRequested: CalendarState.reset()
	onPresetChosen: seconds => CalendarState.startWith(seconds)
	onDurationCommitted: (seconds, start) => CalendarState.commit(seconds, start)
}
