import QtQuick
import QtTest
import "../../shell/modules/notch"

// Bloom's shelf (App.tsx .shelf-*, App.css): tiles of 104 px content with a
// 104 × 84 preview, Bloom's text and folder previews, the caption, the
// remove button on hover, the dashed empty state and the notice; measured
// with tools/bloom-audit/record-shelf.cjs (view origin = pill + 12, 36).
Item {
	id: host
	width: 420
	height: 300

	readonly property var three: [
		{ kind: "text", value: "Meeting notes: ship the shelf parity, then the owner check and the whole-branch review before merging anything.", id: "t1" },
		{ kind: "file", value: "/home/me/notes.md", id: "f1" },
		{ kind: "file", value: "/home/me/Photos", id: "d1" }
	]
	readonly property var previews: ({
		"/home/me/notes.md": { kind: "text", text: "# Notes\nFirst line of the file, then a second one that runs on long enough to wrap." },
		"/home/me/Photos": { kind: "folder", text: "" }
	})

	Component {
		id: viewComponent
		ShelfView { width: 356; height: 154; items: host.three; previews: host.previews }
	}

	TestCase {
		name: "ShelfView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v);
			waitForRendering(host);
			return v;
		}
		function part(item, name) {
			const it = findChild(item, name);
			verify(it, name);
			return it;
		}
		function at(v, item, x, y, w, h, what, tolerance) {
			const t = tolerance || 0.51;
			const p = item.mapToItem(v, 0, 0);
			fuzzyCompare(p.x, x, t, what + " x");
			fuzzyCompare(p.y, y, t, what + " y");
			if (w !== undefined) fuzzyCompare(item.width, w, t, what + " width");
			if (h !== undefined) fuzzyCompare(item.height, h, t, what + " height");
		}
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}

		function test_matchesBloomsLayout() {
			const v = make();
			// Three tiles overflow the 328 px row: Bloom's scrollbar takes 10 px.
			const t0 = part(v, "tile:t1");
			at(v, t0, 14, 12, 116, 120, "first tile");
			at(v, part(v, "tile:f1"), 138, 12, 116, 120, "second tile");
			at(v, part(v, "tile:d1"), 262, 12, 116, 120, "third tile");
			const preview = part(t0, "preview");
			at(v, preview, 20, 18, 104, 84, "preview");
			compare(preview.opacity, 0.85);
			at(v, part(t0, "textIcon"), 28, 25, 11, 11, "text icon");
			compare(part(t0, "textIcon").opacity, 0.4);
			const body = part(t0, "body");
			at(v, body, 28, 40, 88, 56, "text body");
			compare(body.font.pixelSize, 10);
			compare(body.opacity, 0.9);
			const caption = part(t0, "caption");
			at(v, caption, 20, 106, 104, 14, "caption", 1);
			compare(caption.text, "Text · 111 chars");
			compare(caption.font.pixelSize, 11);
			compare(caption.opacity, 0.85);
			at(v, part(t0, "remove"), 108, 16, 18, 18, "remove button");
			// A folder: its 26 px icon, centred.
			at(v, part(part(v, "tile:d1"), "typeIcon"), 262 + 6 + 39, 18 + 29, 26, 26, "folder icon");
			compare(part(part(v, "tile:d1"), "typeIcon").name, "folder");
			compare(part(part(v, "tile:d1"), "caption").text, "Photos");
			verify(part(v, "scrollbar").visible, "the row overflows");
		}

		// The notch is nowrap in Bloom: a text preview is one line, its
		// breaks collapsed, clipped at the tile without an ellipsis.
		function test_textPreviewIsOneLine() {
			const v = make();
			const body = part(part(v, "tile:f1"), "body");
			compare(body.text, "# Notes First line of the file, then a second one that runs on long enough to wrap.");
			compare(body.wrapMode, Text.NoWrap);
			compare(body.elide, Text.ElideNone);
			verify(body.parent.clip || body.clip, "clipped at the tile");
			compare(part(part(v, "tile:f1"), "textIcon").name, "file-text");
		}

		function test_twoTilesFitWithoutScrollbar() {
			const v = make({ items: host.three.slice(0, 2) });
			verify(!part(v, "scrollbar").visible);
			at(v, part(v, "tile:t1"), 14, 12, 116, 130, "tile fills the row");
		}

		function test_removeShowsOnHover() {
			const v = make();
			const t0 = part(v, "tile:t1");
			const button = part(t0, "remove");
			compare(button.opacity, 0);
			const p = t0.mapToItem(host, 50, 50);
			mouseMove(host, p.x, p.y);
			tryCompare(button, "opacity", 1, 500);
			const removed = spy(v, "removeRequested");
			const b = button.mapToItem(host, 9, 9);
			mouseClick(host, b.x, b.y);
			compare(removed.count, 1);
			compare(removed.signalArguments[0][0], 0);
		}

		function test_clickActivates() {
			const v = make();
			const activated = spy(v, "activated");
			const t = part(v, "tile:f1");
			const p = t.mapToItem(host, 40, 40);
			mouseClick(host, p.x, p.y);
			compare(activated.count, 1);
			compare(activated.signalArguments[0][0], 1);
		}

		function test_emptyState() {
			const v = make({ items: [] });
			const empty = part(v, "empty");
			verify(empty.visible);
			compare(part(empty, "label").text, "Drop files or selected text here");
			compare(part(empty, "label").font.pixelSize, 12);
			verify(part(empty, "dashedBorder"), "a dashed border");
		}

		function test_notice() {
			const v = make({ notice: "Copied to clipboard" });
			const n = part(v, "notice");
			verify(n.visible);
			compare(part(n, "label").text, "Copied to clipboard");
			tryVerify(() => Math.abs(n.mapToItem(v, 0, 0).y + n.height - (v.height - 10)) < 0.5, 500, "10 px off the bottom once risen");
			v.notice = "";
			tryVerify(() => !n.visible, 500);
		}

		// A new item springs in from 0.82; the others slide along.
		function test_newTileSpringsIn() {
			const v = make();
			v.newIds = ["n1"];
			v.items = [{ kind: "text", value: "fresh", id: "n1" }].concat(host.three);
			const fresh = part(v, "tile:n1");
			verify(fresh.scale < 1, `starts small, ${fresh.scale}`);
			tryCompare(fresh, "scale", 1, 1000);
			tryVerify(() => Math.abs(part(v, "tile:t1").mapToItem(v, 0, 0).x - 138) < 0.5, 1000, "the old first tile moved over");
		}

		// A removed tile leaves the row at once and fades out where it was.
		function test_removedTileLeaves() {
			const v = make();
			const gone = part(v, "tile:t1");
			v.items = host.three.slice(1);
			verify(gone.opacity > 0, "still fading");
			tryVerify(() => !findChild(v, "tile:t1"), 1000, "gone after 0.16 s");
			tryVerify(() => Math.abs(part(v, "tile:f1").mapToItem(v, 0, 0).x - 14) < 0.5, 1000, "the next one moved in");
		}
	}
}
