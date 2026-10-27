import QtQuick
import QtTest
import "../../shell/modules/dock"

Item {
	id: host
	width: 600
	height: 520

	function a(id, name) {
		return { id: id, name: name, icon: "" };
	}

	Component {
		id: popupComponent
		AddAppPopup {
			x: 120
			y: 40
			apps: [host.a("kitty", "kitty"), host.a("firefox", "Firefox"), host.a("gimp", "GIMP"), host.a("chrome", "Google Chrome")]
			running: [host.a("chrome", "Google Chrome")]
			pinned: ["firefox"]
		}
	}

	Component {
		id: spyComponent
		SignalSpy {}
	}

	TestCase {
		name: "AddAppPopup"
		when: windowShown

		function make(props) {
			const p = createTemporaryObject(popupComponent, host, props || {});
			verify(p !== null);
			p.open();
			return p;
		}

		function test_browseSections() {
			const p = make();
			compare(p.flat.map(x => x.id), ["chrome", "gimp", "kitty"], "Running, then All apps without pinned or running");
			verify(findChild(p, "addapp-row-chrome") !== null);
		}

		function test_searchDebounced() {
			const p = make();
			const field = findChild(p, "addapp-search");
			field.text = "fi";
			compare(p.flat.map(x => x.id), ["chrome", "gimp", "kitty"], "not before 150 ms");
			tryVerify(() => p.flat.length === 1 && p.flat[0].id === "firefox", 600);
		}

		// Review focus 4.
		function test_keyboard() {
			const p = make();
			const pin = createTemporaryObject(spyComponent, host, { target: p, signalName: "pinRequested" });
			const closed = createTemporaryObject(spyComponent, host, { target: p, signalName: "closed" });
			compare(p.selectedIndex, 0);
			keyClick(Qt.Key_Up);
			compare(p.selectedIndex, 0, "clamped at the top");
			keyClick(Qt.Key_Down);
			keyClick(Qt.Key_Down);
			keyClick(Qt.Key_Down);
			compare(p.selectedIndex, 2, "clamped at the bottom");
			keyClick(Qt.Key_Return);
			compare(pin.count, 1);
			compare(pin.signalArguments[0][0], "kitty");
			findChild(p, "addapp-search").text = "firefox";
			tryVerify(() => p.flat.length === 1, 600);
			keyClick(Qt.Key_Return);
			compare(pin.count, 1, "already pinned: Enter only closes");
			verify(closed.count >= 1);
		}

		function test_escapeCloses() {
			const p = make();
			keyClick(Qt.Key_Escape);
			verify(!p.opened);
		}

		function test_loadingSkeleton() {
			const p = make({ apps: [], running: [], loading: true });
			verify(findChild(p, "addapp-skeleton").visible);
			compare(findChild(p, "addapp-empty").visible, false, "not 'No results' while loading");
			p.loading = false;
			compare(findChild(p, "addapp-skeleton").visible, false);
			verify(findChild(p, "addapp-empty").visible);
			compare(findChild(p, "addapp-empty").text, "Running apps show up here — search to pin anything else");
		}

		function test_clickPins() {
			const p = make();
			const pin = createTemporaryObject(spyComponent, host, { target: p, signalName: "pinRequested" });
			wait(400);
			mouseClick(findChild(p, "addapp-row-gimp"), 20, 20);
			compare(pin.signalArguments[0][0], "gimp");
		}
	}
}
