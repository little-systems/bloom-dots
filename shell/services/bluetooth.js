function property(object, name, fallback) {
	return object?.[name]?.data ?? fallback;
}

function batteryLabel(battery, buds) {
	const sides = ["left", "right"].filter(side => Number.isInteger(buds?.[side]));
	if (sides.length) return sides.map(side => side[0].toUpperCase() + " " + buds[side] + "%").join("  ");
	return Number.isInteger(battery) ? battery + "%" : "";
}

function managed(text) {
	let paths;
	try { paths = JSON.parse(text).data?.[0]; } catch (e) { return { available: false, powered: false, adapter: "", devices: [] }; }
	if (!paths || typeof paths !== "object") return { available: false, powered: false, adapter: "", devices: [] };
	const adapters = Object.entries(paths).filter(([, interfaces]) => interfaces["org.bluez.Adapter1"]);
	const adapter = adapters[0]?.[0] ?? "";
	const powered = property(adapters[0]?.[1]?.["org.bluez.Adapter1"], "Powered", false) === true;
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
				paired: property(d, "Paired", false) === true,
				battery: Number.isInteger(battery) ? battery : null, buds,
				batteryLabel: batteryLabel(battery, buds) };
		}).sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name));
	return { available: adapter !== "", powered, adapter, devices };
}
