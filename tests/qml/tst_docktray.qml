import QtQuick
import QtTest
import "../../shell/modules/dock/tray.js" as Tray

TestCase {
	name: "DockTrayRules"

	function test_exactDesktopIdMergesWithRunningApp() {
		const items = [{ key: "sni-1", id: "org.example.Player", title: "Music", status: "Active", category: "ApplicationStatus" }];
		const picked = Tray.selectTray(items, [{ id: "org.example.Player", startupClass: "Player" }], ["org.example.Player"], []);
		compare(picked.merged["org.example.Player"].map(x => x.key), ["sni-1"]);
		compare(picked.separate, []);
	}

	function test_sameTitleNeverIdentifiesAnApp() {
		const item = { key: "sni-2", id: "unrelated", title: "Editor", status: "Active", category: "ApplicationStatus" };
		const picked = Tray.selectTray([item], [
			{ id: "first", name: "Editor", startupClass: "first-class" },
			{ id: "second", name: "Editor", startupClass: "second-class" }
		], ["first", "second"], []);
		compare(Object.keys(picked.merged), []);
		compare(picked.separate.map(x => x.key), ["sni-2"]);
	}

	function test_ambiguousClassStaysSeparateAndPassiveIsHidden() {
		const items = [
			{ key: "a", id: "shared", status: "Active", category: "ApplicationStatus" },
			{ key: "b", id: "passive", status: "Passive", category: "ApplicationStatus" },
			{ key: "c", id: "network", status: "NeedsAttention", category: "SystemServices" }
		];
		const picked = Tray.selectTray(items, [{ id: "one", startupClass: "shared" }, { id: "two", startupClass: "shared" }], ["one", "two"], []);
		compare(picked.separate.map(x => x.key), ["a", "c"]);
		compare(Object.keys(picked.merged), []);
	}

	function test_twoHandlesMergeAndDisappearWithSource() {
		const items = [
			{ key: "a", id: "chat.desktop", title: "Inbox", status: "Active", category: "Communications" },
			{ key: "b", id: "chat.desktop", title: "Calls", status: "Active", category: "Communications" }
		];
		const entries = [{ id: "chat", startupClass: "Chat" }];
		compare(Tray.selectTray(items, entries, ["chat"], []).merged.chat.map(x => x.title), ["Inbox", "Calls"]);
		compare(Object.keys(Tray.selectTray([], entries, ["chat"], []).merged), []);
	}
}
