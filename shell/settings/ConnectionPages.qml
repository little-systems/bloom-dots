import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens

// Settings' own Network and Bluetooth pages, on the same rows as every other
// page. `net` and `bt` are the Network and Bluetooth services, or stand-ins.
Column {
	id: root
	property QtObject theme
	required property string page
	property var net
	property var bt
	property var sys
	property color accent: "#007aff"

	property string _openNet: ""
	property string _openDevice: ""
	property string _password: ""
	property string _pin: ""
	// A switch that hasn't reached the wanted state by now didn't work.
	property var _wantWifi: null
	property var _wantBt: null
	property string _toggleError: ""
	Timer {
		id: toggleCheck
		interval: 5000
		onTriggered: {
			if (root._wantWifi !== null && root.net.wifiEnabled !== root._wantWifi) root._toggleError = "Wi-Fi didn't change. Try again.";
			if (root._wantBt !== null && root.bt.powered !== root._wantBt) root._toggleError = "Bluetooth didn't change. Try again.";
			root._wantWifi = null;
			root._wantBt = null;
		}
	}
	function _setWifi(on) {
		root._toggleError = "";
		root._wantWifi = on;
		root.net.setWifi(on);
		toggleCheck.restart();
	}
	function _setBt(on) {
		root._toggleError = "";
		const refused = root.bt.setPowered(on);
		if (refused) {
			root._toggleError = refused;
			return;
		}
		root._wantBt = on;
		toggleCheck.restart();
	}

	width: parent.width

	// One object serves both pages, so watching follows the page, not the object:
	// moving Network to Bluetooth must start Bluetooth or it reads as no adapter.
	property string _watching: ""
	function _watch(next) {
		if (next === root._watching) return;
		if (root._watching === "network") root.net.hold("settings", false);
		if (root._watching === "bluetooth") {
			root.bt.discover(false);
			root.bt.hold("settings", false);
		}
		root._watching = next;
		root._openNet = "";
		root._openDevice = "";
		if (next === "network") {
			root.net.clearError();
			root.net.hold("settings", true);
			if (root.net.wifiEnabled) root.net.refresh(true);
		} else if (next === "bluetooth") {
			root.bt.clearError();
			root.bt.hold("settings", true);
		}
	}
	onPageChanged: root._watch(root.page)
	Component.onCompleted: root._watch(root.page)
	Component.onDestruction: root._watch("")

	function _wifiIcon(signal) {
		return signal >= 67 ? "wifi" : signal >= 34 ? "wifi-high" : signal >= 10 ? "wifi-low" : "wifi-zero";
	}
	function _netStatus(n) {
		if (root.net.busy === n.ssid) return "Connecting…";
		if (n.connected) return "Connected";
		if (n.saved) return "Saved";
		return n.security === "open" ? "Open" : "Secured";
	}
	function _deviceIcon(d) {
		const kind = String(d.icon || "");
		if (kind.indexOf("headset") >= 0 || kind.indexOf("headphone") >= 0) return "headphones";
		if (kind.indexOf("mouse") >= 0) return "mouse";
		if (kind.indexOf("keyboard") >= 0) return "keyboard";
		if (kind.indexOf("phone") >= 0) return "smartphone";
		return "bluetooth";
	}
	function _errorText(e) {
		const code = e ? e.code : "";
		return ({ "wrong-password": "Wrong password", "password-required": "This network needs a password", timeout: "Timed out" })[code] ?? (code ? "Something went wrong" : "");
	}
	function _connect(ssid) {
		root.net.connect(ssid, root._password);
		root._password = "";
	}

	Text {
		objectName: "toggleError"
		visible: root._toggleError !== ""
		width: parent.width
		bottomPadding: 10
		leftPadding: 6
		text: root._toggleError
		color: "#ff8a80"
		font.family: Fonts.ui
		font.pixelSize: 12
	}

	component Message: Text {
		width: parent.width
		leftPadding: Tokens.settings.row.inset
		rightPadding: 14
		bottomPadding: 10
		wrapMode: Text.Wrap
		font.family: Fonts.ui
		font.pixelSize: 12
		color: root.theme.textMuted
	}

	// Network

	Column {
		visible: root.page === "network"
		width: parent.width

		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "wifi"; label: "Wi-Fi"; divider: false
				desc: !root.net.loaded ? "Checking…" : !root.net.available ? "No Wi-Fi adapter found" : !root.net.wifiEnabled ? "Off" : root.net.connected ? "Connected to " + root.net.ssid : "Not connected"
				SToggle { objectName: "wifi"; accessibleName: "Wi-Fi"; theme: root.theme; enabled: root.net.loaded && root.net.available; checked: root.net.wifiEnabled; onToggled: root._setWifi(!root.net.wifiEnabled) }
			}
		}

		Item {
			visible: root.net.loaded && root.net.wifiEnabled
			width: parent.width
			height: 40
			SGroupLabel { y: 2; theme: root.theme; text: "Networks · " + root.net.networks.length }
			SChip {
				objectName: "scan"
				x: parent.width - width
				y: 8
				theme: root.theme; accent: root.accent; icon: "refresh-cw"
				text: root.net.scanning ? "Scanning…" : "Scan"
				onClicked: root.net.refresh(true)
			}
		}
		SGroup {
			visible: root.net.loaded && root.net.wifiEnabled
			theme: root.theme
			Repeater {
				model: root.net.networks
				delegate: Column {
					id: network
					required property var modelData
					required property int index
					readonly property bool open: root._openNet === network.modelData.ssid
					readonly property bool enterprise: network.modelData.security === "enterprise"
					readonly property bool needsPassword: !network.modelData.saved && !network.modelData.connected && network.modelData.security !== "open" && !network.enterprise
					readonly property var error: root.net.lastError && root.net.lastError.ssid === network.modelData.ssid ? root.net.lastError : null
					width: parent.width

					SRow {
						objectName: "net:" + network.modelData.ssid
						theme: root.theme; action: true; icon: root._wifiIcon(network.modelData.signal)
						label: network.modelData.ssid
						desc: root._netStatus(network.modelData)
						divider: !network.open && network.index < root.net.networks.length - 1
						onClicked: {
							root.net.clearError();
							root._password = "";
							root._openNet = network.open ? "" : network.modelData.ssid;
						}
						SvgIcon {
							visible: network.modelData.security !== "open"
							name: "lock"
							size: 13
							color: root.theme.textMuted
						}
					}
					Rectangle {
						visible: network.open
						width: parent.width
						height: visible ? netDetail.implicitHeight : 0
						color: Qt.rgba(1, 1, 1, 0.025)
						Column {
							id: netDetail
							width: parent.width
							topPadding: 2
							bottomPadding: 10
							spacing: 6

							Message {
								visible: network.enterprise
								bottomPadding: 0
								text: "This network needs a sign-in that Network Manager's own tools handle."
							}
							Row {
								x: Tokens.settings.row.inset
								spacing: 6
								SField {
									objectName: "password:" + network.modelData.ssid
									visible: network.needsPassword || (network.error !== null && network.error.code === "wrong-password")
									width: 220
									theme: root.theme
									secret: true
									placeholder: "Password"
									text: root._password
									onTextChanged: root._password = text
									onAccepted: root._connect(network.modelData.ssid)
								}
								SChip {
									objectName: "netConnect:" + network.modelData.ssid
									visible: !network.modelData.connected && !network.enterprise
									theme: root.theme; accent: root.accent; active: true; text: "Connect"
									onClicked: root._connect(network.modelData.ssid)
								}
								SChip {
									objectName: "netDisconnect:" + network.modelData.ssid
									visible: network.modelData.connected
									theme: root.theme; accent: root.accent; text: "Disconnect"
									onClicked: root.net.disconnect(network.modelData.ssid)
								}
								SChip {
									objectName: "netForget:" + network.modelData.ssid
									visible: network.modelData.saved
									theme: root.theme; accent: root.accent; text: "Forget"
									onClicked: {
										root.net.forget(network.modelData.ssid);
										root._openNet = "";
									}
								}
							}
							Message {
								objectName: "netError"
								visible: network.error !== null
								bottomPadding: 0
								text: root._errorText(network.error)
								color: "#ff8a80"
							}
						}
					}
				}
			}
		}

		SGroupLabel { theme: root.theme; text: "VPN" }
		Text {
			objectName: "noVpn"
			visible: !root.sys || root.sys.vpns.length === 0
			leftPadding: 2
			text: "No VPNs are set up. Add one with NetworkManager."
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: 12
		}
		SGroup {
			visible: !!root.sys && root.sys.vpns.length > 0
			theme: root.theme
			Repeater {
				model: root.sys ? root.sys.vpns : []
				delegate: SRow {
					id: vpnRow
					required property var modelData
					required property int index
					theme: root.theme; icon: "lock"; label: vpnRow.modelData.name; desc: vpnRow.modelData.active === "yes" ? "Connected" : "Not connected"
					divider: vpnRow.index < root.sys.vpns.length - 1
					SToggle { objectName: "vpn:" + vpnRow.modelData.name; accessibleName: vpnRow.modelData.name; theme: root.theme; checked: vpnRow.modelData.active === "yes"; onToggled: value => root.sys.setVpn(vpnRow.modelData.name, value) }
				}
			}
		}
	}

	// Bluetooth

	Column {
		visible: root.page === "bluetooth"
		width: parent.width

		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "bluetooth"; label: "Bluetooth"; divider: false
				desc: !root.bt.loaded ? "Checking…" : root.bt.error ? "Couldn't read Bluetooth" : !root.bt.available ? "No Bluetooth adapter found" : root.bt.powered ? "On" : "Off"
				SToggle { objectName: "bluetooth"; accessibleName: "Bluetooth"; theme: root.theme; enabled: root.bt.loaded && root.bt.available; checked: root.bt.powered; onToggled: root._setBt(!root.bt.powered) }
			}
		}

		SGroupLabel { visible: root.bt.powered && root.bt.paired.length > 0; theme: root.theme; text: "My Devices" }
		SGroup {
			visible: root.bt.powered && root.bt.paired.length > 0
			theme: root.theme
			Repeater {
				model: root.bt.paired
				delegate: Column {
					id: device
					required property var modelData
					required property int index
					readonly property bool open: root._openDevice === device.modelData.path
					width: parent.width

					SRow {
						objectName: "device:" + device.modelData.name
						theme: root.theme; action: true; icon: root._deviceIcon(device.modelData)
						label: device.modelData.name
						desc: root.bt.busy === device.modelData.path ? "Working…" : device.modelData.connected ? "Connected" : "Not connected"
						divider: !device.open && device.index < root.bt.paired.length - 1
						onClicked: root._openDevice = device.open ? "" : device.modelData.path
					}
					Row {
						visible: device.open
						x: Tokens.settings.row.inset
						bottomPadding: 12
						spacing: 8
						SChip {
							objectName: "deviceConnect:" + device.modelData.name
							theme: root.theme; accent: root.accent; active: !device.modelData.connected
							text: device.modelData.connected ? "Disconnect" : "Connect"
							onClicked: root.bt.setConnected(device.modelData.path, !device.modelData.connected)
						}
						SChip {
							objectName: "deviceRemove:" + device.modelData.name
							theme: root.theme; accent: root.accent; text: "Remove"
							onClicked: {
								root.bt.unpair(device.modelData.path);
								root._openDevice = "";
							}
						}
					}
				}
			}
		}

		SGroupLabel { visible: root.bt.powered; theme: root.theme; text: "Add a Device" }
		SGroup {
			visible: root.bt.powered
			theme: root.theme
			SRow {
				objectName: "discover"
				theme: root.theme; icon: "plus"; action: true; divider: root.bt.nearby.length > 0
				label: root.bt.discovering ? "Stop Looking" : "Look for Devices"
				desc: root.bt.discovering ? "Put your device in pairing mode" : "Find devices nearby"
				onClicked: root.bt.discover(!root.bt.discovering)
			}
			Repeater {
				model: root.bt.nearby
				delegate: Column {
					id: candidate
					required property var modelData
					required property int index
					readonly property bool pairing: root.bt.pairing === candidate.modelData.path
					readonly property var prompt: candidate.pairing ? root.bt.prompt : null
					width: parent.width

					SRow {
						objectName: "nearby:" + candidate.modelData.name
						theme: root.theme; action: true; icon: root._deviceIcon(candidate.modelData)
						label: candidate.modelData.name
						desc: candidate.pairing ? "Pairing…" : "Tap to pair"
						divider: !candidate.prompt && candidate.index < root.bt.nearby.length - 1
						onClicked: if (!candidate.pairing) root.bt.pair(candidate.modelData.path)
					}
					Column {
						visible: candidate.prompt !== null
						width: parent.width
						bottomPadding: 12
						spacing: 8

						Message {
							objectName: "pairPrompt"
							bottomPadding: 0
							text: {
								const p = candidate.prompt;
								if (!p) return "";
								if (p.kind === "provide") return "Enter the PIN shown on the device.";
								if (p.kind === "confirm") return "Does the device show " + p.pin + "?";
								return "Type " + p.pin + " on the device, then press Enter on it.";
							}
						}
						SField {
							objectName: "pin"
							visible: !!candidate.prompt && candidate.prompt.kind === "provide"
							x: Tokens.settings.row.inset
							theme: root.theme
							placeholder: "PIN"
							text: root._pin
							onTextChanged: root._pin = text
						}
						Row {
							x: Tokens.settings.row.inset
							spacing: 8
							SChip {
								objectName: "pairYes"
								visible: !!candidate.prompt && candidate.prompt.kind !== "display"
								theme: root.theme; accent: root.accent; active: true
								text: candidate.prompt && candidate.prompt.kind === "confirm" ? "Yes, Pair" : "Pair"
								onClicked: {
									root.bt.respond(true, root._pin);
									root._pin = "";
								}
							}
							SChip {
								objectName: "pairNo"
								theme: root.theme; accent: root.accent; text: "Cancel"
								onClicked: root.bt.respond(false, "")
							}
						}
					}
				}
			}
		}
		Text {
			objectName: "btError"
			visible: !!root.bt.lastError
			width: parent.width
			topPadding: 8
			leftPadding: 6
			text: "Bluetooth couldn't finish that. Try again."
			color: "#ff8a80"
			font.family: Fonts.ui
			font.pixelSize: 12
		}
	}
}
