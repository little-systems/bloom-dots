pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/notch/shelf.js" as Logic

Singleton {
	id: root
	property var items: []
	property string error: ""
	function _save() { if (Settings.values["bloom-shelf-persist"]) state.save(root.items); }
	function addText(text) { const next = Logic.add(root.items, "text", text); if (next === root.items) return "invalid text"; root.items = next; root._save(); return "ok"; }
	function addFile(path) {
		if (!path || !path.startsWith("/") || path.includes("\0")) return "invalid path";
		if (check.running) return "busy";
		check.command = ["test", "-f", path];
		check.pendingPath = path;
		check.running = true;
		return "checking";
	}
	function remove(index) { if (index < 0 || index >= root.items.length) return; root.items = root.items.filter((_, i) => i !== index); root._save(); }
	function activate(index) {
		const item = root.items[index];
		if (!item) return "no item";
		if (item.kind === "file") Quickshell.execDetached(["xdg-open", item.value]);
		else Quickshell.execDetached(["wl-copy", "--", item.value]);
		return "ok";
	}
	StateFile { id: state; name: "shelf"; defaultValue: []; onLoadedChanged: if (loaded && Settings.values["bloom-shelf-persist"]) root.items = Logic.clean(value) }
	Process {
		id: check
		property string pendingPath: ""
		onExited: code => {
			if (code === 0) { root.items = Logic.add(root.items, "file", pendingPath); root._save(); root.error = ""; }
			else root.error = "File unavailable";
			pendingPath = "";
		}
	}
}
