import QtQuick
import QtTest
import "../../shell/modules/dock"

Item {
	width: 500; height: 300
	Component { id: c; DockConfirm { opened: true } }
	Component { id: spy; SignalSpy {} }
	TestCase {
		name: "DockConfirm"
		when: windowShown
		function test_cancelNeverConfirms() {
			const dialog = createTemporaryObject(c, parent);
			verify(dialog !== null);
			const confirmed = createTemporaryObject(spy, dialog, { target: dialog, signalName: "confirmed" });
			const cancel = findChild(dialog, "confirm-cancel");
			mouseClick(cancel, cancel.width / 2, cancel.height / 2);
			compare(dialog.opened, false);
			compare(confirmed.count, 0);
		}
		function test_explicitButtonConfirmsOnce() {
			const dialog = createTemporaryObject(c, parent);
			verify(dialog !== null);
			const confirmed = createTemporaryObject(spy, dialog, { target: dialog, signalName: "confirmed" });
			const button = findChild(dialog, "confirm-empty");
			mouseClick(button, button.width / 2, button.height / 2);
			compare(confirmed.count, 1);
			compare(dialog.opened, false);
		}
	}
}
