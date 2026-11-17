import QtQuick
import "../common"
import "../common/render"
import "../common/tokens.js" as Tokens
import "../common/i18n"

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
			if (root._wantWifi !== null && root.net.wifiEnabled !== root._wantWifi) root._toggleError = I18n.t("linux.settings.wiFiDidnTChangeTryAgain");
			if (root._wantBt !== null && root.bt.powered !== root._wantBt) root._toggleError = I18n.t("linux.settings.bluetoothDidnTChangeTryAgain");
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
		if (root.net.busy === n.ssid) return I18n.t("ui.bluetoothPanel.connecting");
		if (n.connected) return I18n.t("agentIntegrations.connected");
		if (n.saved) return I18n.t("ui.wifiPanel.saved");
		return n.security === "open" ? I18n.t("ui.dock.open") : I18n.t("ui.wifiPanel.secured");
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
		return ({ "wrong-password": I18n.t("ui.wifiPanel.wrongPassword"), "password-required": I18n.t("linux.settings.thisNetworkNeedsAPassword"), timeout: I18n.t("linux.settings.timedOut") })[code] ?? (code ? I18n.t("linux.settings.somethingWentWrong") : "");
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
		leftPadding: Tokens.settings.group.label.h
		text: root._toggleError
		color: "#ff8a80"
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(14)
	}

	component Message: Text {
		width: parent.width
		leftPadding: Tokens.settings.row.inset
		rightPadding: 14
		bottomPadding: 12
		wrapMode: Text.Wrap
		font.family: Fonts.ui
		font.pixelSize: Fonts.px(14)
		color: root.theme.textMuted
	}

	// Network

	Column {
		visible: root.page === "network"
		width: parent.width

		SGroup {
			theme: root.theme
			SRow {
				theme: root.theme; icon: "wifi"; label: I18n.t("notch.commandCenter.wifi"); divider: false
				desc: !root.net.loaded ? I18n.t("linux.settings.checking") : !root.net.available ? I18n.t("ui.wifiPanel.noWiFiAdapterFound") : !root.net.wifiEnabled ? I18n.t("notch.commandCenter.off") : root.net.connected ? I18n.t("linux.settings.connectedTo", { name: root.net.ssid }) : I18n.t("notch.commandCenter.notConnected")
				SToggle { objectName: "wifi"; accessibleName: I18n.t("notch.commandCenter.wifi"); theme: root.theme; enabled: root.net.loaded && root.net.available; checked: root.net.wifiEnabled; onToggled: root._setWifi(!root.net.wifiEnabled) }
			}
		}

		Item {
			visible: root.net.loaded && root.net.wifiEnabled
			width: parent.width
			height: 38
			SGroupLabel { y: 0; theme: root.theme; text: I18n.t("linux.settings.networksCount", { count: root.net.networks.length }) }
			SChip {
				objectName: "scan"
				x: parent.width - width - Tokens.settings.row.paddingH
				y: 6
				theme: root.theme; accent: root.accent; icon: "refresh-cw"
				text: root.net.scanning ? I18n.t("linux.settings.scanning") : I18n.t("linux.settings.scan")
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
							bottomPadding: 18
							spacing: 10

							Message {
								visible: network.enterprise
								bottomPadding: 0
								text: I18n.t("linux.settings.thisNetworkNeedsASignInThatNetwork")
							}
							Row {
								x: Tokens.settings.row.inset
								spacing: 8
								SField {
									objectName: "password:" + network.modelData.ssid
									visible: network.needsPassword || (network.error !== null && network.error.code === "wrong-password")
									width: 220
									theme: root.theme
									secret: true
									placeholder: I18n.t("ui.wifiPanel.password")
									text: root._password
									onTextChanged: root._password = text
									onAccepted: root._connect(network.modelData.ssid)
								}
								SChip {
									objectName: "netConnect:" + network.modelData.ssid
									visible: !network.modelData.connected && !network.enterprise
									theme: root.theme; accent: root.accent; active: true; text: I18n.t("ui.bluetoothPanel.connect")
									onClicked: root._connect(network.modelData.ssid)
								}
								SChip {
									objectName: "netDisconnect:" + network.modelData.ssid
									visible: network.modelData.connected
									theme: root.theme; accent: root.accent; text: I18n.t("ui.bluetoothPanel.disconnect")
									onClicked: root.net.disconnect(network.modelData.ssid)
								}
								SChip {
									objectName: "netForget:" + network.modelData.ssid
									visible: network.modelData.saved
									theme: root.theme; accent: root.accent; text: I18n.t("ui.wifiPanel.forget")
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

		SGroupLabel { theme: root.theme; text: I18n.t("linux.settings.vpn") }
		Text {
			objectName: "noVpn"
			visible: !root.sys || root.sys.vpns.length === 0
			leftPadding: Tokens.settings.group.label.h
			text: I18n.t("linux.settings.noVpnsAreSetUpAddOneWith")
			color: root.theme.textMuted
			font.family: Fonts.ui
			font.pixelSize: Fonts.px(14)
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
					theme: root.theme; icon: "lock"; label: vpnRow.modelData.name; desc: vpnRow.modelData.active === "yes" ? I18n.t("agentIntegrations.connected") : I18n.t("notch.commandCenter.notConnected")
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
				theme: root.theme; icon: "bluetooth"; label: I18n.t("notch.commandCenter.bluetooth"); divider: false
				desc: !root.bt.loaded ? I18n.t("linux.settings.checking") : root.bt.error ? I18n.t("linux.settings.couldnTReadBluetooth") : !root.bt.available ? I18n.t("linux.settings.noBluetoothAdapterFound") : root.bt.powered ? I18n.t("notch.commandCenter.on") : I18n.t("notch.commandCenter.off")
				SToggle { objectName: "bluetooth"; accessibleName: I18n.t("notch.commandCenter.bluetooth"); theme: root.theme; enabled: root.bt.loaded && root.bt.available; checked: root.bt.powered; onToggled: root._setBt(!root.bt.powered) }
			}
		}

		SGroupLabel { visible: root.bt.powered && root.bt.paired.length > 0; theme: root.theme; text: I18n.t("linux.settings.myDevices") }
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
						desc: root.bt.busy === device.modelData.path ? I18n.t("linux.settings.working") : device.modelData.connected ? I18n.t("agentIntegrations.connected") : I18n.t("notch.commandCenter.notConnected")
						divider: !device.open && device.index < root.bt.paired.length - 1
						onClicked: root._openDevice = device.open ? "" : device.modelData.path
					}
					Row {
						visible: device.open
						x: Tokens.settings.row.inset
						bottomPadding: 14
						spacing: 8
						SChip {
							objectName: "deviceConnect:" + device.modelData.name
							theme: root.theme; accent: root.accent; active: !device.modelData.connected
							text: device.modelData.connected ? I18n.t("ui.bluetoothPanel.disconnect") : I18n.t("ui.bluetoothPanel.connect")
							onClicked: root.bt.setConnected(device.modelData.path, !device.modelData.connected)
						}
						SChip {
							objectName: "deviceRemove:" + device.modelData.name
							theme: root.theme; accent: root.accent; text: I18n.t("common.remove")
							onClicked: {
								root.bt.unpair(device.modelData.path);
								root._openDevice = "";
							}
						}
					}
				}
			}
		}

		SGroupLabel { visible: root.bt.powered; theme: root.theme; text: I18n.t("linux.settings.addADevice") }
		SGroup {
			visible: root.bt.powered
			theme: root.theme
			SRow {
				objectName: "discover"
				theme: root.theme; icon: "plus"; action: true; divider: root.bt.nearby.length > 0
				label: root.bt.discovering ? I18n.t("linux.settings.stopLooking") : I18n.t("linux.settings.lookForDevices")
				desc: root.bt.discovering ? I18n.t("linux.settings.putYourDeviceInPairingMode") : I18n.t("linux.settings.findDevicesNearby")
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
						desc: candidate.pairing ? I18n.t("ui.bluetoothPanel.pairing") : I18n.t("linux.settings.tapToPair")
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
								if (p.kind === "provide") return I18n.t("linux.settings.enterThePinShownOnTheDevice");
								if (p.kind === "confirm") return I18n.t("linux.notch.confirmPairingPin", { pin: p.pin });
								return I18n.t("linux.notch.typePairingPin", { pin: p.pin });
							}
						}
						SField {
							objectName: "pin"
							visible: !!candidate.prompt && candidate.prompt.kind === "provide"
							x: Tokens.settings.row.inset
							theme: root.theme
							placeholder: I18n.t("linux.settings.pin")
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
								text: candidate.prompt && candidate.prompt.kind === "confirm" ? I18n.t("linux.settings.yesPair") : I18n.t("ui.bluetoothPanel.pair")
								onClicked: {
									root.bt.respond(true, root._pin);
									root._pin = "";
								}
							}
							SChip {
								objectName: "pairNo"
								theme: root.theme; accent: root.accent; text: I18n.t("common.cancel")
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
			topPadding: 10
			leftPadding: Tokens.settings.group.label.h
			text: I18n.t("linux.settings.bluetoothCouldnTFinishThatTryAgain")
			color: "#ff8a80"
			font.family: Fonts.ui
			font.pixelSize: Fonts.px(14)
		}
	}
}
