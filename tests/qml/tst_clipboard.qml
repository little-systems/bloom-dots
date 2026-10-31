import QtTest
import "../../shell/modules/launcher/launcher.js" as Logic

// What each kind of clipboard entry becomes in the launcher.
TestCase {
	name: "Clipboard"

	function test_classify() {
		compare(Logic.classifyClip("[[ binary data 1.2 MiB png 1920x1080 ]]"), { kind: "image", size: "1.2 MiB", format: "PNG", dims: "1920 × 1080" });
		compare(Logic.classifyClip("[[ binary data 40 KiB zip ]]").kind, "binary");
		compare(Logic.classifyClip("file:///home/a/My%20Doc.pdf").fileName, "My Doc.pdf");
		compare(Logic.classifyClip("https://example.com/x").kind, "link");
		compare(Logic.classifyClip("#FF00aa").kind, "color");
		compare(Logic.classifyClip("#notacolor").kind, "text");
		compare(Logic.classifyClip("hello https://a.b").kind, "text");
	}

	function row(text, thumbs) {
		return Logic.clipRow(Logic.clipEntries("7\t" + text)[0], thumbs || {});
	}

	function test_imageRow() {
		const r = row("[[ binary data 12 KiB png 80x60 ]]", { "7": "/run/x/7" });
		compare(r.name, "Image");
		compare(r.sub, "PNG · 80 × 60 · 12 KiB");
		compare(r.icon, "file:///run/x/7");
		compare(r.preview.image, "file:///run/x/7");
	}

	function test_imageWithoutAThumbnail() {
		const r = row("[[ binary data 12 KiB png 80x60 ]]");
		compare(r.icon, "");
		compare(r.symbol, "file-image");
	}

	function test_fileIcons() {
		compare(row("file:///a/song.mp3").symbol, "file-music");
		compare(row("file:///a/clip.mp4").symbol, "file-video-camera");
		compare(row("file:///a/sheet.csv").symbol, "file-spreadsheet");
		compare(row("file:///a/thing.xyz").symbol, "file");
		compare(row("file:///a/song.mp3").name, "song.mp3");
	}

	function test_colorAndText() {
		compare(row("#336699").swatch, "#336699");
		compare(row("hello").sub, "5 characters");
		compare(row("hello").preview.text, "hello");
	}

	function test_pickingStillPastesTheOriginal() {
		compare(row("#336699").action, { kind: "clip", value: "7\t#336699" });
	}

	function test_thumbs() {
		compare(Logic.imageIds(Logic.clipEntries("1\thi\n2\t[[ binary data 1 KiB png 1x1 ]]")), ["2"]);
		compare(Logic.parseThumbs("2\t/run/2\nnoise\n"), { "2": "/run/2" });
	}

	// A real entry did this: one stray % blanked the whole history.
	function test_oneBadEntryKeepsTheRest() {
		const got = Logic.clipEntries("3\tfile:///a/100%.png\n2\thello\n1\tfile:///a/ok%20x.png");
		compare(got.length, 3);
		compare(got[0].fileName, "100%.png");
		compare(got[2].fileName, "ok x.png");
	}
}
