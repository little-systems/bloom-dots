.pragma library

// The first-run guide's state (~/.local/state/bloom/onboarding.json): a fresh
// install writes {"completed": false}; anything else, including no file at all
// (installed before the guide existed), never opens it unasked.
function pending(text) {
	try {
		return JSON.parse(text).completed === false;
	} catch (error) {
		return false;
	}
}

function serialize(completed) {
	return JSON.stringify({ completed: !!completed }).replace(":", ": ") + "\n";
}
