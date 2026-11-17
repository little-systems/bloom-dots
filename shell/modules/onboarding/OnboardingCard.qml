import QtQuick
import QtQuick.Effects
import "../../common"
import "../../common/render"
import "../../common/i18n"
import "../../common/tokens.js" as Tokens
import "pages.js" as Pages

// The first-run guide's card (Bloom Onboarding.tsx/.css at 63a9bf5, with our
// pages): a fixed 500×400 card; between pages the content fades out in place
// and the new page fades in without moving. OnboardingWindow places, scales
// and moves it. `store` is Settings (values, set(key, value, done(error))).
Item {
	id: root

	property var store: null
	property bool reducedMotion: false
	property bool light: false
	// Adaptive and custom themes keep their colour with an opaque panel.
	property color panelOverride: "transparent"
	// layout.arrow() for the current page's anchor, in card units, or null.
	property var anchorPlacement: null
	property int index: 0
	property bool busy: false
	property string error: ""

	readonly property int cardWidth: 500
	readonly property int cardHeight: 400
	readonly property int count: Pages.PAGES.length
	readonly property var page: Pages.PAGES[Math.max(0, Math.min(root.index, root.count - 1))]
	readonly property string reveal: Pages.reveal(root.page)
	readonly property bool centered: root.page.kind === "welcome" || root.page.kind === "finish"

	readonly property var behaviors: ({ fixed: I18n.t("common.behavior.fixed"), smart: I18n.t("common.behavior.smart"), peek: I18n.t("common.behavior.peek") })

	readonly property var o: Tokens.onboarding
	readonly property var c: root.light ? root.o.light : root.o.dark

	signal closeRequested()

	width: root.cardWidth
	height: root.cardHeight
	focus: true

	function next() { root._navigate(root.index + 1); }
	function back() { root._navigate(root.index - 1); }
	function dismiss() {
		if (!root.busy)
			root.closeRequested();
	}

	property int _target: 0
	function _navigate(target) {
		if (root.busy || target < 0 || target >= root.count)
			return;
		if (root.reducedMotion) {
			root.error = "";
			root.index = target;
			return;
		}
		root._target = target;
		fadeIn.stop();
		fadeOut.restart();
	}

	function _save(key, value) {
		if (root.busy || !root.store)
			return;
		root.busy = true;
		root.error = "";
		root.store.set(key, value, error => {
			root.busy = false;
			if (error)
				root.error = I18n.t("linux.onboarding.couldntSave", { value1: String(error) });
		});
	}

	onIndexChanged: {
		arrow.play();
		if (!root.reducedMotion && !fadeOut.running) {
			pageView.opacity = 0;
			fadeIn.restart();
		}
	}
	Component.onCompleted: arrow.play()

	Keys.onEscapePressed: event => {
		event.accepted = true;
		root.dismiss();
	}

	NumberAnimation {
		id: fadeOut
		target: pageView; property: "opacity"; to: 0; duration: root.o.motion.fadeOutMs
		onFinished: {
			root.error = "";
			root.index = root._target;
		}
	}
	SequentialAnimation {
		id: fadeIn
		PauseAnimation { duration: root.o.motion.fadeInDelayMs }
		NumberAnimation { target: pageView; property: "opacity"; to: 1; duration: root.o.motion.fadeInMs }
	}

	// The panel: 24 px corners, a hairline border and an inset top highlight.
	Rectangle {
		id: panel
		anchors.fill: parent
		radius: root.o.radius
		color: root.panelOverride.a > 0 ? Qt.rgba(root.panelOverride.r, root.panelOverride.g, root.panelOverride.b, 1) : root.c.panel
		border.width: 1
		border.color: root.c.border

		Rectangle {
			x: root.o.radius
			y: 1
			width: parent.width - root.o.radius * 2
			height: 1
			color: root.o.highlight
		}
	}

	// The mascot watermark, clipped to the card's corners.
	Item {
		id: watermarkClip
		anchors.fill: parent
		layer.enabled: true
		layer.effect: MultiEffect {
			maskEnabled: true
			maskSource: watermarkMask
		}
		Image {
			x: root.o.watermark.left
			y: root.height - root.o.watermark.bottom - root.o.watermark.size
			width: root.o.watermark.size
			height: root.o.watermark.size
			sourceSize: Qt.size(root.o.watermark.size, root.o.watermark.size)
			source: Qt.resolvedUrl("../../assets/bloom.png")
			opacity: root.o.watermark.opacity
			layer.enabled: root.light
			layer.effect: MultiEffect { brightness: -1 }
		}
	}
	Rectangle {
		id: watermarkMask
		anchors.fill: parent
		radius: root.o.radius
		visible: false
		layer.enabled: true
	}

	component RoundButton: Item {
		id: button
		property string icon
		property real iconSize: 16
		signal clicked()
		width: root.o.header.button
		height: root.o.header.button
		opacity: root.busy ? root.o.disabledOpacity : 1
		Rectangle {
			anchors.fill: parent
			radius: width / 2
			color: area.containsMouse && !root.busy ? root.c.hover : "transparent"
		}
		SvgIcon {
			anchors.centerIn: parent
			name: button.icon
			size: button.iconSize
			color: area.containsMouse && !root.busy ? root.c.text : root.c.muted
		}
		MouseArea {
			id: area
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: if (!root.busy) button.clicked()
		}
	}

	// Header: "bloom" and the close button.
	Item {
		id: header
		width: parent.width
		height: root.o.header.padY * 2 + root.o.header.button
		Text {
			x: root.o.header.padX
			anchors.verticalCenter: parent.verticalCenter
			text: "bloom"
			color: root.c.text
			font.family: Fonts.uiFor(Font.DemiBold)
			font.weight: Font.DemiBold
			font.pixelSize: root.o.header.title
			font.letterSpacing: root.o.header.tracking
		}
		RoundButton {
			objectName: "close"
			anchors.right: parent.right
			anchors.rightMargin: root.o.header.padX
			anchors.verticalCenter: parent.verticalCenter
			icon: "x"
			iconSize: root.o.header.closeIcon
			Accessible.name: I18n.t("ui.onboarding.closeSetup")
			onClicked: root.dismiss()
		}
	}

	// The page: content and footer fade together.
	Item {
		id: pageView
		y: header.height
		width: parent.width
		height: parent.height - header.height

		Item {
			id: content
			width: parent.width
			height: parent.height - footer.height

			Column {
				id: column
				readonly property real side: root.centered ? root.o.welcome.side : root.o.content.side
				x: column.side
				width: parent.width - column.side * 2
				y: root.centered ? Math.max(0, (content.height - root.o.welcome.bottom - column.height) / 2) : root.o.content.top

				Text {
					objectName: "title"
					width: parent.width
					text: I18n.t(root.page.title)
					color: root.c.text
					wrapMode: Text.WordWrap
					horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
					font.family: Fonts.uiFor(Font.DemiBold)
					font.weight: Font.DemiBold
					font.pixelSize: root.centered ? root.o.welcome.title : root.o.content.title
					font.letterSpacing: root.centered ? root.o.welcome.titleTracking : root.o.content.titleTracking
					lineHeightMode: Text.FixedHeight
					lineHeight: Math.round(font.pixelSize * root.o.content.titleLine)
				}
				Item { width: 1; height: root.o.content.titleGap }
				Text {
					objectName: "description"
					width: parent.width
					text: I18n.t(root.page.description)
					color: root.c.muted
					wrapMode: Text.WordWrap
					horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
					font.family: Fonts.ui
					font.pixelSize: root.o.content.text
					lineHeightMode: Text.FixedHeight
					lineHeight: root.o.content.text * root.o.content.textLine
				}
				Column {
					visible: root.page.hints.length > 0
					topPadding: root.centered ? root.o.welcome.hintTop : root.o.content.hintTop
					width: parent.width
					spacing: root.o.content.hintGap
					Repeater {
						model: root.page.hints
						Text {
							required property string modelData
							required property int index
							objectName: "hint:" + index
							width: parent.width
							text: I18n.t(modelData)
							color: root.c.muted
							wrapMode: Text.WordWrap
							horizontalAlignment: root.centered ? Text.AlignHCenter : Text.AlignLeft
							font.family: Fonts.ui
							readonly property real size: root.centered ? root.o.welcome.hint : root.o.content.hint
							font.pixelSize: size
							lineHeightMode: Text.FixedHeight
							lineHeight: size * root.o.content.hintLine
						}
					}
				}
				Loader {
					width: parent.width
					active: root.page.kind === "island-mode" || root.page.kind === "dock-mode"
					visible: active
					sourceComponent: ModeChoice {
						topPadding: root.o.modes.top
						surface: root.page.kind === "island-mode" ? "island" : "dock"
					}
				}
				Loader {
					width: parent.width
					active: root.page.kind === "preferences"
					visible: active
					sourceComponent: preferences
				}
				Text {
					objectName: "error"
					visible: root.error !== ""
					topPadding: root.o.error.top
					width: parent.width
					text: root.error
					color: root.c.error
					wrapMode: Text.WordWrap
					maximumLineCount: 3
					elide: Text.ElideRight
					font.family: Fonts.ui
					font.pixelSize: root.o.error.size
				}
			}
		}

		// Footer: "n / 9" and Back, Skip and the primary button.
		Item {
			id: footer
			anchors.bottom: parent.bottom
			width: parent.width
			height: root.o.footer.minHeight

			Text {
				objectName: "progress"
				x: root.o.footer.padX
				anchors.verticalCenter: parent.verticalCenter
				text: (root.index + 1) + " / " + root.count
				color: root.c.muted
				font.family: Fonts.ui
				font.pixelSize: root.o.footer.progress
				font.features: { "tnum": 1 }
				Accessible.name: I18n.t("ui.onboarding.stepValue1OfValue2", { value1: root.index + 1, value2: root.count })
			}

			Row {
				anchors.right: parent.right
				anchors.rightMargin: root.o.footer.padX
				anchors.verticalCenter: parent.verticalCenter
				spacing: root.o.footer.gap

				RoundButton {
					objectName: "back"
					anchors.verticalCenter: parent.verticalCenter
					visible: root.index > 0
					icon: "arrow-left"
					iconSize: root.o.footer.backIcon
					Accessible.name: I18n.t("ui.onboarding.previousStep")
					onClicked: root.back()
				}
				Item {
					objectName: "skip"
					anchors.verticalCenter: parent.verticalCenter
					visible: root.page.kind !== "finish"
					width: skipLabel.implicitWidth
					height: skipLabel.implicitHeight + 12
					opacity: root.busy ? root.o.disabledOpacity : 1
					Text {
						id: skipLabel
						anchors.centerIn: parent
						text: I18n.t("ui.onboarding.skip")
						color: skipArea.containsMouse && !root.busy ? root.c.text : root.c.muted
						font.family: Fonts.ui
						font.pixelSize: root.o.footer.link
						font.underline: skipArea.containsMouse && !root.busy
					}
					MouseArea {
						id: skipArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: root.dismiss()
					}
				}
				Rectangle {
					objectName: "primary"
					anchors.verticalCenter: parent.verticalCenter
					readonly property bool hovered: primaryArea.containsMouse && !root.busy
					width: Math.max(root.o.primary.minWidth, primaryRow.implicitWidth + root.o.primary.padX * 2)
					height: primaryRow.implicitHeight + root.o.primary.padY * 2
					radius: root.o.radius
					color: hovered ? root.c.primaryHover : root.c.primary
					opacity: root.busy ? root.o.disabledOpacity : 1
					Row {
						id: primaryRow
						anchors.centerIn: parent
						spacing: root.o.primary.gap
						Text {
							objectName: "primaryLabel"
							anchors.verticalCenter: parent.verticalCenter
							text: root.busy ? I18n.t("ui.onboarding.saving")
								: root.page.kind === "welcome" ? I18n.t("ui.onboarding.showMeAround")
								: root.page.kind === "finish" ? I18n.t("ui.onboarding.letSBloom")
								: I18n.t("ui.onboarding.continue")
							color: root.c.primaryText
							font.family: Fonts.uiFor(Font.DemiBold)
							font.weight: Font.DemiBold
							font.pixelSize: root.o.primary.text
						}
						SvgIcon {
							anchors.verticalCenter: parent.verticalCenter
							visible: root.page.kind !== "finish"
							name: "arrow-right"
							size: root.o.primary.icon
							color: root.c.primaryText
						}
					}
					MouseArea {
						id: primaryArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: {
							if (root.busy)
								return;
							if (root.page.kind === "finish")
								root.dismiss();
							else
								root.next();
						}
					}
				}
			}
		}
	}

	// The hand-drawn arrow to the live surface, in card units; it fades with the page.
	GuideArrow {
		id: arrow
		objectName: "arrow"
		visible: root.page.anchor !== "center" && root.anchorPlacement !== null
		x: root.anchorPlacement ? root.anchorPlacement.x : 0
		y: (root.anchorPlacement ? root.anchorPlacement.y : 0)
		width: root.anchorPlacement ? root.anchorPlacement.width : 112
		height: root.anchorPlacement ? root.anchorPlacement.height : 56
		rotation: root.anchorPlacement ? root.anchorPlacement.rotation : 0
		opacity: pageView.opacity
		color: root.c.arrow
		reducedMotion: root.reducedMotion
	}

	// A segmented control (Bloom's .onboarding-segments): options are
	// [{ value, label }]; the selected one is raised with a check.
	component Segments: Rectangle {
		id: segments
		property var options: []
		property string value
		signal picked(string value)
		implicitHeight: 29 + root.o.modes.pad * 2 + 2
		radius: root.o.modes.radius
		color: root.c.control
		border.width: 1
		border.color: root.c.border
		Row {
			x: root.o.modes.pad + 1
			y: root.o.modes.pad + 1
			width: segments.width - x * 2
			height: segments.height - y * 2
			Repeater {
				model: segments.options
				Rectangle {
					required property var modelData
					readonly property bool selected: segments.value === modelData.value
					objectName: "segment:" + modelData.value
					width: parent.width / segments.options.length
					height: parent.height
					radius: root.o.modes.segmentRadius
					color: selected ? root.c.selected : "transparent"
					layer.enabled: selected
					layer.effect: MultiEffect {
						shadowEnabled: true
						shadowColor: "#1c000000"
						shadowVerticalOffset: 1
						shadowBlur: 0.25
					}
					Row {
						anchors.centerIn: parent
						spacing: root.o.modes.checkGap
						Text {
							anchors.verticalCenter: parent.verticalCenter
							text: modelData.label
							color: selected ? root.c.text : root.c.muted
							font.family: Fonts.ui
							font.pixelSize: root.o.modes.segmentText
						}
						SvgIcon {
							anchors.verticalCenter: parent.verticalCenter
							visible: selected
							name: "check"
							size: root.o.modes.check
							color: root.c.text
						}
					}
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						enabled: !root.busy
						onClicked: if (!selected) segments.picked(modelData.value)
					}
				}
			}
		}
	}

	component ModeChoice: Column {
		id: choice
		property string surface
		readonly property string key: choice.surface === "island" ? "bloom-notch-mode" : "bloom-dock-mode"
		readonly property string fallback: choice.surface === "island" ? "fixed" : "smart"
		readonly property string value: root.store?.values?.[choice.key] ?? choice.fallback
		readonly property var explanations: ({
			island: { fixed: "ui.onboarding.staysVisibleWithYourClockAndQuickInformationInReach",
				smart: "ui.onboarding.movesAsideWhenAWindowOverlapsItReturnToThe",
				peek: "ui.onboarding.waitsAtTheTopEdgeMoveThereToRevealIt" },
			dock: { fixed: "ui.onboarding.staysVisibleAndReservesSpaceBeneathYourWindows",
				smart: "ui.onboarding.movesAsideWhenAWindowOverlapsItReturnToThe2",
				peek: "ui.onboarding.waitsAtTheBottomEdgeMoveThereToRevealIt" }
		})
		objectName: "modes:" + choice.surface

		Item {
			width: parent.width
			height: legend.implicitHeight + root.o.modes.legendGap
			Text {
				id: legend
				text: choice.surface === "island" ? I18n.t("ui.onboarding.theIsland") : I18n.t("ui.onboarding.theDock")
				color: root.c.text
				font.family: Fonts.uiFor(Font.DemiBold)
				font.weight: Font.DemiBold
				font.pixelSize: root.o.modes.legend
			}
			Text {
				anchors.right: parent.right
				anchors.baseline: legend.baseline
				text: I18n.t("ui.onboarding.default") + root.behaviors[choice.fallback]
				color: root.c.muted
				font.family: Fonts.ui
				font.pixelSize: root.o.modes.legendNote
			}
		}
		Segments {
			width: parent.width
			value: choice.value
			options: ["fixed", "smart", "peek"].map(v => ({ value: v, label: root.behaviors[v] }))
			onPicked: v => root._save(choice.key, v)
		}
		Text {
			topPadding: root.o.modes.noteTop
			width: parent.width
			height: Math.max(implicitHeight, root.o.modes.noteTop + root.o.modes.noteMin)
			text: I18n.t(choice.explanations[choice.surface][choice.value] ?? "")
			color: root.c.muted
			wrapMode: Text.WordWrap
			font.family: Fonts.ui
			font.pixelSize: root.o.modes.note
			lineHeightMode: Text.FixedHeight
			lineHeight: root.o.modes.note * root.o.modes.noteLine
		}
	}

	Component {
		id: preferences
		Column {
			objectName: "preferences"
			topPadding: root.o.preferences.top
			readonly property string theme: root.store?.values?.["bloom-theme-mode"] ?? "dark"
			readonly property bool updates: root.store?.values?.["bloom-show-update-indicator"] ?? true

			Item {
				width: parent.width
				height: Math.max(root.o.preferences.rowMin, appearance.height + root.o.preferences.rowPad * 2)
				Text {
					anchors.verticalCenter: parent.verticalCenter
					text: I18n.t("settings.tabs.appearance")
					color: root.c.text
					font.family: Fonts.ui
					font.pixelSize: root.o.preferences.label
				}
				Segments {
					id: appearance
					objectName: "appearance"
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					width: 270
					value: parent.parent.theme
					options: [
						{ value: "dark", label: I18n.t("ui.onboarding.dark") },
						{ value: "light", label: I18n.t("ui.onboarding.light") }
					].concat(parent.parent.theme === "custom" ? [{ value: "custom", label: I18n.t("ui.onboarding.customCurrent") }] : [])
						.concat([{ value: "adaptive", label: I18n.t("ui.onboarding.adaptiveColor") }])
					onPicked: v => root._save("bloom-theme-mode", v)
				}
			}
			Rectangle { width: parent.width; height: 1; color: root.c.border }
			Item {
				objectName: "updates"
				width: parent.width
				height: root.o.preferences.rowMin
				Text {
					anchors.verticalCenter: parent.verticalCenter
					text: I18n.t("linux.onboarding.updateIndicator")
					color: root.c.text
					font.family: Fonts.ui
					font.pixelSize: root.o.preferences.label
				}
				Rectangle {
					id: toggle
					readonly property var t: root.o.preferences.toggle
					readonly property bool checked: parent.parent.updates
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					width: t.width
					height: t.height
					radius: t.height
					color: checked ? root.o.toggleOn : root.c.toggle
					Behavior on color { enabled: !root.reducedMotion; ColorAnimation { duration: root.o.preferences.toggleMs } }
					Rectangle {
						x: toggle.t.pad + (toggle.checked ? toggle.t.width - toggle.t.knob - toggle.t.pad * 2 : 0)
						y: toggle.t.pad
						width: toggle.t.knob
						height: toggle.t.knob
						radius: width / 2
						color: "#fafafa"
						Behavior on x { enabled: !root.reducedMotion; NumberAnimation { duration: root.o.preferences.toggleMs } }
					}
				}
				MouseArea {
					anchors.fill: parent
					cursorShape: Qt.PointingHandCursor
					enabled: !root.busy
					onClicked: root._save("bloom-show-update-indicator", !toggle.checked)
				}
			}
		}
	}
}
