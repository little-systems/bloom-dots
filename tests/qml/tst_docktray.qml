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

	// Bloom dockApps.ts: a tray icon belongs to the app whose process owns it
	// (on Linux, the D-Bus connection's pid and executable), not to its name.
	readonly property var entries: [
		{ id: "com.anthropic.Claude", startupClass: "com.anthropic.Claude", exec: "claude-desktop", webApp: false },
		{ id: "chatgpt", startupClass: "", exec: "chatgpt", webApp: false },
		{ id: "spotify", startupClass: "spotify", exec: "spotify", webApp: false },
		{ id: "brave-aaa-Default", startupClass: "brave-aaa-Default", exec: "brave", webApp: true },
		{ id: "brave-browser", startupClass: "brave-browser", exec: "brave", webApp: false }
	]
	function sni(key, id, extra) { return Object.assign({ key: key, id: id, title: "", status: "Active", category: "ApplicationStatus", icon: "" }, extra || {}); }

	function test_ownerFromThePixmapUrlOrAUniqueIdAndIcon() {
		const owners = [
			{ service: ":1.58/StatusNotifierItem", id: "chrome_status_icon_1", title: "", iconName: "", pid: 10, ppid: 1, exe: "/usr/lib/chatgpt/ChatGPT" },
			{ service: ":1.60/StatusNotifierItem", id: "chrome_status_icon_1", title: "", iconName: "", pid: 20, ppid: 1, exe: "/opt/brave/brave" },
			{ service: ":1.70/x", id: "spotify-client", title: "spotify", iconName: "spotify-linux-32", pid: 30, ppid: 1, exe: "/opt/spotify/spotify" }
		];
		compare(Tray.ownerOf(sni("a", "chrome_status_icon_1", { icon: "image://service.sni/:1.58/StatusNotifierItem/1" }), owners).pid, 10);
		compare(Tray.ownerOf(sni("b", "chrome_status_icon_1"), owners), null, "two owners share the id");
		compare(Tray.ownerOf(sni("c", "spotify-client", { title: "spotify", icon: "image://icon/spotify-linux-32" }), owners).pid, 30);
	}

	function test_windowPidThenExecutableNameIdentifyTheApp() {
		const windows = [{ id: "com.anthropic.Claude", pid: 100 }];
		compare(Tray.appFor({ pid: 100, ppid: 1, exe: "/usr/lib/claude-desktop/claude" }, windows, entries), "com.anthropic.Claude");
		compare(Tray.appFor({ pid: 101, ppid: 100, exe: "/x/helper" }, windows, entries), "com.anthropic.Claude", "a child of the window's process");
		compare(Tray.appFor({ pid: 10, ppid: 1, exe: "/usr/lib/chatgpt/ChatGPT" }, windows, entries), "chatgpt");
		compare(Tray.appFor({ pid: 30, ppid: 1, exe: "/opt/spotify/spotify" }, [], entries), "spotify");
		compare(Tray.appFor({ pid: 40, ppid: 1, exe: "/usr/bin/unknown" }, [], entries), "");
	}

	function test_aBrowserTrayNeverJoinsItsWebApps() {
		const windows = [{ id: "brave-aaa-Default", pid: 20 }, { id: "brave-bbb-Default", pid: 20 }];
		compare(Tray.appFor({ pid: 20, ppid: 1, exe: "/opt/brave/brave" }, windows, entries), "", "one process, several apps");
		compare(Tray.appFor({ pid: 20, ppid: 1, exe: "/opt/brave/brave" }, [], entries), "brave-browser", "the browser itself, never the web app");
	}

	function test_pinnedAppWithoutAWindowGetsItsTray() {
		const owners = [{ service: ":1.58/StatusNotifierItem", id: "chrome_status_icon_1", title: "", iconName: "", pid: 10, ppid: 1, exe: "/usr/lib/chatgpt/ChatGPT" }];
		const item = sni("a", "chrome_status_icon_1", { icon: "image://service.sni/:1.58/StatusNotifierItem/1" });
		const picked = Tray.selectTray([item], entries, [], ["chatgpt"], { owners: owners, windows: [], observed: [] });
		compare(picked.merged.chatgpt.map(x => x.key), ["a"]);
		compare(picked.separate, []);
		compare(picked.background, []);
	}

	// Bloom selectDockTrayApps: an unpinned tray icon becomes a dock item only
	// after its app has had a window; it is forgotten once the icon goes.
	function test_unpinnedTrayAppsAppearOnlyAfterAWindow() {
		const owners = [{ service: ":1.70/x", id: "spotify-client", title: "spotify", iconName: "", pid: 30, ppid: 1, exe: "/opt/spotify/spotify" }];
		const item = sni("s", "spotify-client", { title: "spotify", icon: "image://service.sni/:1.70/x/1" });
		let picked = Tray.selectTray([item], entries, [], [], { owners: owners, windows: [], observed: [] });
		compare([picked.background.length, picked.separate.length], [0, 0], "never seen with a window");
		picked = Tray.selectTray([item], entries, ["spotify"], [], { owners: owners, windows: [{ id: "spotify", pid: 30 }], observed: [] });
		compare(picked.merged.spotify.map(x => x.key), ["s"]);
		compare(picked.observed, ["/opt/spotify/spotify"]);
		picked = Tray.selectTray([item], entries, [], [], { owners: owners, windows: [], observed: picked.observed });
		compare(picked.background.map(b => [b.id, b.trays.map(t => t.key)]), [["spotify", ["s"]]], "the window closed to the tray");
		compare(Tray.selectTray([], entries, [], [], { owners: [], windows: [], observed: picked.observed }).observed, [], "forgotten with its icon");
	}

	function test_observedTrayWithoutADesktopEntryKeepsItsOwnSlot() {
		const owners = [{ service: ":1.80/x", id: "tool", title: "Tool", iconName: "", pid: 50, ppid: 1, exe: "/opt/tool/tool" }];
		const item = sni("t", "tool", { icon: "image://service.sni/:1.80/x/1" });
		compare(Tray.selectTray([item], entries, [], [], { owners: owners, windows: [], observed: [] }).separate, []);
		compare(Tray.selectTray([item], entries, [], [], { owners: owners, windows: [], observed: ["/opt/tool/tool"] }).separate.map(x => x.key), ["t"]);
	}

	function test_desktopIdentityNamesItsExecutable() {
		compare(Tray.identity("chatgpt", "", ["chatgpt", "%U"]), { id: "chatgpt", startupClass: "", exec: "chatgpt", webApp: false });
		compare(Tray.identity("spotify", "spotify", ["/usr/bin/spotify", "--uri=%u"]).exec, "spotify");
		verify(Tray.identity("brave-aaa-Default", "", ["/usr/bin/brave", "--profile-directory=Default", "--app-id=aaa"]).webApp);
		verify(Tray.identity("chrome-x", "", ["google-chrome", "--app=https://x"]).webApp);
		compare(Tray.identity("env-app", "", ["env", "FOO=1", "/opt/tool/tool"]).exec, "tool");
		compare(Tray.identity("empty", "", []).exec, "");
	}
}
