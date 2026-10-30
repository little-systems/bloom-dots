function filePath(value) {
	if (typeof value !== "string" || !value.startsWith("file:///")) return "";
	let path;
	try { path = decodeURIComponent(value.slice(7)); } catch (e) { return ""; }
	return path.startsWith("/") && !path.includes("\0") && !path.includes("\n") ? path : "";
}

function fileUrl(path) {
	if (typeof path !== "string" || !path.startsWith("/") || path.includes("\0")) return "";
	return "file://" + path.split("/").map(encodeURIComponent).join("/");
}

// Bloom's SHELF_MAX_ITEMS.
var MAX_ITEMS = 10;

function _valid(item) {
	return item && (item.kind === "text" || item.kind === "file")
		&& typeof item.value === "string" && item.value.length > 0 && item.value.length <= 4096
		&& (item.kind !== "file" || item.value.startsWith("/") && !item.value.includes("\0"));
}

// Saved items, checked; each keeps its id (old saves get one from newId).
function clean(raw, newId) {
	if (!Array.isArray(raw)) return [];
	return raw.filter(_valid).slice(0, MAX_ITEMS)
		.map(item => ({ kind: item.kind, value: item.value, id: typeof item.id === "string" && item.id ? item.id : newId() }));
}

// Bloom's addShelfItems: new paths go in front, skipping ones already on the
// shelf; a full shelf takes what fits, or nothing, and says so.
function addFiles(items, paths, newId) {
	const existing = new Set(items.filter(i => i.kind === "file").map(i => i.value));
	const fresh = [];
	for (const path of paths) {
		if (existing.has(path) || !_valid({ kind: "file", value: path })) continue;
		existing.add(path);
		fresh.push({ kind: "file", value: path, id: newId() });
	}
	return _take(items, fresh);
}

// Bloom's addShelfText: the same text goes on once.
function addText(items, text, newId) {
	if (!_valid({ kind: "text", value: text }) || items.some(i => i.kind === "text" && i.value === text))
		return { items, added: [], notice: "" };
	return _take(items, [{ kind: "text", value: text, id: newId() }]);
}

function _take(items, fresh) {
	if (fresh.length === 0) return { items, added: [], notice: "" };
	const room = Math.max(0, MAX_ITEMS - items.length);
	if (room === 0) return { items, added: [], notice: "Shelf is full (" + MAX_ITEMS + ") — remove an item first" };
	const added = fresh.slice(0, room);
	return { items: added.concat(items), added: added.map(i => i.id),
		notice: fresh.length > room ? "Shelf is full — added " + room + " of " + fresh.length + " items" : "" };
}

// Bloom's ShelfTypeIcon: lucide icons by file extension.
var _ICON_GROUPS = [
	["file-image", ["png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "tif", "tiff", "heic", "heif", "avif", "svg", "raw", "psd"]],
	["file-video-camera", ["mp4", "mkv", "mov", "avi", "webm", "wmv", "flv", "m4v", "mpg", "mpeg", "3gp"]],
	["file-music", ["mp3", "wav", "flac", "aac", "ogg", "oga", "m4a", "wma", "opus", "aiff", "mid", "midi"]],
	["file-spreadsheet", ["xls", "xlsx", "xlsm", "csv", "tsv", "ods", "numbers"]],
	["presentation", ["ppt", "pptx", "odp", "key"]],
	["file-text", ["pdf", "txt", "md", "rtf", "doc", "docx", "odt", "pages", "epub", "log"]],
	["file-archive", ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "zst", "cab"]],
	["file-code", ["js", "jsx", "ts", "tsx", "mjs", "cjs", "py", "rs", "c", "h", "cpp", "hpp", "cs", "java", "kt", "go", "rb", "php", "swift", "html", "htm", "css", "scss", "json", "xml", "yml", "yaml", "toml", "ini", "sh", "ps1", "bat", "cmd", "sql", "lua"]],
	["app-window", ["exe", "msi", "msix", "appx", "appinstaller", "lnk", "url"]],
	["disc", ["iso", "img", "vhd", "vhdx"]],
	["file-type", ["ttf", "otf", "woff", "woff2", "fon"]]
];

function _extension(path) {
	const name = String(path).split("/").pop();
	const dot = name.lastIndexOf(".");
	return dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
}

function typeIcon(path, folder) {
	if (folder) return "folder";
	const ext = _extension(path);
	for (const [icon, exts] of _ICON_GROUPS)
		if (exts.includes(ext)) return icon;
	return "file";
}

// A tile's caption (App.tsx .shelf-tile-name).
function tileName(item) {
	return item.kind === "text" ? "Text · " + item.value.length + " chars" : item.value.split("/").pop();
}

// Bloom's preview sources (shelf_preview.rs): these images are decoded into a
// thumbnail; these text files show their opening TEXT_PREVIEW_CHARS.
var _IMAGES = ["png", "jpg", "jpeg", "gif", "webp", "bmp", "ico", "tif", "tiff"];
var _TEXTS = ["txt", "md", "markdown", "log", "csv", "tsv", "json", "xml", "yml", "yaml", "toml", "ini",
	"cfg", "conf", "env", "js", "jsx", "ts", "tsx", "mjs", "cjs", "py", "rs", "c", "h", "cpp",
	"hpp", "cs", "java", "kt", "go", "rb", "php", "swift", "html", "htm", "css", "scss", "sh",
	"ps1", "bat", "cmd", "sql", "lua", "srt", "vtt"];
var TEXT_PREVIEW_CHARS = 400;

function isImage(path) { return _IMAGES.includes(_extension(path)); }
function isText(path) { return _TEXTS.includes(_extension(path)); }
function textPreview(text) { return String(text || "").slice(0, TEXT_PREVIEW_CHARS); }

// Where a file manager keeps a picture of the file (freedesktop thumbnail
// spec: the MD5 of its URI), Linux's stand-in for Windows' shell
// thumbnails: the large one, then the normal one.
function thumbnailCandidates(path, home) {
	const md5 = Qt.md5(fileUrl(path));
	return ["large", "normal"].map(size => "file://" + home + "/.cache/thumbnails/" + size + "/" + md5 + ".png");
}
