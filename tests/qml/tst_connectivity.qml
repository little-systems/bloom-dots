import QtQuick
import QtTest
import "../../shell/services/network.js" as Network
import "../../shell/services/bluetooth.js" as Bluetooth

TestCase {
	name: "ConnectivityRules"
	function test_nmcliEscapesAndDeduplicates() {
		compare(Network.fields("*:Cafe\\:North:75:WPA2"), ["*", "Cafe:North", "75", "WPA2"]);
		compare(Network.status("enabled:connected\n"), { wifiEnabled: true, connected: true });
		compare(Network.wifiList(" :Cafe\\:North:40:WPA2\n*:Cafe\\:North:75:WPA2\n :Open:50:--\n"), [
			{ ssid: "Cafe:North", signal: 75, secured: true, active: true },
			{ ssid: "Open", signal: 50, secured: false, active: false }
		]);
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
}
