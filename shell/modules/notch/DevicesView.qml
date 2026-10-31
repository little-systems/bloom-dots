import QtQuick
import "../../common"
import "../../common/tokens.js" as Tokens
import "../../services/devices.js" as Devices
import "device-art.js" as Art
import "qp"
import "../../common/render"

// Bloom's battery hub (ConnectedDevicesPanel.tsx, QuickPanel.css .bh-*):
// connected devices grouped by priority with their battery meters. An audio
// row opens its "Looks like" choice. Pure: ConnectedDevicesPanel.qml binds
// the services.
Item {
	id: root

	property QtObject theme: QpTheme {}
	// Devices.entries(...): this PC, connected Bluetooth devices, wired audio.
	property var entries: []
	property int threshold: 20
	property string pcStatus: ""

	// A pick for `name`; "" clears it (Bloom: picking its own guess).
	signal lookChosen(string name, string art)

	readonly property var groups: Devices.groupDevices(root.entries, root.threshold)
	property string expanded: ""

	// The notch height everything needs (Bloom's measureContent), before the
	// panel's 150..300 clamp.
	readonly property real panelHeight: 36 + Tokens.qp.padding.top + Tokens.bh.titleIcon + Tokens.qp.gap
		+ (root.groups.length ? list.height : 72) + Tokens.qp.padding.bottom

	function _low(part) {
		return !part.charging && part.level <= root.threshold;
	}

	function _parts(entry) {
		if (entry.buds) {
			const out = [];
			if (entry.buds.left) out.push({ label: "L", part: entry.buds.left });
			if (entry.buds.right) out.push({ label: "R", part: entry.buds.right });
			if (entry.buds.case) out.push({ label: "Case", part: entry.buds.case });
			return out;
		}
		return entry.level !== null ? [{ label: "", part: { level: entry.level, charging: entry.charging } }] : [];
	}

	function _sub(entry) {
		if (entry.kind === "pc") return root.pcStatus;
		if (entry.wired) return Devices.wiredSub(entry);
		if (entry.buds) return "Each bud and the case";
		return "Connected";
	}

	// .qp-header with the .bh-title-icon.
	Rectangle {
		id: titleIcon
		objectName: "titleIcon"
		y: Tokens.qp.padding.top
		width: Tokens.bh.titleIcon
		height: Tokens.bh.titleIcon
		radius: width / 2
		color: root.theme.groupBg

		SvgIcon {
			anchors.centerIn: parent
			name: "monitor-smartphone"
			size: Tokens.qp.row.glyph
			color: root.theme.text
		}
	}

	Text {
		objectName: "title"
		x: titleIcon.width + 4 + Tokens.qp.header.gap
		anchors.verticalCenter: titleIcon.verticalCenter
		text: "Connected devices"
		color: root.theme.text
		font.family: Fonts.familyFor(Font.DemiBold)
		font.pixelSize: Fonts.px(Tokens.qp.header.title)
		font.weight: Font.DemiBold
	}

	QpEmpty {
		visible: root.groups.length === 0
		y: titleIcon.y + titleIcon.height + Tokens.qp.gap
		width: root.width
		height: 72
		theme: root.theme
		text: "No devices connected"
	}

	QpScroll { flickable: scroller }

	Flickable {
		id: scroller
		y: titleIcon.y + titleIcon.height + Tokens.qp.gap
		width: root.width
		height: root.height - y - Tokens.qp.padding.bottom
		contentHeight: list.height
		clip: true
		boundsBehavior: Flickable.StopAtBounds
		interactive: false // QpScroll scrolls it

		Column {
			id: list
			objectName: "list"
			width: parent.width
			spacing: Tokens.bh.groupGap

			Repeater {
				model: root.groups

				Column {
					id: group
					required property var modelData
					readonly property string title: modelData.title

					objectName: "group-" + modelData.key
					width: list.width
					spacing: 2

					FracText {
						objectName: "groupTitle"
						x: Tokens.bh.groupTitle.padH
						// margin-bottom 2 on top of the list's 2 px gap.
						height: implicitHeight + 2
						text: group.modelData.title.toUpperCase()
						color: group.modelData.key === "low" ? Tokens.bh.red : root.theme.textMuted
						font.family: Fonts.familyFor(Font.DemiBold)
						font.weight: Font.DemiBold
						font.letterSpacing: Tokens.bh.groupTitle.tracking
						pixelSize: Tokens.bh.groupTitle.text
					}

					Repeater {
						model: group.modelData.entries

						Item {
							id: row
							required property var modelData
							readonly property bool lookable: modelData.kind === "audio"
							readonly property bool open: lookable && root.expanded === modelData.id
							readonly property var parts: root._parts(modelData)

							objectName: "row-" + modelData.id
							width: list.width
							height: rowBox.height + (looksLoader.item ? looksLoader.item.height : 0)

							Rectangle {
								objectName: "itemBackground"
								anchors.fill: parent
								radius: Tokens.bh.row.radius
								color: row.open ? root.theme.groupBg : "transparent"
							}

							Rectangle {
								id: rowBox
								objectName: "rowBackground"
								width: parent.width
								height: Tokens.bh.row.padV * 2 + Math.max(Tokens.bh.art, textColumn.height)
								radius: Tokens.bh.row.radius
								color: rowHover.hovered && !row.open ? root.theme.groupBg : "transparent"

								HoverHandler {
									id: rowHover
								}

								Item {
									objectName: "art"
									x: Tokens.bh.row.padH
									anchors.verticalCenter: parent.verticalCenter
									width: Tokens.bh.art
									height: Tokens.bh.art

									DeviceArt {
										visible: row.modelData.art !== null
										anchors.fill: parent
										still: true
										art: row.modelData.art || "device"
									}

									SvgIcon {
										objectName: "pcGlyph"
										visible: row.modelData.art === null
										anchors.centerIn: parent
										name: "laptop"
										size: Tokens.bh.artGlyph
										color: root.theme.text
									}
								}

								Column {
									id: textColumn
									x: Tokens.bh.row.padH + Tokens.bh.art + Tokens.bh.row.gap
									anchors.verticalCenter: parent.verticalCenter
									width: Math.max(0, (levels.visible ? levels.x - Tokens.bh.row.gap : rowBox.width - Tokens.bh.row.padH) - x)

									Text {
										objectName: "name"
										width: parent.width
										height: Tokens.qp.text * Tokens.qp.row.lineHeight
										verticalAlignment: Text.AlignVCenter
										text: row.modelData.name
										color: root.theme.text
										elide: Text.ElideRight
										maximumLineCount: 1
										font.family: Fonts.familyFor(Font.DemiBold)
										font.pixelSize: Fonts.px(Tokens.qp.text)
										font.weight: Font.DemiBold
									}

									FracText {
										objectName: "sub"
										width: parent.width
										height: Tokens.qp.row.sub * Tokens.qp.row.lineHeight
										verticalAlignment: Text.AlignVCenter
										text: root._sub(row.modelData)
										color: root.theme.textMuted
										elide: Text.ElideRight
										maximumLineCount: 1
										font.family: Fonts.family
										pixelSize: Tokens.qp.row.sub
									}
								}

								// .bh-meters, or "No battery info" for a wireless device.
								Item {
									id: levels
									visible: row.parts.length > 0 || !row.modelData.wired
									x: rowBox.width - Tokens.bh.row.padH - width
									anchors.verticalCenter: parent.verticalCenter
									width: row.parts.length ? meters.width : unknown.width
									height: row.parts.length ? meters.height : unknown.height

									FracText {
										id: unknown
										objectName: "unknown"
										visible: row.parts.length === 0
										text: "No battery info"
										color: root.theme.textMuted
										font.family: Fonts.family
										pixelSize: Tokens.bh.unknown
									}

									Row {
										id: meters
										visible: row.parts.length > 0
										spacing: Tokens.bh.meters.gap

										Repeater {
											model: row.parts

											Column {
												id: meter
												required property var modelData
												required property int index
												readonly property bool low: root._low(modelData.part)

												objectName: "meter-" + index
												width: Tokens.bh.meters.width
												spacing: Tokens.bh.meters.gapV

												Row {
													anchors.right: parent.right
													spacing: 2

													Text {
														objectName: "label"
														visible: meter.modelData.label !== ""
														anchors.verticalCenter: parent.verticalCenter
														rightPadding: 2
														text: meter.modelData.label
														color: root.theme.textMuted
														font.family: Fonts.family
														font.pixelSize: Fonts.px(Tokens.bh.meters.label)
													}

													FracText {
														objectName: "value"
														anchors.verticalCenter: parent.verticalCenter
														text: meter.modelData.part.level + "%"
														color: meter.low ? Tokens.bh.red : root.theme.text
														font.family: Fonts.familyFor(Font.DemiBold)
														font.weight: Font.DemiBold
														font.features: {
															"tnum": 1
														}
														pixelSize: Tokens.bh.meters.value
													}

													SvgIcon {
														objectName: "bolt"
														visible: meter.modelData.part.charging
														anchors.verticalCenter: parent.verticalCenter
														name: "zap-filled"
														size: Tokens.bh.meters.bolt
														strokeWidth: 0
														color: Tokens.bh.green
													}
												}

												Rectangle {
													objectName: "bar"
													width: parent.width
													height: Tokens.bh.meters.bar
													radius: Tokens.bh.meters.barRadius
													color: Qt.rgba(1, 1, 1, Tokens.bh.meters.track)
													clip: true

													Rectangle {
														objectName: "fill"
														width: parent.width * Math.max(4, meter.modelData.part.level) / 100
														height: parent.height
														radius: parent.radius
														color: meter.low ? Tokens.bh.red : Tokens.bh.green

														Behavior on width {
															NumberAnimation {
																duration: Tokens.bh.meters.fillMs
																easing.type: Easing.BezierSpline
																easing.bezierCurve: [0.25, 0.1, 0.25, 1, 1, 1]
															}
														}
													}
												}
											}
										}
									}
								}

								Loader {
									active: row.lookable
									anchors.fill: parent

									sourceComponent: PointerArea {
										objectName: "pointer"
										onClicked: root.expanded = row.open ? "" : row.modelData.id
									}
								}
							}

							// .bh-looks: padding 0 8 8 47; only while the row is open.
							Loader {
								id: looksLoader
								active: row.open
								x: 47
								y: rowBox.height

								sourceComponent: Flow {
								objectName: "looks"
								width: row.width - 47 - 8
								height: implicitHeight + 8
								spacing: Tokens.qp.chip.gap

								Text {
									height: Tokens.qp.chip.height
									verticalAlignment: Text.AlignVCenter
									text: "Looks like"
									color: root.theme.textMuted
									font.family: Fonts.family
									font.pixelSize: Fonts.px(Tokens.qp.note)
								}

								Repeater {
									model: row.modelData.wired ? Art.WIRED_DEVICE_LOOKS : Art.DEVICE_LOOKS

									QpChip {
										required property var modelData
										objectName: "look-" + modelData.art
										theme: root.theme
										text: modelData.label
										on: row.modelData.art === modelData.art
										onClicked: root.lookChosen(row.modelData.name, modelData.art === row.modelData.guess ? "" : modelData.art)
									}
								}
								}
							}
						}
					}
				}
			}
		}
	}
}
