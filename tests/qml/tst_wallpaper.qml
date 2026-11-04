import QtTest
import "../../shell/modules/wallpaper/wallpaper.js" as Logic

TestCase {
	name: "WallpaperLogic"

	function test_kinds() {
		verify(Logic.isVideo("/a/b.MP4"));
		verify(Logic.isVideo("/a/b.webm"));
		verify(!Logic.isVideo("/a/b.jpg"));
		verify(!Logic.isVideo(""));
	}

	function test_listKeepsPicturesAndVideos() {
		compare(Logic.parseList("/w/b.jpg\n/w/notes.txt\n/w/a.PNG\n/w/c.mp4\n\n"), ["/w/a.PNG", "/w/b.jpg", "/w/c.mp4"]);
		compare(Logic.parseList(""), []);
	}

	function test_recursiveListAndUrls() {
		compare(Logic.parseList("/w/sub/a.svg\0/w/sub/b.avif\0/w/a\nb.jpg\0/w/sub/a.svg\0"), ["/w/a\nb.jpg", "/w/sub/a.svg", "/w/sub/b.avif"]);
		const path = "/w/snow #1 & café.jpg";
		compare(Logic.localPath(Logic.fileUrl(path)), path);
		compare(Logic.search(["/w/Nature/green.jpg", "/w/blue.png"], "nature green"), ["/w/Nature/green.jpg"]);
	}
	function test_accentFromMatugen() {
		compare(Logic.accentFrom('{"colors":{"primary":{"dark":{"color":"#abcdef"}}}}'), "#abcdef");
		compare(Logic.accentFrom('{"colors":{"primary":{"default":{"color":"#123456"}}}}'), "#123456");
		compare(Logic.accentFrom('{"colors":{"primary":"#aabbcc"}}'), "#aabbcc");
		compare(Logic.accentFrom("{}"), "");
		compare(Logic.accentFrom("nope"), "");
	}

	function test_randomNeverRepeats() {
		compare(Logic.pickOther(["a", "b", "c"], "a", 0), "b");
		compare(Logic.pickOther(["a", "b", "c"], "a", 0.99), "c");
		compare(Logic.pickOther(["a"], "a", 0.5), "");
		compare(Logic.pickOther([], "", 0.5), "");
	}

	function test_gridMoves() {
		compare(Logic.move(0, "right", 7, 3), 1);
		compare(Logic.move(2, "right", 7, 3), 3);
		compare(Logic.move(6, "right", 7, 3), 6);
		compare(Logic.move(0, "left", 7, 3), 0);
		compare(Logic.move(1, "down", 7, 3), 4);
		compare(Logic.move(5, "down", 7, 3), 6);
		compare(Logic.move(6, "down", 7, 3), 6);
		compare(Logic.move(4, "up", 7, 3), 1);
		compare(Logic.move(1, "up", 7, 3), 1);
	}
}
