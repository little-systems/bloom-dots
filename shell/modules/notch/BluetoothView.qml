import QtQuick
import "../../common/tokens.js" as Tokens
import "../../services/bluetooth.js" as Logic
import "device-art.js" as Art
import "qp"
import "../../common/render"

// Bloom's Bluetooth panel (BluetoothPanel.tsx, QuickPanel.css .qp): paired
// devices with Connect/Disconnect/Remove and an audio device's "Looks like"
// chips, and the "Add a device" view, which looks for nearby devices and
// pairs one, answering the agent's passkey prompts. Pure: BluetoothPanel.qml
// binds the Bluetooth service.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property bool enabled: false
	property bool available: true
	// Paired devices { path, name, kind, connected, battery } and nearby ones
	// { path, name, kind }.
	property var devices: []
	property var nearby: []
	// A connect/disconnect/remove in progress, the device pairing, the
	// agent's request ({ id, kind, pin }) and the last failure ({ id, code }).
	property string busy: ""
	property string pairing: ""
	property var prompt: null
	property var error: null
	// "Looks like" picks by device name (bloom-device-looks).
	property var looks: ({})
	property bool settingsAvailable: false
	property bool adding: false
	// The session that looks for devices couldn't run.
	property bool lookFailed: false
	// A pairing keeps the notch open (Bloom's onPinChange).
	readonly property bool pinned: root.pairing !== "" || root._typing
	readonly property real scrollY: root.adding ? nearbyList.scrollY : pairedList.scrollY

	signal back()
	signal toggle()
	signal discover(bool active)
	signal pairRequested(string path)
	signal respond(bool accept, string pin)
	signal connectRequested(string path, bool connected)
	signal removeRequested(string path)
	// A pick for `name`; "" clears it (picking Bloom's own guess).
	signal lookChosen(string name, string art)
	signal errorCleared()
	signal openSettings()

	property string selected: ""
	property bool _typing: false
	property string _pairedFrom: ""

	function guessFor(device) {
		return Art.artForKind(device.kind || "other", device.name);
	}
	function _kindIcon(kind) {
		return ({ audio: "headphones", phone: "smartphone", computer: "laptop", keyboard: "keyboard",
			mouse: "mouse", gamepad: "gamepad-2", wearable: "watch" })[kind] ?? "bluetooth";
	}
	function _statusText(d) {
		if (root.busy === d.path) return d.connected ? "Disconnecting…" : "Connecting…";
		if (!d.connected) return "Not connected";
		return d.battery !== null && d.battery !== undefined ? "Connected · " + d.battery + "%" : "Connected";
	}
	function _setAdding(wanted) {
		if (root.adding === wanted) return;
		root.adding = wanted;
		root.discover(wanted);
	}
	function _toggleRow(path) {
		if (root.error) root.errorCleared();
		root.selected = root.selected === path ? "" : path;
	}
	function _pair(path) {
		if (root.error) root.errorCleared();
		root._pairedFrom = path;
		root.pairRequested(path);
	}
	// Bloom's .qp-pin inside a note: the code in the text colour, spaced.
	function _pin(pin) {
		return "<font color=\"" + root.theme.text + "\"><b>" + (pin || "") + "</b></font>";
	}

	onPairingChanged: {
		if (root.pairing !== "" || root._pairedFrom === "") return;
		const path = root._pairedFrom;
		root._pairedFrom = "";
		// Paired without an error: Bloom goes back to the paired list.
		Qt.callLater(() => {
			if (!root.error || root.error.id !== path) root._setAdding(false);
		});
	}
	onEnabledChanged: if (!root.enabled) { root.selected = ""; root._setAdding(false); }
	Component.onDestruction: if (root.adding) root.discover(false)

	Column {
		x: Tokens.qp.padding.side
		y: Tokens.qp.padding.top
		width: root.width - 2 * Tokens.qp.padding.side
		height: root.height - Tokens.qp.padding.top - Tokens.qp.padding.bottom
		spacing: Tokens.qp.gap

		QpHeader {
			id: header
			objectName: "header"
			width: parent.width
			theme: root.theme
			title: root.adding ? "Add a device" : "Bluetooth"
			onBack: root.adding ? root._setAdding(false) : root.back()

			QpIconButton {
				objectName: "add"
				visible: !root.adding
				theme: root.theme
				icon: "plus"
				enabled: root.enabled
				onClicked: root._setAdding(true)
			}
			QpSwitch {
				objectName: "switch"
				theme: root.theme
				checked: root.enabled
				enabled: root.available
				onToggled: root.toggle()
			}
		}

		Item {
			width: parent.width
			height: parent.height - header.height - (footer.visible ? footer.height + Tokens.qp.gap : 0) - Tokens.qp.gap

			QpEmpty {
				objectName: "empty"
				anchors.fill: parent
				visible: !root.enabled || (root.adding ? root.nearby.length === 0 : root.devices.length === 0)
				theme: root.theme
				icon: root.enabled && root.adding && !root.lookFailed ? "loader-circle" : ""
				text: !root.enabled ? "Bluetooth is off"
					: root.adding ? (root.lookFailed ? "Couldn't look for devices" : "Looking for devices. Make sure yours is in pairing mode.")
					: "No paired devices"

				Loader {
					anchors.horizontalCenter: parent.horizontalCenter
					active: root.enabled && !root.adding && root.devices.length === 0
					sourceComponent: QpButton {
						objectName: "addDevice"
						theme: root.theme
						text: "Add device"
						onClicked: root._setAdding(true)
					}
				}
			}

			// Paired devices.
			QpList {
				id: pairedList
				objectName: "list"
				anchors.fill: parent
				visible: root.enabled && !root.adding && root.devices.length > 0
				theme: root.theme
				keyName: "path"
				items: root.enabled && !root.adding ? root.devices : []

				delegate: Column {
					id: device
					required property string key
					readonly property var d: pairedList.entry(device.key) ?? ({ path: device.key, name: "", kind: "other", connected: false, battery: null })
					readonly property bool expanded: root.selected === device.d.path
					readonly property bool isBusy: root.busy === device.d.path
					width: pairedList.rowWidth

					QpRow {
						objectName: "row:" + device.d.path
						width: parent.width
						theme: root.theme
						icon: root._kindIcon(device.d.kind)
						name: device.d.name
						sub: root._statusText(device.d)
						active: device.d.connected
						expanded: device.expanded
						onClicked: root._toggleRow(device.d.path)

						Loader {
							active: device.expanded
							visible: active
							width: parent.width
							sourceComponent: Column {
								spacing: Tokens.qp.actions.gap

								// .qp-chips: what the connection popup draws for it.
								Loader {
									active: device.d.kind === "audio"
									width: pairedList.rowWidth - Tokens.qp.actions.left - Tokens.qp.actions.side
									sourceComponent: Flow {
										readonly property string shown: root.looks[device.d.name] || root.guessFor(device.d)
										spacing: Tokens.qp.chip.gap

										// .qp-note, centred on the chips' line.
										Item {
											width: looksNote.implicitWidth
											height: Tokens.qp.chip.height

											Text {
												id: looksNote
												objectName: "looksNote"
												anchors.verticalCenter: parent.verticalCenter
												anchors.alignWhenCentered: false
												text: "Looks like"
												color: root.theme.textMuted
												font.family: Fonts.family
												font.pixelSize: Tokens.qp.note
											}
										}
										Repeater {
											model: Art.DEVICE_LOOKS
											QpChip {
												required property var modelData
												objectName: "look-" + modelData.art
												theme: root.theme
												text: modelData.label
												on: parent.shown === modelData.art
												onClicked: root.lookChosen(device.d.name, modelData.art === root.guessFor(device.d) ? "" : modelData.art)
											}
										}
									}
								}

								Row {
									spacing: Tokens.qp.actions.gap

									QpButton {
										objectName: device.d.connected ? "disconnect" : "connect"
										theme: root.theme
										text: device.d.connected ? "Disconnect" : "Connect"
										primary: !device.d.connected
										busy: device.isBusy
										enabled: !device.isBusy
										onClicked: root.connectRequested(device.d.path, !device.d.connected)
									}
									QpButton {
										objectName: "remove"
										theme: root.theme
										text: "Remove"
										enabled: !device.isBusy
										onClicked: root.removeRequested(device.d.path)
									}
								}
							}
						}
					}

					ErrorLine { id_: device.d.path }
				}
			}

			// Nearby devices to pair.
			QpList {
				id: nearbyList
				objectName: "nearbyList"
				anchors.fill: parent
				visible: root.enabled && root.adding && root.nearby.length > 0
				theme: root.theme
				keyName: "path"
				items: root.enabled && root.adding ? root.nearby : []

				delegate: Column {
					id: candidate
					required property string key
					readonly property var d: nearbyList.entry(candidate.key) ?? ({ path: candidate.key, name: "", kind: "other" })
					readonly property bool isPairing: root.pairing === candidate.d.path
					readonly property bool asking: candidate.isPairing && !!root.prompt && root.prompt.id === candidate.d.path
					width: nearbyList.rowWidth

					QpRow {
						objectName: "row:" + candidate.d.path
						width: parent.width
						theme: root.theme
						icon: root._kindIcon(candidate.d.kind)
						name: candidate.d.name
						sub: candidate.isPairing ? "Pairing…" : "Click to pair"
						badge: candidate.isPairing ? "loader-circle" : ""
						badgeSpinning: candidate.isPairing
						expanded: candidate.isPairing
						clickable: root.pairing === ""
						onClicked: root._pair(candidate.d.path)

						Loader {
							active: candidate.asking
							visible: active
							width: parent.width
							sourceComponent: root.prompt && root.prompt.kind === "provide" ? providePrompt
								: root.prompt && root.prompt.kind === "confirm" ? confirmPrompt : displayPrompt
						}
					}

					ErrorLine { id_: candidate.d.path }
				}
			}
		}

		QpFooter {
			id: footer
			objectName: "footer"
			anchors.horizontalCenter: parent.horizontalCenter
			visible: root.settingsAvailable
			theme: root.theme
			text: "More Bluetooth settings"
			onClicked: root.openSettings()
		}
	}

	Component {
		id: displayPrompt
		Text {
			objectName: "promptNote"
			wrapMode: Text.Wrap
			textFormat: Text.StyledText
			text: "Type " + root._pin(root.prompt?.pin) + " on the device, then press Enter on it."
			color: root.theme.textMuted
			font.family: Fonts.family
			font.pixelSize: Tokens.qp.note
		}
	}

	Component {
		id: confirmPrompt
		Column {
			spacing: Tokens.qp.actions.gap

			Text {
				objectName: "promptNote"
				width: parent.width
				wrapMode: Text.Wrap
				textFormat: Text.StyledText
				text: "Does the device show " + root._pin(root.prompt?.pin) + "?"
				color: root.theme.textMuted
				font.family: Fonts.family
				font.pixelSize: Tokens.qp.note
			}
			Row {
				spacing: Tokens.qp.actions.gap
				QpButton { objectName: "yes"; theme: root.theme; text: "Yes, pair"; primary: true; onClicked: root.respond(true, "") }
				QpButton { objectName: "no"; theme: root.theme; text: "No"; onClicked: root.respond(false, "") }
			}
		}
	}

	Component {
		id: providePrompt
		Column {
			spacing: Tokens.qp.actions.gap

			QpInput {
				id: pinField
				objectName: "pin"
				width: parent.width
				theme: root.theme
				placeholder: "PIN shown on the device"
				Component.onCompleted: forceActiveFocus()
				onFocusedChanged: root._typing = focused
				onAccepted: if (text) root.respond(true, text)
				onEscaped: root.respond(false, "")
				Component.onDestruction: root._typing = false
			}
			Row {
				spacing: Tokens.qp.actions.gap
				QpButton { objectName: "pairButton"; theme: root.theme; text: "Pair"; primary: true; enabled: pinField.text !== ""; onClicked: root.respond(true, pinField.text) }
				QpButton { objectName: "cancel"; theme: root.theme; text: "Cancel"; onClicked: root.respond(false, "") }
			}
		}
	}

	// .qp-error: under a row, shown even once it collapses.
	component ErrorLine: Item {
		property string id_: ""
		readonly property bool shown: !!root.error && root.error.id === id_
		visible: shown
		width: parent ? parent.width : 0
		height: shown ? line.implicitHeight + Tokens.qp.error.bottom : 0

		Text {
			id: line
			objectName: "error:" + parent.id_
			x: Tokens.qp.error.left
			width: parent.width - Tokens.qp.error.left - Tokens.qp.error.side
			wrapMode: Text.Wrap
			text: root.error ? Logic.errorText(root.error.code) : ""
			color: Tokens.qp.error.color
			font.family: Fonts.family
			font.pixelSize: Tokens.qp.error.text
		}
	}
}
