import QtQuick
import QtTest

// Under Hyprland the card windows fade as a whole (HyprlandWindow.opacity
// follows `fade`), so the compositor's blur fades with the card, like CSS
// opacity over backdrop-filter. The card itself then stays solid: its pixels
// keep clearing the blur rule's ignore_alpha while its shadow stays below it.
Item {
	id: host
	width: 1000
	height: 700

	readonly property var views: [
		"../../shell/modules/launcher/LauncherView.qml",
		"../../shell/modules/cheatsheet/CheatsheetView.qml",
		"../../shell/modules/overview/OverviewView.qml",
		"../../shell/modules/session/SessionView.qml",
		"../../shell/modules/polkit/PolkitView.qml",
		"../../shell/modules/wallpaper/PickerView.qml"
	]

	TestCase {
		name: "CompositorFade"
		when: windowShown

		function make(path, compositorFade) {
			const component = Qt.createComponent(Qt.resolvedUrl(path));
			compare(component.status, Component.Ready, path + ": " + component.errorString());
			const v = createTemporaryObject(component, host, { width: host.width, height: host.height, compositorFade: compositorFade });
			verify(v, path);
			return v;
		}

		function test_cardStaysSolidWhileTheWindowFades() {
			for (const path of host.views) {
				const v = make(path, true);
				const card = findChild(v, "card");
				v.open();
				tryVerify(() => v.fade > 0 && v.fade < 1, 1000, path + " fades in");
				compare(card.opacity, 1, path + " card is solid while fading in");
				tryCompare(v, "fade", 1, 2000, path);
				// Closing unmaps the window; Hyprland's layer animation fades it.
				v.close();
				tryCompare(v, "fade", 0, 2000, path);
				compare(card.opacity, 0, path + " card hides once faded out");
				verify(!v.shown, path + " gone once faded out");
			}
		}

		function test_elsewhereTheCardFadesItself() {
			for (const path of host.views) {
				const v = make(path, false);
				const card = findChild(v, "card");
				v.open();
				tryVerify(() => v.fade > 0 && v.fade < 1, 1000, path + " fades in");
				compare(card.opacity, v.fade, path);
				tryCompare(v, "fade", 1, 2000, path);
				compare(card.opacity, 1, path);
			}
		}
	}
}
