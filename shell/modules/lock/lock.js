.pragma library

var DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

function failureText(outcome) {
	if (outcome === "maxtries") return "Too many tries. Wait a moment, then try again";
	if (outcome === "error") return "Couldn't check the password";
	return "That password didn't work";
}

function clock(time, use24) {
	const minutes = String(time.getMinutes()).padStart(2, "0");
	const hours = time.getHours();
	return (use24 ? String(hours).padStart(2, "0") : String(hours % 12 || 12)) + ":" + minutes;
}

function date(time) {
	return DAYS[time.getDay()] + ", " + MONTHS[time.getMonth()] + " " + time.getDate();
}

// `hyprctl devices -j`: the main keyboard's state, or the only keyboard's.
function capsLock(devicesJson) {
	try {
		const keyboards = JSON.parse(devicesJson).keyboards || [];
		const keyboard = keyboards.find(k => k.main) || keyboards[0];
		return !!keyboard && keyboard.capsLock === true;
	} catch (e) {
		return false;
	}
}
