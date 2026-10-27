// Pure rules for Linux dock extras. Process execution stays in DockExtras.qml.

var FOLDERS = ["desktop", "downloads", "documents", "pictures", "music", "videos"];

function jsonArray(raw) {
	try {
		const parsed = JSON.parse(raw || "[]");
		return Array.isArray(parsed) ? parsed : [];
	} catch (_) { return []; }
}

function parseDrives(raw, hiddenRaw) {
	let data;
	try { data = JSON.parse(raw); } catch (_) { return null; }
	if (!data || !Array.isArray(data.blockdevices)) return null;
	const hidden = jsonArray(hiddenRaw).filter(x => typeof x === "string");
	const filesystems = [];
	function collect(list, parentRemovable) {
		for (const d of list) {
			if (!d || typeof d !== "object") continue;
			const removable = parentRemovable || d.rm === true || d.rm === 1 || d.hotplug === true || d.hotplug === 1;
			if (d && typeof d.path === "string" && /^\/dev\/[A-Za-z0-9._/-]+$/.test(d.path)
				&& typeof d.fstype === "string" && d.fstype && d.fstype !== "swap"
				&& ["part", "disk", "crypt", "lvm"].indexOf(d.type) >= 0) {
				const mount = typeof d.mountpoint === "string" ? d.mountpoint : "";
				const userMounted = /^\/(run\/media|media|mnt)(\/|$)/.test(mount);
				const systemMounted = mount === "/" || /^\/(boot|efi|usr|var|home)(\/|$)/.test(mount);
				if (!systemMounted && (removable || userMounted))
					filesystems.push({ device: d.path, uuid: typeof d.uuid === "string" ? d.uuid : "",
						name: typeof d.label === "string" && d.label ? d.label : d.path.slice(5),
						path: mount, mounted: !!mount, removable: removable });
			}
			if (Array.isArray(d.children)) collect(d.children, removable);
		}
	}
	collect(data.blockdevices, false);
	const counts = {};
	for (const d of filesystems) if (d.uuid) counts[d.uuid] = (counts[d.uuid] || 0) + 1;
	return filesystems.filter(d => hidden.indexOf(d.uuid || "path:" + d.device) < 0).map(d => {
		const id = d.uuid ? d.uuid + (counts[d.uuid] > 1 ? "@" + d.device : "") : "path:" + d.device;
		return Object.assign({ key: "drive:" + id, kind: "drive", icon: "drive-harddisk" }, d);
	});
}

function driveAction(current, key, action) {
	const drive = (current || []).find(d => d.key === key);
	if (!drive || !/^\/dev\/[A-Za-z0-9._/-]+$/.test(drive.device)) return null;
	if (action === "open") return drive.mounted && drive.path ? ["gio", "open", drive.path] : ["udisksctl", "mount", "-b", drive.device];
	if (action === "eject" && drive.removable) return ["udisksctl", drive.mounted ? "unmount" : "power-off", "-b", drive.device];
	return null;
}

function folderEntries(enabledRaw, customRaw, dirs, home, exists) {
	const enabled = (enabledRaw || "").split(",").map(s => s.trim().toLowerCase());
	const out = [];
	for (const id of FOLDERS) {
		if (enabled.indexOf(id) < 0) continue;
		let path = dirs[id] || "";
		if (path === home) path = id === "downloads" ? home + "/Downloads" : "";
		if (!path || !path.startsWith("/") || !exists(path)) continue;
		out.push({ key: "folder:" + id, kind: "folder", name: id[0].toUpperCase() + id.slice(1), path: path, icon: "folder" });
	}
	for (const f of jsonArray(customRaw)) {
		if (!f || typeof f.name !== "string" || typeof f.path !== "string" || !f.path.startsWith("/")
			|| f.path.indexOf("\0") >= 0 || f.name.length > 100 || !exists(f.path)
			|| out.some(x => x.path === f.path)) continue;
		out.push({ key: "custom:" + f.path, kind: "custom", name: f.name || f.path.split("/").pop(), path: f.path, icon: "folder" });
	}
	return out;
}

function trashCount(text) {
	const m = /^\s*trash::item-count:\s*(\d+)\s*$/m.exec(text || "");
	return m ? Number(m[1]) : null;
}
