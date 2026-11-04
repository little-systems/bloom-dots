// The wallpaper (spec §3.4): what counts as one, the Adaptive accent from
// matugen's JSON, and moving around the picker's grid. Pure.
var PICTURES = /\.(jpe?g|png|webp|bmp|avif|svg|gif)$/i;
var VIDEOS = /\.(mp4|webm|mkv|mov|avi)$/i;

function isVideo(path) {
	return VIDEOS.test(path || "");
}

function parseList(text) {
	return Array.from(new Set(text.split(text.indexOf("\0") >= 0 ? "\0" : "\n").filter(p => PICTURES.test(p) || VIDEOS.test(p)))).sort((a, b) => a.localeCompare(b));
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

// `chance` is a number from 0 up to 1.
function pickOther(items, current, chance) {
	const others = items.filter(item => item !== current);
	return others.length ? others[Math.floor(chance * others.length)] : "";
}

function localPath(url) {
	const value = String(url || "");
	return value.indexOf("file://") === 0 ? decodeURIComponent(value.slice(7)) : value;
}
function fileUrl(path) { return "file://" + String(path).split("/").map(encodeURIComponent).join("/"); }
function search(items, query) {
	const words = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
	return items.filter(path => words.every(word => path.toLowerCase().includes(word)));
}

// Like the dock picker, use an installed desktop dialog; arguments remain
// positional so paths are never interpolated into shell code.
var pickerScript = 'if [ -n "$BLOOM_WALLPAPER_PICKER" ]; then exec "$BLOOM_WALLPAPER_PICKER" "$1" "$2"; fi; '
	+ 'if command -v kdialog >/dev/null 2>&1; then '
	+ 'if [ "$1" = folder ]; then exec kdialog --title "Wallpaper folder" --getexistingdirectory "$2"; '
	+ 'else exec kdialog --title "Choose a wallpaper" --getopenfilename "$2" "*.jpg *.jpeg *.png *.webp *.avif *.svg *.gif *.bmp *.mp4 *.webm *.mkv *.mov *.avi|Wallpapers"; fi; fi; '
	+ 'for z in zenity qarma; do if command -v "$z" >/dev/null 2>&1; then '
	+ 'if [ "$1" = folder ]; then exec "$z" --file-selection --directory --title="Wallpaper folder" --filename="$2/"; '
	+ 'else exec "$z" --file-selection --title="Choose a wallpaper" --filename="$2/"; fi; fi; done; exit 127';

function parentFolder(path) {
	const trimmed = String(path).replace(/\/+$/, "");
	return trimmed.slice(0, trimmed.lastIndexOf("/")) || "/";
}
