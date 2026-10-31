// The on-screen keyboard's layout and what a press sends. Pure. Each key is
// { id, label, shift?, width?, key?, modifier? }; `key` is a wtype key name.
var ROWS = [
	"`1234567890-=", "qwertyuiop[]\\", "asdfghjkl;'", "zxcvbnm,./"
];
var SHIFTED = { "`": "~", "1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&", "8": "*", "9": "(", "0": ")", "-": "_", "=": "+", "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?" };

function _chars(row) {
	return row.split("").map(c => ({ id: c, label: c, shift: SHIFTED[c] ?? c.toUpperCase() }));
}

function rows() {
	return [
		_chars(ROWS[0]).concat([{ id: "Backspace", label: "⌫", key: "BackSpace", width: 1.6 }]),
		[{ id: "Tab", label: "Tab", key: "Tab", width: 1.4 }].concat(_chars(ROWS[1])),
		[{ id: "ctrl", label: "Ctrl", modifier: "ctrl", width: 1.6 }].concat(_chars(ROWS[2])).concat([{ id: "Return", label: "Enter", key: "Return", width: 1.8 }]),
		[{ id: "shift", label: "Shift", modifier: "shift", width: 2 }].concat(_chars(ROWS[3])).concat([{ id: "Up", label: "↑", key: "Up" }, { id: "alt", label: "Alt", modifier: "alt", width: 1.2 }]),
		[{ id: "Escape", label: "Esc", key: "Escape", width: 1.4 }, { id: "logo", label: "Super", modifier: "logo", width: 1.4 }, { id: "space", label: "", key: "space", width: 6 }, { id: "Left", label: "←", key: "Left" }, { id: "Down", label: "↓", key: "Down" }, { id: "Right", label: "→", key: "Right" }]
	];
}

// The wtype arguments for a key with these modifiers held.
function _flags(flag, modifiers) {
	return modifiers.reduce((all, m) => all.concat([flag, m]), []);
}

function command(key, held) {
	const on = _flags("-M", held);
	const off = _flags("-m", held.slice().reverse());
	if (key.key) return ["wtype"].concat(on, ["-k", key.key], off);
	const shift = held.indexOf("shift") >= 0;
	const others = held.filter(m => m !== "shift");
	const text = shift ? key.shift : key.label;
	if (others.length === 0) return ["wtype", "--", text];
	return ["wtype"].concat(_flags("-M", others), ["-k", key.label], _flags("-m", others.slice().reverse()));
}
