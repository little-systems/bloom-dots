pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/notch/shelf.js" as Logic

// The notch shelf (Bloom App.tsx shelf*): files and text, newest first, up to
// ten, with Bloom's notices. Files are checked to exist before they go on;
// each file's preview (a folder, a text file's opening) is read once by
// scripts/shelf-preview.sh. Saved only with bloom-shelf-persist.
Singleton {
	id: root

	// { kind: "file" | "text", value, id }
	property var items: []
	// Ids added in the last 0.9 s: only these tiles animate in.
	property var newIds: []
	// Bloom's notice line, for 2.6 s.
	property string notice: ""
	// By path: { kind: "folder" | "text" | "file" | "missing", thumb, text }.
	property var previews: ({})

	function _newId() { return Date.now().toString(36) + "-" + Math.random().toString(36).slice(2, 8); }
	function _save() { if (Settings.values["bloom-shelf-persist"]) state.save(root.items); }
	function _say(text) {
		if (!text) return;
		root.notice = text;
		noticeTimer.restart();
	}
	function _apply(result) {
		root._say(result.notice);
		if (result.added.length === 0) return;
		root.items = result.items;
		root.newIds = root.newIds.concat(result.added);
		newTimer.restart();
		root._save();
		root._preview();
	}

	function addText(text) {
		const result = Logic.addText(root.items, text, root._newId);
		root._apply(result);
		return result.added.length ? "ok" : result.notice || "already on the shelf, or not text";
	}
	function addFile(path) { return root.addFiles([path]); }
	// Paths are checked to exist (all at once) before they go on.
	function addFiles(paths) {
		const valid = paths.filter(p => typeof p === "string" && p.startsWith("/") && !p.includes("\0"));
		if (valid.length === 0) return "invalid path";
		exists.pending = exists.pending.concat([valid]);
		exists.next();
		return "checking";
	}
	function remove(index) {
		if (index < 0 || index >= root.items.length) return;
		root.items = root.items.filter((_, i) => i !== index);
		root._save();
	}
	// Bloom's openShelfItem: a file opens in its app, text is copied.
	function activate(index) {
		const item = root.items[index];
		if (!item) return "no item";
		if (opener.running) return "busy";
		opener.item = item;
		opener.command = item.kind === "file"
			? ["timeout", "-k", "1s", "8s", Quickshell.env("BLOOM_XDG_OPEN") || "xdg-open", item.value]
			: ["timeout", "-k", "1s", "8s", Quickshell.env("BLOOM_WL_COPY") || "wl-copy", "--", item.value];
		opener.running = true;
		return "ok";
	}

	Timer { id: noticeTimer; interval: 2600; onTriggered: root.notice = "" }
	Timer { id: newTimer; interval: 900; onTriggered: root.newIds = [] }

	StateFile {
		id: state
		name: "shelf"
		defaultValue: []
		onLoadedChanged: if (loaded && Settings.values["bloom-shelf-persist"]) {
			root.items = Logic.clean(value, root._newId);
			root._preview();
			prune.start();
		}
	}

	// Bloom's startup prune: saved files that are gone (moved, deleted, a
	// drive unplugged) leave the shelf; text always stays.
	Process {
		id: prune
		property var paths: []
		function start() {
			paths = root.items.filter(i => i.kind === "file").map(i => i.value);
			if (paths.length === 0) return;
			command = ["sh", "-c", "for p do [ -e \"$p\" ] && printf '%s\\n' \"$p\"; done; exit 0", "sh"].concat(paths);
			running = true;
		}
		stdout: StdioCollector { id: pruneOut }
		onExited: {
			const alive = pruneOut.text.split("\n");
			const kept = root.items.filter(i => i.kind !== "file" || alive.includes(i.value));
			if (kept.length !== root.items.length) {
				root.items = kept;
				root._save();
			}
		}
	}

	// Which of a batch of paths exist; batches wait their turn.
	Process {
		id: exists
		property var pending: []
		property var batch: []
		function next() {
			if (running || pending.length === 0) return;
			batch = pending[0];
			pending = pending.slice(1);
			command = ["sh", "-c", "for p do [ -e \"$p\" ] && printf '%s\\n' \"$p\"; done; exit 0", "sh"].concat(batch);
			running = true;
		}
		stdout: StdioCollector { id: existsOut }
		onExited: {
			const found = existsOut.text.split("\n").filter(p => p !== "");
			// Keep the batch's order, and only paths that were asked about.
			const present = batch.filter(p => found.includes(p));
			if (present.length === 0)
				root._say(batch.length === 1 ? "File unavailable" : "Files unavailable");
			if (present.length) root._apply(Logic.addFiles(root.items, present, root._newId));
			batch = [];
			next();
		}
	}

	// One file's preview at a time.
	function _preview() {
		const missing = root.items.filter(i => i.kind === "file" && !(i.value in root.previews) && i.value !== preview.path);
		if (preview.running || missing.length === 0) return;
		preview.path = missing[0].value;
		// A file manager's thumbnails (freedesktop spec), as paths.
		const thumbs = Logic.isImage(preview.path) ? [] : Logic.thumbnailCandidates(preview.path, Quickshell.env("HOME")).map(u => decodeURIComponent(u.slice(7)));
		preview.command = ["timeout", "-k", "1s", "3s", "sh", Quickshell.shellPath("scripts/shelf-preview.sh"), preview.path].concat(thumbs);
		preview.running = true;
	}
	Process {
		id: preview
		property string path: ""
		stdout: StdioCollector { id: previewOut }
		onExited: {
			// "<kind>\n<thumbnail or nothing>\n<a text file's opening>"
			const lines = previewOut.text.split("\n");
			const kind = (lines[0] || "").trim() || "file";
			const thumb = (lines[1] || "").trim();
			const next = Object.assign({}, root.previews);
			next[path] = { kind: kind, thumb: thumb ? Logic.fileUrl(thumb) : "",
				text: kind === "text" && !thumb ? Logic.textPreview(lines.slice(2).join("\n")) : "" };
			root.previews = next;
			path = "";
			root._preview();
		}
	}

	// Opening or copying; a file that won't open is checked: gone, it
	// leaves the shelf; otherwise Bloom just says it couldn't open.
	Process {
		id: opener
		property var item: null
		onExited: code => {
			if (item.kind === "text") {
				if (code === 0) root._say("Copied to clipboard");
			} else if (code !== 0) {
				gone.item = item;
				gone.command = ["test", "-e", item.value];
				gone.running = true;
			}
		}
	}
	Process {
		id: gone
		property var item: null
		onExited: code => {
			if (code !== 0) {
				root._say("File no longer exists — removed from shelf");
				root.items = root.items.filter(i => i.id !== item.id);
				root._save();
			} else {
				root._say("Couldn't open the file");
			}
		}
	}
}
