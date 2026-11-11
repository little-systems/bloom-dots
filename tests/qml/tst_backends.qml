import QtQuick
import QtTest
import "../../shell/services/bluetooth.js" as Bluetooth
import "../../shell/services/network.js" as Network
import "../../shell/services/capability.js" as Capability

// A backend that is absent, stopped or failing is told apart from a device
// that is simply missing, so the UI can say what is wrong.
TestCase {
	name: "Backends"

	function test_backoffIsBoundedAndGrows() {
		compare(Capability.backoffMs(1, 1000, 60000), 1000);
		compare(Capability.backoffMs(3, 1000, 60000), 4000);
		compare(Capability.backoffMs(40, 1000, 60000), 60000);
		compare(Capability.worst(["available", "degraded", "stopped"]), "degraded");
		compare(Capability.worst([]), "stopped");
	}

	function test_bluetoothServiceMissingIsNotNoAdapter() {
		const gone = Bluetooth.failure(1, "Call failed: The name org.bluez was not provided by any .service files");
		compare(gone.state, "missing");
		verify(gone.message.indexOf("service") >= 0);
		compare(Bluetooth.failure(1, "Failed to connect to bus: No such file or directory").state, "missing");
		compare(Bluetooth.failure(124, "").state, "degraded");
		compare(Bluetooth.failure(127, "").state, "missing");
	}

	function test_networkManagerStoppedIsNotNoWifi() {
		const stopped = Network.failure(8, "Error: NetworkManager is not running.");
		compare(stopped.state, "missing");
		verify(stopped.message.indexOf("NetworkManager") >= 0);
		compare(Network.failure(127, "").state, "missing");
		compare(Network.failure(124, "").state, "degraded");
		compare(Network.failure(1, "Error: something odd").state, "degraded");
	}
}
