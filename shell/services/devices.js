function audioDevices(nodes) {
	return (nodes || []).filter(n => n && !n.isStream && n.properties && /^Audio\/(Sink|Source)$/.test(n.properties["media.class"] || ""))
		.map(n => ({ id: n.id, name: n.description || n.nickname || n.name || "Audio device", kind: n.properties["media.class"] === "Audio/Source" ? "input" : "output" }));
}

function privacy(nodes) {
	const streams = (nodes || []).filter(n => n && n.isStream && n.properties);
	return {
		microphone: streams.some(n => n.properties["media.class"] === "Stream/Input/Audio" || n.properties["media.class"] === "Audio/Source"),
		screen: streams.some(n => {
			const props = n.properties;
			return /Video\/(Source|Capture)|Stream\/(Input|Output)\/Video/.test(props["media.class"] || "")
				&& (/portal|screencast|screen/i.test([props["node.name"], props["application.name"], props["media.name"]].join(" ")));
		})
	};
}

function udevEvent(lines) {
	const props = {};
	for (const line of lines || []) {
		const at = line.indexOf("=");
		if (at > 0) props[line.slice(0, at)] = line.slice(at + 1);
	}
	if (props.ACTION !== "add" || props.DEVTYPE !== "usb_device") return null;
	const name = (props.ID_MODEL_FROM_DATABASE || props.ID_MODEL || props.PRODUCT || "USB device").replace(/_/g, " ").slice(0, 90);
	return { kind: "usb", title: "Device connected", detail: name };
}
