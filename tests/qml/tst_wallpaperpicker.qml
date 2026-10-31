import QtQuick
import QtTest
import "../../shell/modules/wallpaper"

Item {
	id: host
	width: 1000
	height: 700

	Component {
		id: viewComponent
		PickerView { anchors.fill: parent; items: ["/w/a.jpg", "/w/b.jpg", "/w/c.mp4", "/w/d.jpg"]; current: "/w/b.jpg" }
	}

	TestCase {
		name: "PickerView"
		when: windowShown

		function make(props) {
			const v = createTemporaryObject(viewComponent, host, props || {});
			verify(v);
			v.open();
			return v;
		}
		function spy(target, signalName) {
			const s = createTemporaryQmlObject("import QtTest; SignalSpy {}", host);
			s.target = target;
			s.signalName = signalName;
			return s;
		}

		function test_startsOnTheCurrentWallpaper() {
			compare(make().selectedIndex, 1);
		}

		function test_arrowsMove() {
			const v = make();
			keyClick(Qt.Key_Right);
			compare(v.selectedIndex, 2);
			keyClick(Qt.Key_Left);
			keyClick(Qt.Key_Left);
			compare(v.selectedIndex, 0);
			keyClick(Qt.Key_Down);
			compare(v.selectedIndex, 3);
		}

		function test_enterChooses() {
			const v = make();
			const chosen = spy(v, "chosen");
			keyClick(Qt.Key_Right);
			keyClick(Qt.Key_Return);
			compare(Array.from(chosen.signalArguments[0]), ["/w/c.mp4"]);
		}

		function test_clickChooses() {
			const v = make();
			const chosen = spy(v, "chosen");
			tryCompare(v, "_morph", 1, 2000);
			waitForRendering(host);
			tryVerify(() => findChild(v, "tile:/w/d.jpg") !== null, 1000, "tile");
			const it = findChild(v, "tile:/w/d.jpg");
			const p = it.mapToItem(host, it.width / 2, it.height / 2);
			mouseClick(host, p.x, p.y);
			compare(Array.from(chosen.signalArguments[0]), ["/w/d.jpg"]);
		}

		function test_escapeDismisses() {
			const v = make();
			const dismissed = spy(v, "dismissed");
			keyClick(Qt.Key_Escape);
			compare(dismissed.count, 1);
		}

		function test_emptyFolder() {
			const v = make({ items: [] });
			compare(findChild(v, "empty").text, "No wallpapers in this folder");
			keyClick(Qt.Key_Return);
		}
	}
}
