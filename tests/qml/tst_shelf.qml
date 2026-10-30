import QtQuick
import QtTest
import "../../shell/modules/notch/shelf.js" as Shelf

TestCase {
	name: "ShelfRules"
	function test_localPathsOnly() {
		compare(Shelf.filePath("file:///home/user/Notes%20One.txt"), "/home/user/Notes One.txt");
		compare(Shelf.filePath("https://example.com/file"), "");
		compare(Shelf.filePath("file:///%ZZ"), "");
		compare(Shelf.filePath(Shelf.fileUrl("/tmp/a # file")), "/tmp/a # file");
	}
	function ids() {
		let n = 0;
		return () => "id" + (++n);
	}

	// Restored items keep their ids; old saves without one get one.
	function test_restore() {
		const mixed = [{ kind: "file", value: "/tmp/a", id: "x" }, { kind: "file", value: "relative" }, { kind: "text", value: "hello" }];
		const got = Shelf.clean(mixed, ids());
		compare(got.map(i => [i.kind, i.value, i.id]), [["file", "/tmp/a", "x"], ["text", "hello", "id1"]]);
	}

	// Bloom's addShelfItems / addShelfText: newest first, no duplicates,
	// and a full shelf (10) refuses rather than dropping old items.
	function test_addRules() {
		const id = ids();
		let r = Shelf.addFiles([], ["/a", "/b", "/a"], id);
		compare(r.items.map(i => i.value), ["/a", "/b"]);
		compare(r.added, ["id1", "id2"]);
		compare(r.notice, "");
		r = Shelf.addFiles(r.items, ["/b", "/c"], id);
		compare(r.items.map(i => i.value), ["/c", "/a", "/b"], "only the new file, in front");
		r = Shelf.addText(r.items, "hi", id);
		compare(r.items[0].value, "hi");
		compare(Shelf.addText(r.items, "hi", id).added, [], "the same text once");
		let items = r.items;
		r = Shelf.addFiles(items, ["/1", "/2", "/3", "/4", "/5", "/6", "/7", "/8"], id);
		compare(r.items.length, 10);
		compare(r.notice, "Shelf is full — added 6 of 8 items");
		compare(r.items.map(i => i.value).slice(0, 6), ["/1", "/2", "/3", "/4", "/5", "/6"]);
		items = r.items;
		r = Shelf.addFiles(items, ["/9"], id);
		compare(r.items, items, "full: nothing goes");
		compare(r.notice, "Shelf is full (10) — remove an item first");
		compare(Shelf.addText(items, "new", id).notice, "Shelf is full (10) — remove an item first");
	}

	// Bloom's ShelfTypeIcon: a folder, else the extension's lucide icon.
	function test_typeIcons() {
		compare(Shelf.typeIcon("/a/Photos", true), "folder");
		compare(Shelf.typeIcon("/a/b.PNG", false), "file-image");
		compare(Shelf.typeIcon("/a/clip.mkv", false), "file-video-camera");
		compare(Shelf.typeIcon("/a/song.flac", false), "file-music");
		compare(Shelf.typeIcon("/a/t.xlsx", false), "file-spreadsheet");
		compare(Shelf.typeIcon("/a/deck.key", false), "presentation");
		compare(Shelf.typeIcon("/a/r.pdf", false), "file-text");
		compare(Shelf.typeIcon("/a/x.tar", false), "file-archive");
		compare(Shelf.typeIcon("/a/main.rs", false), "file-code");
		compare(Shelf.typeIcon("/a/setup.exe", false), "app-window");
		compare(Shelf.typeIcon("/a/disk.iso", false), "disc");
		compare(Shelf.typeIcon("/a/f.woff2", false), "file-type");
		compare(Shelf.typeIcon("/a/noext", false), "file");
	}

	// The tile's caption: a text item counts its characters.
	function test_tileName() {
		compare(Shelf.tileName({ kind: "text", value: "hello there" }), "Text · 11 chars");
		compare(Shelf.tileName({ kind: "file", value: "/home/u/Report final.pdf" }), "Report final.pdf");
	}

	// Bloom's preview sources (shelf_preview.rs): images are decoded, these
	// text files show their opening 400 characters.
	function test_previewKinds() {
		verify(Shelf.isImage("/a/b.jpeg"));
		verify(Shelf.isImage("/a/b.TIFF"));
		verify(!Shelf.isImage("/a/b.svg"), "Bloom decodes rasters only");
		verify(Shelf.isText("/a/notes.md"));
		verify(Shelf.isText("/a/sub.vtt"));
		verify(!Shelf.isText("/a/b.pdf"));
		compare(Shelf.textPreview("x".repeat(900)).length, 400);
		compare(Shelf.textPreview("short"), "short");
	}

	// A file manager's thumbnail (freedesktop thumbnail spec): the cache
	// names it by the MD5 of the file's URI, large first.
	function test_thumbnailCache() {
		const got = Shelf.thumbnailCandidates("/home/u/My Film.mp4", "/home/u");
		const md5 = Qt.md5("file:///home/u/My%20Film.mp4");
		compare(got, ["file:///home/u/.cache/thumbnails/large/" + md5 + ".png", "file:///home/u/.cache/thumbnails/normal/" + md5 + ".png"]);
	}
}
