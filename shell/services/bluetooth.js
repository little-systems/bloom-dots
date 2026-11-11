function property(object, name, fallback) {
	return object?.[name]?.data ?? fallback;
}

function batteryLabel(battery, buds) {
	const sides = ["left", "right"].filter(side => Number.isInteger(buds?.[side]));
	if (sides.length) return sides.map(side => side[0].toUpperCase() + " " + buds[side] + "%").join("  ");
	return Number.isInteger(battery) ? battery + "%" : "";
}

// Bloom's device kinds from BlueZ's Icon property.
function bluetoothKind(icon) {
	const i = icon || "";
	if (/^audio-/.test(i)) return "audio";
	if (i === "phone") return "phone";
	if (i === "computer") return "computer";
	if (i === "input-keyboard") return "keyboard";
	if (i === "input-mouse" || i === "input-tablet") return "mouse";
	if (i === "input-gaming") return "gamepad";
	return "other";
}

function managed(text) {
	let paths;
	try { paths = JSON.parse(text).data?.[0]; } catch (e) { return { available: false, powered: false, adapter: "", devices: [], discovering: false }; }
	if (!paths || typeof paths !== "object") return { available: false, powered: false, adapter: "", devices: [], discovering: false };
	const adapters = Object.entries(paths).filter(([, interfaces]) => interfaces["org.bluez.Adapter1"]);
	const adapter = adapters[0]?.[0] ?? "";
	const powered = property(adapters[0]?.[1]?.["org.bluez.Adapter1"], "Powered", false) === true;
	const discovering = property(adapters[0]?.[1]?.["org.bluez.Adapter1"], "Discovering", false) === true;
	const devices = Object.entries(paths).filter(([, interfaces]) => interfaces["org.bluez.Device1"])
		.map(([path, interfaces]) => {
			const d = interfaces["org.bluez.Device1"];
			const battery = property(interfaces["org.bluez.Battery1"], "Percentage", null);
			const buds = {};
			for (const [childPath, childInterfaces] of Object.entries(paths)) {
				if (!childPath.startsWith(path + "/")) continue;
				const part = childPath.slice(path.length + 1);
				const side = /(^|[_/-])(left|right)([_/-]|$)/i.exec(part)?.[2]?.toLowerCase();
				const percentage = property(childInterfaces["org.bluez.Battery1"], "Percentage", null);
				if (side && Number.isInteger(percentage) && percentage >= 0 && percentage <= 100) buds[side] = percentage;
			}
			return { path, name: property(d, "Alias", property(d, "Name", "Bluetooth device")),
				address: property(d, "Address", ""), connected: property(d, "Connected", false) === true,
				// BlueZ aliases an unnamed device by its address; only a Name is real.
				named: typeof property(d, "Name", null) === "string",
				paired: property(d, "Paired", false) === true,
				kind: bluetoothKind(property(d, "Icon", "")),
				battery: Number.isInteger(battery) ? battery : null, buds,
				batteryLabel: batteryLabel(battery, buds) };
		}).sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name));
	return { available: adapter !== "", powered, adapter, devices, discovering };
}

// Bloom's panel lists: paired devices (connected first, then by name, as
// managed() sorts them), and nearby ones to pair: unpaired, named, by name.
function paired(devices) {
	return (devices || []).filter(d => d.paired);
}
function nearby(devices) {
	return (devices || []).filter(d => !d.paired && d.named)
		.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
}

// One line from scripts/bluetooth-agent.py, the pairing agent: a prompt
// to show (Bloom's confirm / display / provide), the pairing's result as
// Bloom's codes, or that it is ready.
function agentEvent(line) {
	let e;
	try { e = JSON.parse(line); } catch (err) { return null; }
	if (!e || typeof e !== "object") return null;
	if (e.event === "ready") return { ready: true };
	if (e.event === "paired") return { result: "ok" };
	if (e.event === "failed") return { result: pairError(e.error) };
	if (e.event === "prompt" && ["confirm", "display", "provide"].includes(e.kind))
		return { prompt: e.kind, pin: typeof e.pin === "string" ? e.pin : null };
	return null;
}

// BlueZ's errors as Bloom's codes (bluetooth.rs pairing_error).
function pairError(name) {
	const n = String(name || "");
	if (/AlreadyExists$/.test(n)) return "ok";
	if (/AuthenticationTimeout$|NoReply$|Timeout$/.test(n)) return "timeout";
	if (/Authentication(Canceled|Rejected|Failed)$|InProgress$/.test(n)) return "cancelled";
	if (/NotReady$/.test(n)) return "not-ready";
	if (/UnknownObject$|DoesNotExist$/.test(n)) return "not-found";
	return "failed";
}

// Bloom's BluetoothPanel ERROR_TEXT.
var ERROR_TEXT = {
	"not-found": "Refresh and try again",
	timeout: "The device didn't answer in time",
	cancelled: "Pairing was cancelled",
	failed: "Couldn't pair with this device",
	"not-ready": "Put the device in pairing mode first"
};
function errorText(code) {
	return ERROR_TEXT[code] ?? String(code);
}

// Why a BlueZ query failed: the service is absent (bluetoothd stopped or not
// installed, or no system bus) versus a transient failure. A missing adapter
// is not a failure: the query succeeds with no Adapter1.
function failure(code, stderr) {
	const text = String(stderr || "");
	if (code === 127 || /ServiceUnknown|was not provided by any|not activatable|Failed to connect to bus/i.test(text))
		return { state: "missing", reason: "bluetoothd is not running", message: "Bluetooth service isn't running" };
	if (code === 124)
		return { state: "degraded", reason: "query timed out", message: "Bluetooth isn't responding" };
	return { state: "degraded", reason: "query failed", message: "Bluetooth query failed" };
}
