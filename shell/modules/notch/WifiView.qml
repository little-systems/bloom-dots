import QtQuick
import "../../common/tokens.js" as Tokens
import "qp"
import "../../common/render"

// Bloom's Wi-Fi panel (WifiPanel.tsx, QuickPanel.css .qp): the header with
// scan and the radio switch, the networks (connected, saved, then by
// signal), a row's actions with the password field, Bloom's error text, and
// the settings footer. Pure: WifiPanel.qml binds the Network service.
Item {
	id: root

	property QtObject theme: QpTheme {}
	property bool enabled: false
	property bool available: true
	// network.js wifiList entries: { ssid, signal, security, connected, saved }.
	property var networks: []
	property bool scanning: false
	// The network a change is for, and the last failure as { ssid, code }.
	property string busy: ""
	property var error: null
	property bool settingsAvailable: false
	// Typing a password keeps the notch open (Bloom's onPinChange).
	readonly property bool pinned: root._typing

	signal back()
	signal toggle()
	signal scan()
	signal connectRequested(string ssid, string password)
	signal disconnectRequested(string ssid)
	signal forgetRequested(string ssid)
	signal openSettings()
	// Bloom's collapse clears the error; the owner holds it.
	signal errorCleared()

	// Personal networks take a typed password; anything else that isn't
	// open (work sign-in, WEP, OWE) goes to the settings tool.
	readonly property var _personal: ["wpa", "wpa2", "wpa3"]
	readonly property var _errorText: ({
		"wrong-password": "Wrong password",
		"password-required": "Enter the password",
		"password-length": "Wi-Fi passwords are 8 to 63 characters",
		"unsupported": "Connect to this network in your network settings",
		"not-found": "This network is out of range",
		"timeout": "Couldn't connect in time",
		"no-adapter": "No Wi-Fi adapter found",
		"failed": "Couldn't connect"
	})
	property string selected: ""
	// A saved network whose stored password stopped working gets a field.
	property string askPassword: ""
	property bool _typing: false
	// The connect this view asked for, to collapse the row when it lands.
	property string _connecting: ""

	function _collapse() {
		if (root.error) root.errorCleared();
		root.selected = "";
		root.askPassword = "";
		root._typing = false;
	}
	function _toggleRow(ssid) {
		const was = root.selected;
		root._collapse();
		if (was !== ssid) root.selected = ssid;
	}
	function _statusText(n) {
		if (root.busy === n.ssid) return "Connecting…";
		if (n.connected) return "Connected";
		if (n.saved) return "Saved";
		return n.security === "open" ? "Open" : "Secured";
	}
	function _signalIcon(signal) {
		return signal >= 75 ? "wifi" : signal >= 50 ? "wifi-high" : signal >= 25 ? "wifi-low" : "wifi-zero";
	}
	function _needsPassword(n) {
		return (!n.saved && root._personal.includes(n.security)) || root.askPassword === n.ssid;
	}
	function _handledBySettings(n) {
		return !n.saved && n.security !== "open" && !root._personal.includes(n.security);
	}
	function _connect(n, password) {
		root._connecting = n.ssid;
		root.connectRequested(n.ssid, password);
	}

	onBusyChanged: {
		if (root.busy !== "" || root._connecting === "") return;
		const ssid = root._connecting;
		root._connecting = "";
		// No error by the time the change ends: connected, so Bloom collapses.
		Qt.callLater(() => {
			if (!root.error || root.error.ssid !== ssid) {
				if (root.selected === ssid) root._collapse();
			}
		});
	}
	onErrorChanged: {
		const e = root.error;
		if (!e) return;
		const n = root.networks.find(x => x.ssid === e.ssid);
		// Bloom: a saved personal network that failed without a password asks for one.
		if (n && n.saved && root._personal.includes(n.security) && root.askPassword !== n.ssid
			&& (e.code === "wrong-password" || e.code === "password-required"))
			root.askPassword = n.ssid;
	}
	onEnabledChanged: if (!root.enabled) root._collapse()

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
			title: "Wi-Fi"
			onBack: root.back()

			QpIconButton {
				objectName: "refresh"
				theme: root.theme
				icon: "refresh-cw"
				spinning: root.scanning
				enabled: root.enabled && !root.scanning
				onClicked: root.scan()
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
			id: body
			width: parent.width
			height: parent.height - header.height - (footer.visible ? footer.height + Tokens.qp.gap : 0) - Tokens.qp.gap

			QpEmpty {
				objectName: "empty"
				anchors.fill: parent
				visible: !root.enabled || root.networks.length === 0
				theme: root.theme
				text: !root.enabled ? "Wi-Fi is off" : root.scanning ? "Looking for networks…" : "No networks found"
			}

			QpList {
				id: list
				objectName: "list"
				anchors.fill: parent
				visible: root.enabled && root.networks.length > 0
				theme: root.theme
				keyName: "ssid"
				items: root.enabled ? root.networks : []

				delegate: Column {
					id: entry
					required property string key
					readonly property var n: list.entry(entry.key) ?? ({ ssid: entry.key, signal: 0, security: "open", connected: false, saved: false })
					readonly property bool expanded: root.selected === entry.n.ssid
					readonly property bool isBusy: root.busy === entry.n.ssid
					width: list.rowWidth

					QpRow {
						objectName: "row:" + entry.n.ssid
						width: parent.width
						theme: root.theme
						icon: root._signalIcon(entry.n.signal)
						name: entry.n.ssid
						sub: root._statusText(entry.n)
						badge: entry.n.security !== "open" ? "lock" : ""
						active: entry.n.connected
						expanded: entry.expanded
						onClicked: root._toggleRow(entry.n.ssid)

						// Bloom renders a row's actions only while it is expanded: a
						// sign-in network's go to the settings tool, the rest are
						// the password field and Connect / Disconnect / Forget.
						Loader {
							active: entry.expanded
							visible: active
							width: parent.width
							sourceComponent: root._handledBySettings(entry.n) ? settingsActions : networkActions
						}
					}

					Component {
						id: settingsActions
						Column {
							spacing: Tokens.qp.actions.gap

							Text {
								objectName: "note"
								width: entry.width - Tokens.qp.actions.left - Tokens.qp.actions.side
								wrapMode: Text.Wrap
								text: "This network needs a sign-in your network settings handle."
								color: root.theme.textMuted
								font.family: Fonts.family
								font.pixelSize: Tokens.qp.note
							}
							Loader {
								active: root.settingsAvailable
								sourceComponent: QpButton {
									objectName: "openSettingsButton"
									theme: root.theme
									text: "Open Settings"
									onClicked: root.openSettings()
								}
							}
						}
					}

					Component {
						id: networkActions
						Column {
							spacing: Tokens.qp.actions.gap

							Loader {
								// Mounted only while asked for, so its field takes
								// focus as Bloom's autoFocus does.
								active: root._needsPassword(entry.n) && !entry.n.connected
								width: entry.width - Tokens.qp.actions.left - Tokens.qp.actions.side
								sourceComponent: QpInput {
									objectName: "password"
									theme: root.theme
									placeholder: "Password"
									echoMode: TextInput.Password
									enabled: !entry.isBusy
									Component.onCompleted: forceActiveFocus()
									onFocusedChanged: root._typing = focused
									onAccepted: if (text) root._connect(entry.n, text)
									onEscaped: root._collapse()
								}
								onLoaded: root._password = item
								onActiveChanged: if (!active) root._password = null
							}

							Row {
								spacing: Tokens.qp.actions.gap

								QpButton {
									objectName: entry.n.connected ? "disconnect" : "connect"
									theme: root.theme
									text: entry.n.connected ? "Disconnect" : "Connect"
									primary: !entry.n.connected
									busy: entry.isBusy && !entry.n.connected
									enabled: entry.n.connected || (!entry.isBusy
										&& !(root._needsPassword(entry.n) && !(root._password && root._password.text)))
									onClicked: {
										if (entry.n.connected) root.disconnectRequested(entry.n.ssid);
										else root._connect(entry.n, root._needsPassword(entry.n) && root._password ? root._password.text : "");
									}
								}
								Loader {
									active: entry.n.saved
									sourceComponent: QpButton {
										objectName: "forget"
										theme: root.theme
										text: "Forget"
										enabled: !entry.isBusy
										onClicked: root.forgetRequested(entry.n.ssid)
									}
								}
							}
						}
					}

					// .qp-error: under the row, shown even once it collapses.
					Item {
						visible: !!root.error && root.error.ssid === entry.n.ssid
						width: parent.width
						height: visible ? errorText.implicitHeight + Tokens.qp.error.bottom : 0

						Text {
							id: errorText
							objectName: "error:" + entry.n.ssid
							x: Tokens.qp.error.left
							width: parent.width - Tokens.qp.error.left - Tokens.qp.error.side
							wrapMode: Text.Wrap
							text: root.error ? (root._errorText[root.error.code] ?? root.error.code) : ""
							color: Tokens.qp.error.color
							font.family: Fonts.family
							font.pixelSize: Tokens.qp.error.text
						}
					}
				}
			}
		}

		QpFooter {
			id: footer
			objectName: "footer"
			anchors.horizontalCenter: parent.horizontalCenter
			visible: root.settingsAvailable
			theme: root.theme
			text: "More Wi-Fi settings"
			onClicked: root.openSettings()
		}
	}

	// The open password field, if any.
	property Item _password: null
}
