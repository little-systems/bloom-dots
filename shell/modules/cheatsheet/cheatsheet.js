// The keybind cheatsheet (spec §3.4): `hyprctl binds -j` as groups of keys and
// what they do, from each bind's "Group: text" description. Pure.
var MODIFIERS = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]];
var NAMES = {
	"mouse:272": "Left click", "mouse:273": "Right click", "mouse:274": "Middle click",
	"mouse_down": "Scroll down", "mouse_up": "Scroll up",
	"slash": "/", "backslash": "\\", "comma": ",", "period": ".", "semicolon": ";", "apostrophe": "'",
	"minus": "-", "equal": "=", "bracketleft": "[", "bracketright": "]", "grave": "`",
	"space": "Space", "tab": "Tab", "SUPER_L": "Super", "SUPER_R": "Super"
};

function keyName(key) {
	return NAMES[key] ?? (key.length === 1 ? key.toUpperCase() : key);
}

function keys(bind) {
	const held = MODIFIERS.filter(([bit]) => bind.modmask & bit).map(([, name]) => name);
	return held.concat([keyName(bind.key)]);
}

function parse(bindsJson) {
	let binds;
	try {
		binds = JSON.parse(bindsJson);
	} catch (e) {
		return [];
	}
	if (!Array.isArray(binds)) return [];
	const groups = [];
	const seen = {};
	binds.forEach(bind => {
		if (!bind.description || seen[bind.description]) return;
		seen[bind.description] = true;
		const colon = bind.description.indexOf(": ");
		const name = colon > 0 ? bind.description.slice(0, colon) : "Other";
		const text = colon > 0 ? bind.description.slice(colon + 2) : bind.description;
		let group = groups.find(g => g.name === name);
		if (!group) {
			group = { name: name, binds: [] };
			groups.push(group);
		}
		group.binds.push({ keys: keys(bind), text: text });
	});
	// "Other" reads last, wherever its first bind happened to be.
	return groups.filter(g => g.name !== "Other").concat(groups.filter(g => g.name === "Other"));
}

// Each group goes to the shortest column so far, in order, so the sheet stays
// even and groups never split.
function columns(groups, count) {
	const result = [];
	const heights = [];
	for (let i = 0; i < count; i++) {
		result.push([]);
		heights.push(0);
	}
	groups.forEach(group => {
		const shortest = heights.indexOf(Math.min(...heights));
		result[shortest].push(group);
		heights[shortest] += group.binds.length + 2;
	});
	return result;
}
