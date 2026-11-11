import QtQuick
import QtTest
import "../../sddm/bloom"
import "../../shell/modules/lock"

// The Bloom login screen: the lock screen's own view, driven by SDDM.
Item {
	id: host
	width: 1000
	height: 700

	QtObject {
		id: fakeApi
		signal loginFailed()
		signal loginSucceeded()
		property string hostName: "bloom-vm"
		property var calls: []
		function login(user, password, session) { calls = calls.concat([["login", user, password, session]]); }
		function powerOff() { calls = calls.concat([["powerOff"]]); }
		function reboot() { calls = calls.concat([["reboot"]]); }
		function suspend() { calls = calls.concat([["suspend"]]); }
	}
	ListModel { id: oneUser; property int lastIndex: 0; ListElement { name: "dhanush" } }
	ListModel {
		id: twoUsers
		property int lastIndex: 1
		ListElement { name: "alex" }
		ListElement { name: "dhanush" }
	}
	ListModel { id: oneSession; property int lastIndex: 0; ListElement { name: "Hyprland" } }
	ListModel {
		id: twoSessions
		property int lastIndex: 0
		ListElement { name: "Hyprland" }
		ListElement { name: "Hyprland (uwsm-managed)" }
	}

	Component {
		id: greeterComponent
		BloomGreeter { anchors.fill: parent; api: fakeApi; stateUrl: "file:///nonexistent/State.qml" }
	}
	Component {
		id: lockComponent
		LockView { anchors.fill: parent; user: "dhanush"; clockTurning: false }
	}

	TestCase {
		name: "Greeter"
		when: windowShown

		function make(users, sessions) {
			fakeApi.calls = [];
			const g = createTemporaryObject(greeterComponent, host, { userModel: users, sessionModel: sessions });
			verify(g);
			tryCompare(part(g, "fieldBox"), "scale", 1, 1500); // the islands spring in
			return g;
		}
		function part(item, name) {
			tryVerify(() => findChild(item, name) !== null, 1000, name);
			return findChild(item, name);
		}

		function test_lock_screen_unchanged_without_greeter_props() {
			const v = createTemporaryObject(lockComponent, host);
			compare(findChild(v, "userPrevious").visible, false);
			compare(findChild(v, "userNext").visible, false);
			compare(findChild(v, "session").visible, false);
		}
		function test_arrows_only_with_several_users() {
			let g = make(oneUser, oneSession);
			compare(part(g, "userPrevious").visible, false);
			g = make(twoUsers, oneSession);
			compare(part(g, "userNext").visible, true);
			compare(part(g, "user").text, "dhanush", "starts at the last user");
			mouseClick(part(g, "userNext"));
			compare(part(g, "user").text, "alex");
		}
		function test_session_only_with_several_sessions() {
			let g = make(oneUser, oneSession);
			compare(part(g, "session").visible, false);
			g = make(oneUser, twoSessions);
			const label = part(g, "session");
			compare(label.visible, true);
			compare(label.text, "Hyprland");
			mouseClick(label);
			compare(label.text, "Hyprland (uwsm-managed)");
		}
		function test_submit_calls_login_with_selected_user_and_session() {
			const g = make(twoUsers, twoSessions);
			mouseClick(part(g, "session"));
			part(g, "field").forceActiveFocus();
			keyClick("s"); keyClick("e"); keyClick("c");
			keyClick(Qt.Key_Return);
			compare(JSON.stringify(fakeApi.calls), JSON.stringify([["login", "dhanush", "sec", 1]]));
			compare(part(g, "field").text, "", "the password leaves the field");
		}
		function test_failed_login_shakes_and_clears() {
			const g = make(oneUser, oneSession);
			part(g, "field").forceActiveFocus();
			keyClick("x"); keyClick(Qt.Key_Return);
			fakeApi.loginFailed();
			compare(part(g, "message").text, "Wrong password");
			compare(part(g, "field").readOnly, false, "can try again");
		}
		function test_power_buttons_reach_sddm() {
			const g = make(oneUser, oneSession);
			mouseClick(part(g, "shutdown"));
			mouseClick(part(g, "reboot"));
			mouseClick(part(g, "suspend"));
			compare(JSON.stringify(fakeApi.calls), JSON.stringify([["powerOff"], ["reboot"], ["suspend"]]));
		}
		function test_clock_tag_names_the_machine_instead_of_locked() {
			const g = make(oneUser, oneSession);
			compare(part(g, "clockTag").text, "bloom-vm");
		}
		function test_login_state_sets_wallpaper_accent_and_scale() {
			api_reset();
			const g = createTemporaryObject(greeterComponent, host, { userModel: oneUser, sessionModel: oneSession,
				stateUrl: Qt.resolvedUrl("login-state/State.qml") });
			tryVerify(() => String(part(g, "backdrop").source).endsWith("login-state/wallpaper-0123456789ab.jpg"), 2000, String(part(g, "backdrop").source));
			compare(String(findChild(g, "confirm").color), "#ff8800");
			compare(findChild(g, "fieldBox").parent.scale, 1.15);
			compare(String(findChild(g, "user").color), String(Qt.rgba(1, 1, 1, 0.6)), "missing colours keep the dark palette");
		}
		function api_reset() { fakeApi.calls = []; }
		function test_missing_login_state_uses_default_wallpaper() {
			const g = make(oneUser, oneSession);
			verify(String(part(g, "backdrop").source).endsWith("default-wallpaper.jpg"));
		}
	}
}
