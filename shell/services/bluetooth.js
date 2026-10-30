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

// One line of bluetoothctl, which pairs as the agent: a prompt to show
// (Bloom's confirm / display / provide), consent to give (the person already
// chose to pair), or the pairing's result as Bloom's error codes.
function agentLine(raw) {
	const line = (raw || "").replace(/\u001b\[[0-9;]*[A-Za-z]/g, "").replace(/^\s*\[[^\]]*\][#>]?\s*/, m => /agent/.test(m) ? m : "").trim();
	let m;
	if ((m = /Confirm passkey (\d+)/.exec(line))) return { prompt: "confirm", pin: m[1] };
	if ((m = /\[agent\] (?:Passkey|PIN code): (\S+)/.exec(line))) return { prompt: "display", pin: m[1] };
	if (/Enter (?:PIN code|passkey)/.test(line)) return { prompt: "provide", pin: null };
	if (/Accept pairing|Authorize service/.test(line)) return { answer: "yes" };
	if (/Pairing successful/.test(line)) return { result: "ok" };
	if (/Device [0-9A-F:]+ not available/i.test(line)) return { result: "not-found" };
	if ((m = /Failed to pair: org\.bluez\.Error\.(\w+)/.exec(line))) {
		const code = m[1];
		if (code === "AlreadyExists") return { result: "ok" };
		if (code === "AuthenticationTimeout") return { result: "timeout" };
		if (/^Authentication(Canceled|Rejected|Failed)$|InProgress/.test(code)) return { result: "cancelled" };
		if (code === "NotReady") return { result: "not-ready" };
		return { result: "failed" };
	}
	return null;
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
