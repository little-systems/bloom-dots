import QtQuick
import QtTest
import "../../shell/common"

// Typing parks hover until the pointer itself moves: rows sliding under a
// still pointer must not count as the owner using the mouse.
Item {
	id: host
	width: 400
	height: 300

	Item {
		id: view
		width: 300
		height: 300
		TypingGuard { id: guard }
	}

	TestCase {
		name: "TypingGuard"
		when: windowShown

		function init() {
			mouseMove(host, 100, 100);
			tryVerify(() => guard.hovered, 500);
			guard.typing = false;
		}

		function test_typingParksHover() {
			guard.typed();
			verify(guard.typing);
		}

		function test_stillPointerKeepsTyping() {
			guard.typed();
			mouseMove(host, 100, 100);
			wait(50);
			verify(guard.typing);
		}

		function test_moveWithinSlopKeepsTyping() {
			guard.typed();
			mouseMove(host, 102, 101);
			wait(50);
			verify(guard.typing);
		}

		function test_pointerArrivingFromOutsideEndsTyping() {
			mouseMove(host, 350, 100);
			tryVerify(() => !guard.hovered, 500);
			guard.typed();
			mouseMove(host, 100, 100);
			tryVerify(() => !guard.typing, 500);
		}

		function test_realMoveEndsTyping() {
			guard.typed();
			mouseMove(host, 120, 100);
			tryVerify(() => !guard.typing, 500);
		}
	}
}
