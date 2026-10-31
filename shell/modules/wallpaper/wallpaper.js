// The wallpaper (spec §3.4): what counts as one, the Adaptive accent from
// matugen's JSON, and moving around the picker's grid. Pure.
var PICTURES = /\.(jpe?g|png|webp|bmp)$/i;
var VIDEOS = /\.(mp4|webm|mkv|mov|avi)$/i;

function isVideo(path) {
	return VIDEOS.test(path || "");
}

function parseList(text) {
	return text.split("\n").filter(p => PICTURES.test(p) || VIDEOS.test(p)).sort((a, b) => a.localeCompare(b));
}

function accentFrom(matugenJson) {
	try {
		const primary = JSON.parse(matugenJson).colors.primary;
		if (typeof primary === "string") return primary;
		return (primary.dark || primary.default).color || "";
	} catch (e) {
		return "";
	}
}

function move(index, direction, count, columns) {
	if (direction === "left") return Math.max(0, index - 1);
	if (direction === "right") return Math.min(count - 1, index + 1);
	if (direction === "up") return index - columns >= 0 ? index - columns : index;
	return Math.min(count - 1, index + columns);
}
