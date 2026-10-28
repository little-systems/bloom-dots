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
	function test_restoreAndBound() {
		const mixed = [{ kind: "file", value: "/tmp/a" }, { kind: "file", value: "relative" }, { kind: "text", value: "hello" }];
		compare(Shelf.clean(mixed).length, 2);
		let items = [];
		for (let i = 0; i < 20; i++) items = Shelf.add(items, "text", "item " + i);
		compare(items.length, 10);
		compare(items[0].value, "item 19");
	}
}
