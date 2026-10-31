import QtQuick
import QtTest
import "../../shell/services/network.js" as Network
import "../../shell/services/bluetooth.js" as Bluetooth

TestCase {
	name: "ConnectivityRules"
	function test_nmcliEscapesAndDeduplicates() {
		compare(Network.fields("*:Cafe\\:North:75:WPA2"), ["*", "Cafe:North", "75", "WPA2"]);
		compare(Network.status("enabled:connected\n"), { wifiEnabled: true, connected: true });
		compare(Network.wifiList(" :Cafe\\:North:40:WPA2\n*:Cafe\\:North:75:WPA2\n :Open:50:--\n", []), [
			{ ssid: "Cafe:North", signal: 75, security: "wpa2", connected: true, saved: false },
			{ ssid: "Open", signal: 50, security: "open", connected: false, saved: false }
		]);
	}

	// Bloom's labels (wifi.rs security_label) from nmcli's SECURITY field.
	function test_securityLabels() {
		compare(Network.security(""), "open");
		compare(Network.security("--"), "open");
		compare(Network.security("WEP"), "wep");
		compare(Network.security("WPA1"), "wpa");
		compare(Network.security("WPA1 WPA2"), "wpa2");
		compare(Network.security("WPA2 WPA3"), "wpa3");
		compare(Network.security("WPA3"), "wpa3");
		compare(Network.security("OWE"), "owe");
		compare(Network.security("WPA2 802.1X"), "enterprise");
		compare(Network.security("WPA3 802.1X"), "enterprise");
	}

	// Saved networks are NetworkManager's Wi-Fi connection profiles.
	function test_savedProfiles() {
		compare(Network.savedNames("Home:802-11-wireless\nWired connection 1:802-3-ethernet\nCafe\\:North:802-11-wireless\n"), ["Home", "Cafe:North"]);
		const list = Network.wifiList(" :Home:30:WPA2\n :Strong:90:WPA2\n*:Here:20:--\n :Cafe:60:WPA2\n", ["Home", "Cafe"]);
		// Bloom's order: connected, then saved, then strongest, then name.
		compare(list.map(n => n.ssid), ["Here", "Cafe", "Home", "Strong"]);
		compare(list[1].saved, true);
		compare(list[3].saved, false);
	}

	// Bloom's error codes from what nmcli says.
	function test_connectErrors() {
		compare(Network.connectError("Error: Connection activation failed: Secrets were required, but not provided.", 4, true), "wrong-password");
		compare(Network.connectError("Error: Connection activation failed: Secrets were required, but not provided.", 4, false), "password-required");
		compare(Network.connectError("Error: No network with SSID 'Cafe' found.", 10, false), "not-found");
		compare(Network.connectError("", 124, false), "timeout");
		compare(Network.connectError("Error: No Wi-Fi device found.", 10, false), "no-adapter");
		compare(Network.connectError("Error: something else", 1, false), "failed");
	}

	function test_passwordNeverAppearsInNmcliArguments() {
		const command = Network.connectCommand("Cafe:North", "correct horse battery staple");
		verify(command.includes("--ask"));
		verify(!command.includes("correct horse battery staple"));
		compare(command[command.length - 1], "Cafe:North");
	}
	function test_bluezSnapshotAndOptionalBattery() {
		const data = { type: "a{oa{sa{sv}}}", data: [{
			"/org/bluez/hci0": { "org.bluez.Adapter1": { Powered: { data: true } } },
			"/org/bluez/hci0/dev_A": { "org.bluez.Device1": { Alias: { data: "Earbuds" }, Connected: { data: true }, Paired: { data: true } }, "org.bluez.Battery1": { Percentage: { data: 75 } } },
			"/org/bluez/hci0/dev_A/battery_left": { "org.bluez.Battery1": { Percentage: { data: 71 } } },
			"/org/bluez/hci0/dev_A/battery_right": { "org.bluez.Battery1": { Percentage: { data: 73 } } },
			"/org/bluez/hci0/dev_B": { "org.bluez.Device1": { Name: { data: "Mouse" }, Connected: { data: false } } }
		}] };
		const got = Bluetooth.managed(JSON.stringify(data));
		compare(got.available, true);
		compare(got.adapter, "/org/bluez/hci0");
		compare(got.devices[0].name, "Earbuds");
		compare(got.devices[0].battery, 75);
		compare(got.devices[0].batteryLabel, "L 71%  R 73%");
		compare(got.devices[1].battery, null);
		compare(got.devices[1].batteryLabel, "");
		compare(Bluetooth.managed("garbage").available, false);
	}

	// Bloom's "Add a device" list: unpaired devices that have a name, by name.
	function test_nearbyDevices() {
		const data = { type: "a{oa{sa{sv}}}", data: [{
			"/org/bluez/hci0": { "org.bluez.Adapter1": { Powered: { data: true }, Discovering: { data: true } } },
			"/org/bluez/hci0/dev_A": { "org.bluez.Device1": { Name: { data: "zeta Speaker" }, Alias: { data: "zeta Speaker" }, Paired: { data: false }, Icon: { data: "audio-card" } } },
			"/org/bluez/hci0/dev_B": { "org.bluez.Device1": { Alias: { data: "11-22-33-44-55-66" }, Paired: { data: false } } },
			"/org/bluez/hci0/dev_C": { "org.bluez.Device1": { Name: { data: "Alpha Phone" }, Paired: { data: false }, Icon: { data: "phone" } } },
			"/org/bluez/hci0/dev_D": { "org.bluez.Device1": { Name: { data: "Mine" }, Paired: { data: true } } }
		}] };
		const got = Bluetooth.managed(JSON.stringify(data));
		compare(got.discovering, true);
		compare(Bluetooth.nearby(got.devices).map(d => [d.name, d.kind]), [["Alpha Phone", "phone"], ["zeta Speaker", "audio"]]);
		compare(Bluetooth.paired(got.devices).map(d => d.name), ["Mine"]);
	}

	// scripts/bluetooth-agent.py, the pairing agent: one JSON event a line.
	function test_agentEvents() {
		compare(Bluetooth.agentEvent('{"event":"prompt","kind":"confirm","pin":"123456"}'), { prompt: "confirm", pin: "123456" });
		compare(Bluetooth.agentEvent('{"event":"prompt","kind":"display","pin":"004521"}'), { prompt: "display", pin: "004521" });
		compare(Bluetooth.agentEvent('{"event":"prompt","kind":"provide"}'), { prompt: "provide", pin: null });
		compare(Bluetooth.agentEvent('{"event":"paired"}'), { result: "ok" });
		compare(Bluetooth.agentEvent('{"event":"failed","error":"org.bluez.Error.AuthenticationTimeout"}'), { result: "timeout" });
		compare(Bluetooth.agentEvent('{"event":"ready"}'), { ready: true });
		compare(Bluetooth.agentEvent("not json"), null);
		compare(Bluetooth.agentEvent('{"event":"prompt","kind":"bogus"}'), null);
	}

	// BlueZ's errors as Bloom's codes (bluetooth.rs pairing_error).
	function test_pairErrors() {
		compare(Bluetooth.pairError("org.bluez.Error.AuthenticationTimeout"), "timeout");
		compare(Bluetooth.pairError("org.bluez.Error.AuthenticationCanceled"), "cancelled");
		compare(Bluetooth.pairError("org.bluez.Error.AuthenticationRejected"), "cancelled");
		compare(Bluetooth.pairError("org.bluez.Error.AuthenticationFailed"), "cancelled");
		compare(Bluetooth.pairError("org.bluez.Error.InProgress"), "cancelled");
		compare(Bluetooth.pairError("org.bluez.Error.AlreadyExists"), "ok");
		compare(Bluetooth.pairError("org.bluez.Error.NotReady"), "not-ready");
		compare(Bluetooth.pairError("org.freedesktop.DBus.Error.UnknownObject"), "not-found");
		compare(Bluetooth.pairError("org.freedesktop.DBus.Error.NoReply"), "timeout");
		compare(Bluetooth.pairError("org.bluez.Error.ConnectionAttemptFailed"), "failed");
	}

	// Bloom's error text (BluetoothPanel.tsx ERROR_TEXT).
	function test_bluetoothErrorText() {
		compare(Bluetooth.errorText("timeout"), "The device didn't answer in time");
		compare(Bluetooth.errorText("not-ready"), "Put the device in pairing mode first");
		compare(Bluetooth.errorText("weird"), "weird");
	}
}
