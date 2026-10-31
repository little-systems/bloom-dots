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

	readonly property var _grid: Calendar.monthGrid(root.now.getFullYear(), root.now.getMonth())
	readonly property int rows: root._grid.length / 7

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
		root.editing = false;
		const total = Calendar.timerDigits(root.editDigits);
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
				root.commitEdit(false);
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

	Item {
		objectName: "calendarColumn"
		x: Tokens.calendar.padding
		y: root._top
		width: root._calWidth
		height: root._innerHeight

		// Bloom ignores the wheel over the calendar and the timer: it doesn't
		// switch panels from here.
		MouseArea {
			anchors.fill: parent
			acceptedButtons: Qt.NoButton
			onWheel: wheel => wheel.accepted = true
		}

		Text {
			id: month
			objectName: "month"
			width: parent.width
			height: Tokens.calendar.month.text * 1.3
			lineHeightMode: Text.FixedHeight
			lineHeight: height
			verticalAlignment: Text.AlignVCenter
			text: Qt.locale().standaloneMonthName(root.now.getMonth(), Locale.LongFormat) + " " + root.now.getFullYear()
			color: root.theme.text
			opacity: Tokens.calendar.month.opacity
			font.family: Fonts.familyFor(Font.DemiBold)
			font.pixelSize: Fonts.px(Tokens.calendar.month.text)
			font.weight: Font.DemiBold
		}

		Row {
			id: dayNames
			objectName: "dayNames"
			y: month.height + Tokens.calendar.month.below
			spacing: Tokens.calendar.grid.gap

			Repeater {
				model: ["S", "M", "T", "W", "T", "F", "S"]

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
					readonly property bool today: info.inMonth && info.day === root.now.getDate()
					readonly property string label: info.inMonth ? String(info.day) : ""

					objectName: "day-" + index
					width: root._cell
					height: root._cell
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
