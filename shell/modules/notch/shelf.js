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

function clean(raw) {
	if (!Array.isArray(raw)) return [];
	return raw.filter(item => item && (item.kind === "text" || item.kind === "file")
		&& typeof item.value === "string" && item.value.length > 0 && item.value.length <= 4096
		&& (item.kind !== "file" || item.value.startsWith("/") && !item.value.includes("\0")))
		.slice(0, 10);
}

function add(items, kind, value) {
	if ((kind !== "text" && kind !== "file") || typeof value !== "string" || !value || value.length > 4096) return items;
	if (kind === "file" && (!value.startsWith("/") || value.includes("\0"))) return items;
	return clean([{ kind, value }].concat(items)).slice(0, 10);
}
