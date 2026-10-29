// Name-based counterpart of Bloom's Windows deviceArtFor/usbArtFor. BlueZ and
// PipeWire do not report the same kind/form fields as the Windows backend.
function artFor(name, kind) {
	const n = (name || "").toLowerCase();
	if (kind === "usb") {
		if (/\b(ssd|nvme|portable ssd)\b/.test(n)) return "ssd";
		if (/\b(sd|sdhc|sdxc|micro ?sd|card reader)\b/.test(n)) return "sd-card";
		if (/\b(camera|webcam)\b/.test(n)) return "webcam";
		return "flash-drive";
	}
	if (/\bair ?pods max\b/.test(n)) return "headphones";
	if (/\b(air ?pods|ear ?pods|freebuds|stem)\b/.test(n)) return "stem-buds";
	if (/\b(neck ?band|bullets wireless|buds wireless|rockerz ?[1-3]\d\d)\b/.test(n)) return "neckband";
	if (/\b(buds?|pods|earbuds?|earphones?|tws|in-?ear)\b/.test(n)) return "round-buds";
	if (/\b(speaker|soundlink|soundcore|sound ?bar|home ?pod|wonderboom)\b/.test(n)) return "speaker";
	if (/\b(phone|iphone|pixel|galaxy)\b/.test(n)) return "phone";
	if (/\b(mouse)\b/.test(n)) return "mouse";
	if (/\b(keyboard)\b/.test(n)) return "keyboard";
	if (/\b(controller|gamepad)\b/.test(n)) return "controller";
	if (/\b(watch)\b/.test(n)) return "watch";
	if (kind === "audio" || /\b(headphones?|headset)\b/.test(n)) return "headphones";
	return "device";
}

// Bloom's deviceArtFor: the drawing for a Bluetooth device by its kind, by
// name for audio.
function artForKind(kind, name) {
	switch (kind) {
	case "audio": return artFor(name, "audio");
	case "phone": return "phone";
	case "gamepad": return "controller";
	case "mouse": return "mouse";
	case "keyboard": return "keyboard";
	case "wearable": return "watch";
	default: return "device";
	}
}

// The looks a user can pick for an audio device (deviceLooks.ts).
var DEVICE_LOOKS = [
	{ art: "headphones", label: "Headphones" },
	{ art: "round-buds", label: "Earbuds" },
	{ art: "stem-buds", label: "Stem buds" },
	{ art: "neckband", label: "Neckband" },
	{ art: "speaker", label: "Speaker" }
];
var WIRED_DEVICE_LOOKS = [
	{ art: "headphones-wired", label: "Headphones" },
	{ art: "earbuds-usbc", label: "Earbuds (USB-C)" },
	{ art: "earbuds-jack", label: "Earbuds (3.5 mm)" },
	{ art: "speaker", label: "Speaker" },
	{ art: "microphone", label: "Microphone" }
];
