import QtQuick
import QtTest
import "../../shell/modules/dock"

Item {
	width: 800
	height: 300

	Component {
		id: previewComponent
		DockPreview { captureEnabled: false; opened: true }
	}

	Component { id: spyComponent; SignalSpy {} }

	TestCase {
		name: "DockPreviewCard"
		when: windowShown

		function test_cardsAndFallback() {
			const p = createTemporaryObject(previewComponent, parent, {
				candidates: [{ address: "0xa", title: "First", toplevel: null }, { address: "0xb", title: "Second", toplevel: null }]
			});
			verify(p !== null);
			compare(p.width, 452);
			verify(findChild(p, "preview-card-0xa") !== null);
			verify(findChild(p, "preview-fallback-0xa").visible);
			compare(findChild(p, "preview-title-0xb").text, "Second");
		}

		function test_closeDoesNotFocus() {
			const p = createTemporaryObject(previewComponent, parent, {
				candidates: [{ address: "0xa", title: "First", toplevel: null }]
			});
			verify(p !== null);
			const focus = createTemporaryObject(spyComponent, p, { target: p, signalName: "focusRequested" });
			const close = createTemporaryObject(spyComponent, p, { target: p, signalName: "closeRequested" });
			const button = findChild(p, "preview-close-0xa");
			verify(button !== null);
			const point = button.mapToItem(p, button.width / 2, button.height / 2);
			mouseClick(p, point.x, point.y);
			compare(close.count, 1);
			compare(close.signalArguments[0][0], "0xa");
			compare(focus.count, 0);
			const card = findChild(p, "preview-card-0xa");
			const titlePoint = card.mapToItem(p, 12, 150);
			mouseClick(p, titlePoint.x, titlePoint.y);
			compare(focus.count, 1);
			compare(focus.signalArguments[0][0], "0xa");
		}
		function test_onlyThreePartlyVisibleCardsCanCapture() {
			const candidates = ["0xa", "0xb", "0xc", "0xd"].map(address => ({ address: address, title: address, toplevel: null }));
			const p = createTemporaryObject(previewComponent, parent, { candidates: candidates });
			verify(p !== null);
			p.scrollOffset = 100;
			compare(p.liveIndices.length, 3);
		}
	}
}
