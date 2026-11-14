import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "calendar.js" as Calendar
import "qp"
import "../../common/render"

// Bloom's calendar and timer split view (App.tsx .calendar-timer-content):
// the month on the left, the Pomodoro timer on the right. Pure: the timer's
// state comes in as properties and its actions go out as signals;
// CalendarPanel.qml binds CalendarState.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property date now: new Date()
	property bool use24h: false
	// Bloom's lastDurationSeconds: shown while idle and started by Play.
	property int durationSec: 1500
	// Time left: counting down while running, held while paused, 0 when idle.
	property int remainingSec: 0
	property bool running: false
	property bool finished: false

	// Play while not editing: the owner pauses, resumes or starts.
	signal primaryRequested()
	signal resetRequested()
	signal presetChosen(int seconds)
	signal durationCommitted(int seconds, bool start)

	property bool editing: false
	property string editDigits: ""
	// The edit opens with the duration selected: the first digit replaces it.
	property bool _fresh: false

	// The month shown (Bloom's calendarMonth) and the week start. The owner
	// keeps the month; monthChosen asks for another.
	property int viewYear: root.now.getFullYear()
	property int viewMonth: root.now.getMonth()
	property bool mondayFirst: false
	signal monthChosen(int year, int month)

	readonly property var _grid: Calendar.monthGrid(root.viewYear, root.viewMonth, root.mondayFirst)
	readonly property int rows: root._grid.length / 7
	readonly property bool _isCurrentMonth: root.viewYear === root.now.getFullYear() && root.viewMonth === root.now.getMonth()
	property bool pickingMonth: false
	property bool _monthListOpen: false

	function changeMonth(by) {
		const next = Calendar.shiftMonth(root.viewYear, root.viewMonth, by);
		if (next)
			root.monthChosen(next.year, next.month);
	}

	function goToday() {
		root.monthChosen(root.now.getFullYear(), root.now.getMonth());
	}

	function openMonthPicker() {
		yearField.text = String(root.viewYear);
		root._monthListOpen = false;
		root.pickingMonth = true;
		yearField.forceActiveFocus();
		yearField.selectAll();
	}

	function closeMonthPicker() {
		root.pickingMonth = false;
		yearField.focus = false;
		root._monthListOpen = false;
	}

	// Bloom's year field: 100 to 9999, otherwise it shows the year again.
	function commitYear(text) {
		if (!root.pickingMonth)
			return;
		const value = Number(text);
		if (Number.isInteger(value) && value >= 100 && value <= 9999) {
			if (value !== root.viewYear)
				root.monthChosen(value, root.viewMonth);
		} else {
			yearField.text = String(root.viewYear);
		}
	}

	readonly property string _state: root.editing ? "idle"
		: root.finished ? "finished"
		: root.running ? "running"
		: root.remainingSec > 0 ? "paused" : "idle"
	readonly property bool _editValid: Calendar.timerDigits(root.editDigits) !== null
	readonly property int _display: root.remainingSec > 0 || root.finished ? root.remainingSec : root.durationSec
	readonly property var _clock: Calendar.clockDigits(root.editing ? Calendar.formatDigits(root.editDigits) : Calendar.clockText(root._display))
	readonly property color _red: Tokens.timer.red
	// .timer-section-new: the section's colour by state, 0.3 s ease.
	property color _sectionColor: root._state === "finished" ? root._red : root._state === "paused" ? root.theme.textMuted : root.theme.text
	readonly property color _digitColor: root._state === "finished" || (root.editing && !root._editValid) ? root._red : root.theme.text

	Behavior on _sectionColor {
		ColorAnimation {
			duration: 300
			easing.type: Easing.BezierSpline
			easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
		}
	}

	function beginEdit() {
		if (root.running || root.editing)
			return;
		const wasFinished = root.finished;
		if (wasFinished)
			root.resetRequested();
		const base = !wasFinished && root.remainingSec > 0 ? root.remainingSec : root.durationSec;
		root.editDigits = Calendar.secondsToDigits(base);
		root._fresh = true;
		root.editing = true;
		editor.forceActiveFocus();
	}

	// Bloom's commitTimerEdit: Enter or Play starts it; leaving keeps it idle.
	function commitEdit(start) {
		if (!root.editing)
			return;
		const total = Calendar.timerDigits(root.editDigits);
		// Starting needs a valid duration: the editor stays open (8a8d6a9).
		if (total === null && start) {
			editor.forceActiveFocus();
			return;
		}
		root.editing = false;
		if (total === null)
			return;
		const base = root.remainingSec > 0 ? root.remainingSec : root.durationSec;
		// A tap that changes nothing (a paused timer) must not reset the state.
		if (!start && total === base)
			return;
		root.durationCommitted(total, start);
	}

	function cancelEdit() {
		root.editing = false;
	}

	// The edit's key handling: digits fill from the right, five at most.
	Item {
		id: editor

		Keys.onPressed: event => {
			if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
				const d = String(event.key - Qt.Key_0);
				root.editDigits = root._fresh ? d : (root.editDigits + d).slice(0, 5);
				root._fresh = false;
			} else if (event.key === Qt.Key_Backspace) {
				root.editDigits = root._fresh ? "" : root.editDigits.slice(0, -1);
				root._fresh = false;
			} else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
				root.commitEdit(true);
			} else if (event.key === Qt.Key_Escape) {
				root.cancelEdit();
			}
			event.accepted = true;
		}
		onActiveFocusChanged: if (!activeFocus) root.commitEdit(false)
	}

	// .calendar-timer-content.split-view: padding 16 and a 1 px top margin.
	readonly property real _top: Tokens.calendar.padding + Tokens.calendar.topMargin
	readonly property real _innerHeight: root.height - Tokens.calendar.topMargin - Tokens.calendar.padding * 2
	// Flex 1.2 : 1 from a 0 basis: the timer column's border and padding come
	// off before the split.
	readonly property real _timerChrome: 1 + Tokens.calendar.padding
	readonly property real _free: root.width - Tokens.calendar.padding * 2 - Tokens.calendar.gap - root._timerChrome
	readonly property real _calWidth: root._free * Tokens.calendar.columns[0] / (Tokens.calendar.columns[0] + Tokens.calendar.columns[1])
	readonly property real _timerWidth: root._free - root._calWidth
	readonly property real _cell: (root._calWidth - Tokens.calendar.grid.gap * 6) / 7

	// The calendar column (Bloom's Calendar component): a month you can browse
	// with the arrows, the wheel (Shift: a year), Page Up / Page Down and Home,
	// or by picking a month and typing a year.
	FocusScope {
		id: calendarColumn
		objectName: "calendarColumn"
		x: Tokens.calendar.padding
		y: root._top
		width: root._calWidth
		height: root._innerHeight

		readonly property bool _shown: columnHover.hovered || calendarColumn.activeFocus
		property real _lastWheel: 0

		HoverHandler { id: columnHover }

		Keys.onPressed: event => {
			// Bloom ignores the keys while you type in the picker.
			if (root.pickingMonth)
				return;
			if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
				root.changeMonth((event.key === Qt.Key_PageUp ? -1 : 1) * (event.modifiers & Qt.ShiftModifier ? 12 : 1));
				event.accepted = true;
			} else if (event.key === Qt.Key_Home) {
				root.goToday();
				event.accepted = true;
			}
		}

		// Bloom changes month on the wheel and never switches panels from here:
		// |delta| under 5 is ignored, and one change per 300 ms.
		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.LeftButton
			onPressed: mouse => {
				// Leaving the header closes the picker and keeps the typed year.
				if (root.pickingMonth) {
					root.commitYear(yearField.text);
					root.closeMonthPicker();
				}
				calendarColumn.forceActiveFocus();
				mouse.accepted = false;
			}
			onWheel: wheel => {
				wheel.accepted = true;
				if (root.pickingMonth)
					return;
				const dx = -wheel.angleDelta.x, dy = -wheel.angleDelta.y;
				const delta = Math.abs(dx) > Math.abs(dy) ? dx : dy;
				const now = Date.now();
				if (Math.abs(delta) < 5 || now - calendarColumn._lastWheel < 300)
					return;
				calendarColumn._lastWheel = now;
				root.changeMonth((delta > 0 ? 1 : -1) * (wheel.modifiers & Qt.ShiftModifier ? 12 : 1));
			}
		}

		// .calendar-header: 24 px, 4 px gaps, 8 px above the day names.
		Item {
			id: header
			objectName: "calendarHeader"
			width: parent.width
			height: Tokens.calendar.header.height

			// The month and year: click to pick them.
			Rectangle {
				id: headingButton
				visible: !root.pickingMonth
				// .calendar-heading: flex 1, up to "Today".
				width: todayButton.x - Tokens.calendar.header.gap
				height: parent.height
				radius: Tokens.calendar.header.radius
				color: headingArea.hovered ? Qt.alpha(root.theme.text, 0.12) : "transparent"

				Text {
					id: month
					objectName: "month"
					height: parent.height
					verticalAlignment: Text.AlignVCenter
					text: Qt.locale().standaloneMonthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
					color: root.theme.text
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: Fonts.px(Tokens.calendar.header.heading)
					font.weight: Font.DemiBold
				}

				PointerArea {
					id: headingArea
					anchors.fill: parent
					onClicked: root.openMonthPicker()
				}
			}

			// .calendar-month-picker: the month list, the year and Done.
			Row {
				id: picker
				objectName: "monthPicker"
				visible: root.pickingMonth
				height: parent.height
				width: todayButton.x - Tokens.calendar.header.gap
				spacing: Tokens.calendar.picker.gap

				Rectangle {
					id: monthSelect
					objectName: "monthSelect"
					width: picker.width - yearField.width - doneButton.width - picker.spacing * 2
					height: parent.height
					radius: Tokens.calendar.header.radius
					color: monthSelectArea.hovered || root._monthListOpen ? Qt.alpha(root.theme.text, 0.12) : "transparent"

					Text {
						x: 1
						height: parent.height
						verticalAlignment: Text.AlignVCenter
						text: Qt.locale().standaloneMonthName(root.viewMonth, Locale.LongFormat)
						color: root.theme.text
						font.family: Fonts.familyFor(Font.DemiBold)
						font.pixelSize: Fonts.px(Tokens.calendar.picker.text)
						font.weight: Font.DemiBold
					}

					PointerArea {
						id: monthSelectArea
						anchors.fill: parent
						onClicked: root._monthListOpen = !root._monthListOpen
					}
				}

				TextInput {
					id: yearField
					objectName: "yearField"
					width: Tokens.calendar.picker.year
					height: parent.height
					verticalAlignment: TextInput.AlignVCenter
					leftPadding: 1
					rightPadding: 1
					maximumLength: 4
					validator: IntValidator { bottom: 0; top: 9999 }
					color: root.theme.text
					selectionColor: Qt.alpha(root.theme.text, 0.3)
					selectedTextColor: root.theme.text
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: Fonts.px(Tokens.calendar.picker.text)
					font.weight: Font.DemiBold
					onEditingFinished: root.commitYear(yearField.text)
					onActiveFocusChanged: if (!activeFocus && root.pickingMonth) {
						root.commitYear(yearField.text);
						root.closeMonthPicker();
					}
					Keys.onReturnPressed: { root.commitYear(yearField.text); root.closeMonthPicker(); }
					Keys.onEnterPressed: { root.commitYear(yearField.text); root.closeMonthPicker(); }
					Keys.onEscapePressed: root.closeMonthPicker()
				}

				Rectangle {
					id: doneButton
					objectName: "pickerDone"
					width: Tokens.calendar.header.minButton
					height: parent.height
					radius: Tokens.calendar.header.radius
					color: doneArea.hovered ? Qt.alpha(root.theme.text, 0.12) : "transparent"

					SvgIcon {
						anchors.centerIn: parent
						name: "check"
						size: Tokens.calendar.header.glyph
						color: root.theme.text
					}

					PointerArea {
						id: doneArea
						anchors.fill: parent
						onClicked: root.closeMonthPicker()
					}
				}
			}

			// "Today": only away from the current month (visibility: hidden,
			// so the row keeps its layout).
			Rectangle {
				id: todayButton
				objectName: "todayButton"
				visible: !root._isCurrentMonth
				// The arrows leave while picking, so "Today" ends the row.
				x: root.pickingMonth ? parent.width - width : monthNav.x - Tokens.calendar.header.gap - width
				width: Tokens.calendar.header.today
				height: parent.height
				radius: Tokens.calendar.header.radius
				color: todayArea.hovered ? Qt.alpha(root.theme.text, 0.12) : "transparent"

				Text {
					objectName: "todayLabel"
					anchors.centerIn: parent
					text: "Today"
					color: root.theme.text
					opacity: Tokens.calendar.header.todayOpacity
					font.family: Fonts.familyFor(Font.Normal)
					font.pixelSize: Fonts.px(Tokens.calendar.header.todayText)
				}

				PointerArea {
					id: todayArea
					anchors.fill: parent
					onClicked: { root.goToday(); root.closeMonthPicker(); }
				}
			}

			// .calendar-navigation: a pill with the arrows, shown on hover or
			// focus.
			Rectangle {
				id: monthNav
				objectName: "monthNav"
				visible: !root.pickingMonth
				x: parent.width - width
				width: Tokens.calendar.nav.width
				height: parent.height
				radius: height / 2
				color: root.theme.groupBg
				border.width: 1
				border.color: root.theme.border
				opacity: calendarColumn._shown ? 1 : 0
				Behavior on opacity {
					NumberAnimation {
						duration: Tokens.calendar.nav.fadeMs
						easing.type: Easing.BezierSpline
						easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
					}
				}

				Row {
					anchors.centerIn: parent

					Repeater {
						model: [{ name: "previousMonth", icon: "chevron-left", by: -1 }, { name: "nextMonth", icon: "chevron-right", by: 1 }]

						Rectangle {
							required property var modelData
							objectName: modelData.name
							width: Tokens.calendar.nav.button
							height: Tokens.calendar.nav.button
							radius: height / 2
							color: arrowArea.hovered ? Qt.alpha(root.theme.text, 0.12) : "transparent"

							SvgIcon {
								anchors.centerIn: parent
								name: parent.modelData.icon
								size: Tokens.calendar.header.glyph
								color: root.theme.text
							}

							PointerArea {
								id: arrowArea
								anchors.fill: parent
								enabled: monthNav.opacity > 0
								onClicked: root.changeMonth(parent.modelData.by)
							}
						}
					}
				}
			}
		}

		Row {
			id: dayNames
			objectName: "dayNames"
			y: header.height + Tokens.calendar.header.below
			spacing: Tokens.calendar.grid.gap

			Repeater {
				model: root.mondayFirst ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"] : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

				Text {
					required property string modelData
					width: root._cell
					height: implicitHeight + Tokens.calendar.dayName.below
					horizontalAlignment: Text.AlignHCenter
					text: modelData
					color: root.theme.text
					opacity: Tokens.calendar.dayName.opacity
					font.family: Fonts.familyFor(Font.DemiBold)
					font.pixelSize: Fonts.px(Tokens.calendar.dayName.text)
					font.weight: Font.DemiBold
				}
			}
		}

		Grid {
			y: dayNames.y + dayNames.height + Tokens.calendar.grid.gap
			columns: 7
			spacing: Tokens.calendar.grid.gap

			Repeater {
				model: root._grid.length

				Rectangle {
					required property int index
					readonly property var info: root._grid[index]
					readonly property bool today: root._isCurrentMonth && info.inMonth && info.day === root.now.getDate()
					readonly property string label: info.inMonth ? String(info.day) : ""

					objectName: "day-" + index
					width: root._cell
					height: Tokens.calendar.day.height
					radius: Tokens.calendar.day.radius
					color: today ? root.theme.text : "transparent"

					Text {
						objectName: "dayText"
						anchors.centerIn: parent
						text: parent.label
						color: parent.today ? root.theme.bgExpanded : root.theme.text
						font.family: Fonts.familyFor(parent.today ? Font.DemiBold : Font.Normal)
						font.pixelSize: Fonts.px(Tokens.calendar.day.text)
						font.weight: parent.today ? Font.DemiBold : Font.Normal
					}
				}
			}
		}

		// The month list (Bloom's <select>), over the grid.
		Rectangle {
			objectName: "monthList"
			visible: root.pickingMonth && root._monthListOpen
			z: 10
			y: header.height + 2
			width: monthSelect.width + yearField.width
			height: monthColumn.height + 4
			radius: Tokens.calendar.header.radius
			color: root.theme.bgExpanded
			border.width: 1
			border.color: root.theme.border

			Column {
				id: monthColumn
				y: 2
				width: parent.width

				Repeater {
					model: 12

					Rectangle {
						required property int index
						objectName: "monthOption-" + index
						width: monthColumn.width
						height: Tokens.calendar.picker.option
						color: optionArea.hovered || index === root.viewMonth ? Qt.alpha(root.theme.text, 0.12) : "transparent"

						Text {
							x: 6
							height: parent.height
							verticalAlignment: Text.AlignVCenter
							text: Qt.locale().standaloneMonthName(parent.index, Locale.LongFormat)
							color: root.theme.text
							font.family: Fonts.familyFor(Font.Normal)
							font.pixelSize: Fonts.px(Tokens.calendar.picker.text)
						}

						PointerArea {
							id: optionArea
							anchors.fill: parent
							onClicked: {
								root.monthChosen(root.viewYear, parent.index);
								root._monthListOpen = false;
							}
						}
					}
				}
			}
		}
	}

	Rectangle {
		objectName: "divider"
		x: Tokens.calendar.padding + root._calWidth + Tokens.calendar.gap
		y: root._top
		width: 1
		height: root._innerHeight
		color: root.theme.border
	}

	Item {
		id: timerColumn
		objectName: "timerColumn"
		x: Tokens.calendar.padding + root._calWidth + Tokens.calendar.gap + root._timerChrome
		y: root._top
		width: root._timerWidth
		height: root._innerHeight

		// Bloom ignores the wheel over the calendar and the timer: it doesn't
		// switch panels from here.
		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.NoButton
			onWheel: wheel => wheel.accepted = true
		}

		Column {
			y: (parent.height - height) / 2
			width: parent.width
			spacing: Tokens.timer.sectionGap

			Column {
				width: parent.width
				spacing: Tokens.timer.mainGap

				Text {
					objectName: "status"
					width: parent.width
					height: Tokens.timer.status.height
					horizontalAlignment: Text.AlignHCenter
					verticalAlignment: Text.AlignVCenter
					text: Calendar.status({ editing: root.editing, finished: root.finished, running: root.running, remaining: root.remainingSec }, root.now, root.use24h)
					color: root._sectionColor
					opacity: root._state === "finished" ? Tokens.timer.status.finishedOpacity : Tokens.timer.status.opacity
					font.family: Fonts.familyFor(Font.Medium)
					font.pixelSize: Fonts.px(Tokens.timer.status.text)
					font.weight: Font.Medium
					font.letterSpacing: Tokens.timer.status.tracking
					font.features: {
						"tnum": 1
					}
				}

				Item {
					id: clockRow
					width: parent.width
					height: clock.height

					Row {
						id: clock
						objectName: "clock"
						anchors.horizontalCenter: parent.horizontalCenter
						spacing: Tokens.timer.digit.gap

						// Minute digits counted from the right, so they keep their
						// place when a third appears.
						RollDigit {
							objectName: "digit-m3"
							visible: root._clock.compact
							compact: root._clock.compact
							value: root._clock.compact ? root._clock.minutes[0] : ""
							color: root._digitColor
						}

						RollDigit {
							objectName: "digit-m2"
							compact: root._clock.compact
							value: root._clock.minutes[root._clock.minutes.length - 2]
							color: root._digitColor
						}

						RollDigit {
							objectName: "digit-m1"
							compact: root._clock.compact
							value: root._clock.minutes[root._clock.minutes.length - 1]
							color: root._digitColor
						}

						Text {
							objectName: "colon"
							anchors.verticalCenter: parent.verticalCenter
							width: Math.ceil(implicitWidth) + Tokens.timer.colon.padH * 2
							height: Tokens.timer.colon.text
							horizontalAlignment: Text.AlignHCenter
							verticalAlignment: Text.AlignVCenter
							text: ":"
							color: root._sectionColor
							opacity: Tokens.timer.colon.opacity
							font.family: Fonts.familyFor(Font.DemiBold)
							font.pixelSize: Fonts.px(Tokens.timer.colon.text)
							font.weight: Font.DemiBold
						}

						RollDigit {
							objectName: "digit-s2"
							compact: root._clock.compact
							value: root._clock.seconds[0]
							color: root._digitColor
						}

						RollDigit {
							objectName: "digit-s1"
							compact: root._clock.compact
							value: root._clock.seconds[1]
							color: root._digitColor
						}

						// .state-finished .timer-clock: a 1.03 pulse every 1.9 s after 0.65 s.
						SequentialAnimation {
							objectName: "pulse"
							running: root._state === "finished" && root.visible
							onRunningChanged: if (!running) clock.scale = 1

							PauseAnimation {
								duration: Tokens.timer.pulse.delay
							}

							SequentialAnimation {
								loops: Animation.Infinite

								NumberAnimation { target: clock; property: "scale"; to: 1.03; duration: Tokens.timer.pulse.ms / 2; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
								NumberAnimation { target: clock; property: "scale"; to: 1; duration: Tokens.timer.pulse.ms / 2; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.42, 0, 0.58, 1, 1, 1] }
							}
						}
					}

					// .timer-clock: cursor text; a click opens the edit.
					MouseArea {
						objectName: "clockPointer"
						x: clock.x
						width: clock.width
						height: clock.height
						cursorShape: Qt.IBeamCursor
						onClicked: root.beginEdit()
					}

					// .timer-edit-underline: grows under the clock while editing.
					Rectangle {
						objectName: "underline"
						anchors.horizontalCenter: parent.horizontalCenter
						y: parent.height + 1 - height
						// width: 74% in Bloom: the fraction eases, a resize doesn't.
						property real fraction: root.editing ? Tokens.timer.underline.width : 0
						width: parent.width * fraction
						height: Tokens.timer.underline.height
						radius: 2
						color: root._sectionColor
						opacity: root.editing ? Tokens.timer.underline.opacity : 0

						Behavior on fraction {
							NumberAnimation {
								duration: Tokens.timer.underline.ms
								easing.type: Easing.BezierSpline
								easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
							}
						}

						Behavior on opacity {
							NumberAnimation {
								duration: Tokens.timer.underline.ms
								easing.type: Easing.BezierSpline
								easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
							}
						}
					}
				}
			}

			Row {
				width: parent.width
				spacing: Tokens.timer.controls.gap

				Item {
					width: Tokens.timer.controls.spacer
					height: Tokens.timer.controls.spacer
					anchors.verticalCenter: parent.verticalCenter
				}

				Item {
					id: play
					objectName: "play"
					width: parent.width - Tokens.timer.controls.spacer * 2 - Tokens.timer.controls.gap * 2
					height: Tokens.timer.play.height
					opacity: playPointer.hovered ? Tokens.timer.play.hoverOpacity : 1
					scale: playPointer.pressed ? Tokens.timer.play.pressScale : 1

					Behavior on opacity {
						NumberAnimation {
							duration: 200
							easing.type: Easing.BezierSpline
							easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
						}
					}

					Behavior on scale {
						NumberAnimation {
							duration: Tokens.timer.play.ms
							easing.type: Easing.BezierSpline
							easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
						}
					}

					Rectangle {
						objectName: "background"
						anchors.fill: parent
						radius: Tokens.timer.play.radius
						color: root.theme.text
					}

					Row {
						anchors.centerIn: parent
						spacing: Tokens.timer.play.gap

						SvgIcon {
							objectName: "glyph"
							anchors.verticalCenter: parent.verticalCenter
							name: root.running ? "pause-filled" : "play-filled"
							size: Tokens.timer.play.glyph
							color: root.theme.bgExpanded
						}

						Text {
							objectName: "label"
							anchors.verticalCenter: parent.verticalCenter
							text: Calendar.primaryLabel(root.running, root.remainingSec, root.finished)
							color: root.theme.bgExpanded
							font.family: Fonts.familyFor(Font.DemiBold)
							font.pixelSize: Fonts.px(Tokens.timer.play.text)
							font.weight: Font.DemiBold
						}
					}

					PointerArea {
						id: playPointer
						anchors.fill: parent
						onClicked: root.editing ? root.commitEdit(true) : root.primaryRequested()
					}
				}

				Item {
					objectName: "reset"
					anchors.verticalCenter: parent.verticalCenter
					width: Tokens.timer.reset.size
					height: Tokens.timer.reset.size
					// Bloom: disabled when there's nothing to reset (idle).
					enabled: root.remainingSec > 0 || root.finished
					opacity: !enabled ? Tokens.timer.reset.disabledOpacity : resetPointer.hovered ? Tokens.timer.reset.hoverOpacity : Tokens.timer.reset.opacity
					scale: resetPointer.pressed ? Tokens.timer.reset.pressScale : 1

					Behavior on opacity {
						NumberAnimation {
							duration: 200
							easing.type: Easing.BezierSpline
							easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
						}
					}

					Behavior on scale {
						NumberAnimation {
							duration: 150
							easing.type: Easing.BezierSpline
							easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
						}
					}

					SvgIcon {
						objectName: "glyph"
						anchors.centerIn: parent
						name: "rotate-ccw"
						size: Tokens.timer.reset.glyph
						strokeWidth: 2.5
						color: root._sectionColor
					}

					PointerArea {
						id: resetPointer
						anchors.fill: parent
						onClicked: root.resetRequested()
					}
				}
			}

			Row {
				width: parent.width
				spacing: Tokens.timer.presets.gap

				Repeater {
					model: [5, 15, 25, 50]

					Item {
						id: preset
						required property int modelData
						required property int index
						readonly property bool active: root.durationSec === modelData * 60 && !root.finished

						objectName: "preset-" + index
						width: (parent.width - Tokens.timer.presets.gap * 3) / 4
						height: Math.ceil(presetLabel.implicitHeight) + Tokens.timer.presets.padV * 2
						opacity: active || presetPointer.hovered ? 1 : Tokens.timer.presets.opacity

						Behavior on opacity {
							NumberAnimation {
								duration: 200
								easing.type: Easing.BezierSpline
								easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
							}
						}

						Rectangle {
							objectName: "background"
							anchors.fill: parent
							radius: Tokens.timer.presets.radius
							color: preset.active ? root.theme.border : "transparent"

							Behavior on color {
								ColorAnimation {
									duration: 200
									easing.type: Easing.BezierSpline
									easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
								}
							}
						}

						Text {
							id: presetLabel
							objectName: "label"
							anchors.centerIn: parent
							text: preset.modelData + "m"
							color: root.theme.text
							font.family: Fonts.familyFor(Font.DemiBold)
							font.pixelSize: Fonts.px(Tokens.timer.presets.text)
							font.weight: Font.DemiBold
						}

						PointerArea {
							id: presetPointer
							anchors.fill: parent
							onClicked: root.presetChosen(preset.modelData * 60)
						}
					}
				}
			}
		}
	}
}
