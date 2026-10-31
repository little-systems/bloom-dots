//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
// Importing a module's directory is what makes Quickshell index its QML
// types, so a window loaded by URL can use the files beside it.
import "modules/notch"
import "modules/dock"
import "modules/osd"
import "modules/launcher"
import "modules/session"
import "modules/overview"
import "modules/polkit"
import "modules/lock"
import "modules/cheatsheet"
import "modules/wallpaper"
import "common/render"

// Bloom shell root: loads the core services, the surfaces enabled in
// bloom-enabled-modules, and the IPC interface used by `bloom ipc` and keybinds.
ShellRoot {
	// Layers render at the scale the stages are drawn (common/render).
	Binding {
		target: Render
		property: "scale"
		value: (Settings.values["bloom-scale"] || 1) * Math.max(1, ...Quickshell.screens.map(s => s.devicePixelRatio || 1))
	}
	Component.onCompleted: console.log(`bloom: shell started (theme ${Theme.mode}, settings ${Settings.path})`)

	readonly property var _modules: Settings.values["bloom-enabled-modules"]

	LazyLoader {
		id: notchLoader
		active: _modules.indexOf("notch") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/notch/NotchWindow.qml"), { modelData: modelData })
			}
		}
	}
	// A persisted Pomodoro deadline must survive a shell restart even when the
	// Calendar panel stays closed. CalendarState schedules one expiry timer.
	LazyLoader {
		active: _modules.indexOf("notch") >= 0 && Settings.values["bloom-calendar-enabled"]
		component: Scope { Component.onCompleted: CalendarState.remaining() }
	}

	LazyLoader {
		id: launcherLoader
		active: _modules.indexOf("launcher") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/launcher/LauncherWindow.qml"), { modelData: modelData })
			}
		}
	}

	LazyLoader {
		id: sessionLoader
		active: _modules.indexOf("session") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/session/SessionWindow.qml"), { modelData: modelData })
			}
		}
	}

	LazyLoader {
		id: overviewLoader
		active: _modules.indexOf("overview") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/overview/OverviewWindow.qml"), { modelData: modelData })
			}
		}
	}

	// Exclusive with any other polkit agent: only one can register (§3.4).
	LazyLoader {
		active: _modules.indexOf("cheatsheet") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/cheatsheet/CheatsheetWindow.qml"), { modelData: modelData })
			}
		}
	}

	LazyLoader {
		active: _modules.indexOf("wallpaper") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Scope {
				id: wallpaperScreen
				required property var modelData
				Loader { Component.onCompleted: setSource(Qt.resolvedUrl("modules/wallpaper/WallpaperWindow.qml"), { modelData: wallpaperScreen.modelData }) }
				Loader { Component.onCompleted: setSource(Qt.resolvedUrl("modules/wallpaper/PickerWindow.qml"), { modelData: wallpaperScreen.modelData }) }
			}
		}
	}

	LazyLoader {
		id: lockLoader
		active: _modules.indexOf("lock") >= 0
		component: LockSurface {}
	}
	LazyLoader {
		id: polkitLoader
		active: _modules.indexOf("polkit") >= 0
		component: PolkitSurface {}
	}

	LazyLoader {
		id: dockLoader
		active: _modules.indexOf("dock") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/dock/DockWindow.qml"), { modelData: modelData })
			}
		}
	}

	LazyLoader {
		id: leftOsdLoader
		active: _modules.indexOf("osd") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/osd/OsdWindow.qml"), { modelData: modelData, edge: "left" })
			}
		}
	}
	LazyLoader {
		id: rightOsdLoader
		active: _modules.indexOf("osd") >= 0
		component: Variants {
			model: Quickshell.screens
			delegate: Loader {
				required property var modelData
				Component.onCompleted: setSource(Qt.resolvedUrl("modules/osd/OsdWindow.qml"), { modelData: modelData, edge: "right" })
			}
		}
	}
	LazyLoader {
		id: notificationsLoader
		active: _modules.indexOf("notifications") >= 0
		source: Qt.resolvedUrl("modules/notifications/NotificationHub.qml")
	}

	LazyLoader {
		active: _modules.indexOf("dock") >= 0 && _modules.indexOf("tray") >= 0
		source: Qt.resolvedUrl("modules/dock/DockTraySource.qml")
	}

	// Super+Alt+1–9, only under Hyprland, with the dock and the setting on.
	LazyLoader {
		active: _modules.indexOf("dock") >= 0 && HyprState.available && Settings.values["bloom-dock-win-number-enabled"]
		source: Qt.resolvedUrl("modules/dock/DockShortcuts.qml")
	}

	IpcHandler {
		target: "shell"

		function ping(): string {
			return "pong";
		}
	}

	IpcHandler {
		target: "calendar"
		function state(): string { return JSON.stringify({ durationSec: CalendarState.durationSec, deadlineMs: CalendarState.deadlineMs, pausedSec: CalendarState.pausedSec, finished: CalendarState.finished }); }
		function start(): string { CalendarState.start(); return "ok"; }
		function pause(): string { CalendarState.pause(); return "ok"; }
		function reset(): string { CalendarState.reset(); return "ok"; }
		function setDuration(seconds: int): string { return CalendarState.setDuration(seconds); }
	}

	IpcHandler {
		target: "shelf"
		function state(): string { return JSON.stringify(ShelfState.items); }
		// The items with the notice line and each file's preview.
		function details(): string { return JSON.stringify({ items: ShelfState.items, notice: ShelfState.notice, previews: ShelfState.previews }); }
		function addText(text: string): string { return ShelfState.addText(text); }
		function addFile(path: string): string { return ShelfState.addFile(path); }
		function remove(index: int): string { ShelfState.remove(index); return "ok"; }
	}

	IpcHandler {
		target: "settings"

		// The value as JSON (null for an unknown key).
		function get(key: string): string {
			return JSON.stringify(Settings.get(key) ?? null);
		}

		// `value` is JSON (0.6, true, "\"light\""); a bare word is taken as a string.
		function set(key: string, value: string): string {
			let parsed = value;
			if (typeof value === "string") {
				try {
					parsed = JSON.parse(value);
				} catch (e) {}
			}
			// Quickshell IPC expands JSON arrays as positional arguments. The
			// bloom CLI wraps them as a JSON string; decode that second layer only
			// for list settings so ordinary text remains text.
			if (Settings.inputType(key) === "list" && typeof parsed === "string") {
				try {
					parsed = JSON.parse(parsed);
				} catch (e) {}
			}
			return Settings.set(key, parsed) || "ok";
		}

		function nonDefaults(): string {
			return JSON.stringify(Settings.nonDefaults());
		}

		function warnings(): string {
			return JSON.stringify(Settings.warnings);
		}
	}

	IpcHandler {
		target: "theme"

		function mode(): string {
			return Theme.mode;
		}
	}

	IpcHandler {
		target: "osd"
		function _windows() {
			const result = [];
			for (const v of [leftOsdLoader.item, rightOsdLoader.item]) {
				if (v) for (const loader of v.instances) if (loader.item) result.push(loader.item);
			}
			return result;
		}
		function state(): string { return JSON.stringify(_windows().map(w => w.stateObject())); }
		function showVolume(): string { _windows().filter(w => w.edge === "left").forEach(w => w.show()); return "ok"; }
		function showBrightness(): string {
			return _windows().filter(w => w.edge === "right").some(w => w.show()) ? "ok" : "backlight unavailable";
		}
	}
	IpcHandler {
		target: "notifications"
		function state(): string { return JSON.stringify(notificationsLoader.item?.stateObject() ?? null); }
		function openHistory(): string { return notificationsLoader.item?.openHistory() ?? "notifications disabled"; }
		function closeHistory(): string { return notificationsLoader.item?.closeHistory() ?? "notifications disabled"; }
		function markRead(): string { return notificationsLoader.item?.markRead() ?? "notifications disabled"; }
		function clear(): string { return notificationsLoader.item?.clear() ?? "notifications disabled"; }
		function dismiss(id: int): string { return notificationsLoader.item?.dismiss(id) ?? "notifications disabled"; }
		function action(id: int, identifier: string): string { return notificationsLoader.item?.invoke(id, identifier) ?? "notifications disabled"; }
		function historyAction(key: string, id: int, identifier: string): string { return notificationsLoader.item?.invokeHistory(key, id, identifier) ?? "notifications disabled"; }
	}

	IpcHandler {
		target: "updates"

		function state(): string {
			return JSON.stringify({ available: Updates.available, count: Updates.count, installed: Updates.installed, checking: Updates.checking });
		}

		// Checks now (after an upgrade, the dot would otherwise wait an hour).
		function check(): string {
			Updates.check();
			return "ok";
		}
	}

	IpcHandler {
		target: "notch"

		function _windows() {
			const variants = notchLoader.item;
			return variants ? variants.instances.map(loader => loader.item).filter(Boolean) : [];
		}

		// One state object per screen, in screen order.
		function state(): string {
			return JSON.stringify(_windows().map(w => w.view.stateObject()));
		}

		// Shows a hidden notch for `ms` milliseconds, as Bloom's event peek.
		function peek(ms: int): string {
			_windows().forEach(w => w.view.peek(ms));
			return "ok";
		}

		// Opens Bloom's music player (as a click on the art) on the focused
		// monitor, or the first screen when Hyprland can't say which that is.
		function openMusic(): string {
			const windows = _windows();
			const focused = HyprState.monitors.find(m => m.focused)?.name ?? "";
			const onFocused = windows.filter(w => w.modelData.name === focused);
			(onFocused.length ? onFocused : windows.slice(0, 1)).forEach(w => w.view.openMusic());
			return "ok";
		}
		function openPanel(name: string): string {
			const windows = _windows();
			const focused = HyprState.monitors.find(m => m.focused)?.name ?? "";
			const target = windows.find(w => w.modelData.name === focused) ?? windows[0];
			return target ? target.view.openPanel(name) : "notch disabled";
		}
		function closePanel(): string { _windows().forEach(w => w.view.closePanel()); return "ok"; }
		function nextPanel(): string { const w = _windows()[0]; return w ? w.view.cyclePanel(1) : "notch disabled"; }
		function previousPanel(): string { const w = _windows()[0]; return w ? w.view.cyclePanel(-1) : "notch disabled"; }

		// Bloom's visibility toggle.
		function setVisible(visible: bool): string {
			_windows().forEach(w => w.view.userVisible = visible);
			return "ok";
		}
	}

	IpcHandler {
		target: "devices"

		// What the device alerts and Connected devices see now.
		function state(): string {
			return JSON.stringify({
				alert: Devices.alert,
				usb: Devices.usb,
				wired: Devices.wired,
				bluetooth: Bluetooth.devices.map(d => ({ name: d.name, kind: d.kind, paired: d.paired, connected: d.connected, battery: d.battery }))
			});
		}
	}

	// The Wi-Fi panel's service. Passwords are never taken here: IPC
	// arguments show in the process list.
	IpcHandler {
		target: "wifi"

		function state(): string {
			return JSON.stringify({ enabled: Network.wifiEnabled, ssid: Network.ssid, scanning: Network.scanning,
				busy: Network.busy, error: Network.lastError, networks: Network.networks });
		}
		// Keeps the service watching without a panel open (scripts, tests).
		function hold(wanted: bool): string { Network.hold("ipc", wanted); return "ok"; }
		function scan(): string { Network.refresh(true); return "ok"; }
		function connect(ssid: string): string { return Network.connect(ssid, ""); }
		function disconnect(ssid: string): string { return Network.disconnect(ssid); }
		function forget(ssid: string): string { return Network.forget(ssid); }
	}

	// The Bluetooth panel's service: devices by path.
	IpcHandler {
		target: "bluetooth"

		function state(): string {
			const brief = d => ({ path: d.path, name: d.name, kind: d.kind, connected: d.connected, battery: d.battery });
			return JSON.stringify({ powered: Bluetooth.powered, discovering: Bluetooth.discovering, lookFailed: Bluetooth.lookFailed, busy: Bluetooth.busy,
				pairing: Bluetooth.pairing, prompt: Bluetooth.prompt, error: Bluetooth.lastError,
				paired: Bluetooth.paired.map(brief), nearby: Bluetooth.nearby.map(brief) });
		}
		function hold(wanted: bool): string { Bluetooth.hold("ipc", wanted); return "ok"; }
		function discover(wanted: bool): string { return Bluetooth.discover(wanted); }
		function pair(path: string): string { return Bluetooth.pair(path); }
		function respond(accept: bool, pin: string): string { return Bluetooth.respond(accept, pin); }
		function unpair(path: string): string { return Bluetooth.unpair(path); }
		function connect(path: string, wanted: bool): string { return Bluetooth.setConnected(path, wanted); }
	}

	IpcHandler {
		target: "launcher"

		function toggle(): string { Launcher.toggle(); return "ok"; }
		function close(): string { Launcher.hide(); return "ok"; }
		function search(text: string): string { Launcher.setQuery(text); return "ok"; }
		function accept(index: int): string { return Launcher.accept(Launcher.results[index]); }
		function state(): string {
			return JSON.stringify({ opened: Launcher.opened, query: Launcher.query, results: Launcher.results.map(r => ({ id: r.id, name: r.name, sub: r.sub })) });
		}
	}

	IpcHandler {
		target: "session"

		function toggle(): string { Session.toggle(); return "ok"; }
		function close(): string { Session.hide(); return "ok"; }
		function run(action: string): string { return Session.run(action); }
		function state(): string { return JSON.stringify({ opened: Session.opened, busy: Session.busy }); }
	}

	IpcHandler {
		target: "overview"

		function toggle(): string { Overview.toggle(); return "ok"; }
		function close(): string { Overview.hide(); return "ok"; }
		function move(address: string, workspace: int): string { return Overview.moveWindow(address, workspace); }
		function state(): string {
			return JSON.stringify({ opened: Overview.opened, activeWorkspace: Overview.activeWorkspace, windows: Overview.clients.length });
		}
	}

	// The agent's state, never what's typed: passwords don't come through IPC.
	IpcHandler {
		target: "performance"

		function state(): string { return JSON.stringify({ mode: Performance.mode, lowPower: Performance.lowPower }); }
	}

	IpcHandler {
		target: "region"

		function run(action: string): string {
			if (_modules.indexOf("regiontools") < 0) return "off";
			if (["screenshot", "annotate", "ocr", "record", "record-audio"].indexOf(action) < 0) return "unknown action";
			Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/region.sh"), action]);
			return "ok";
		}
	}

	IpcHandler {
		target: "wallpaper"

		function set(path: string): string { Wallpaper.set(path); return "ok"; }
		function toggle(): string { Wallpaper.toggle(); return "ok"; }
		function random(): string { Wallpaper.random(); return "ok"; }
		function close(): string { Wallpaper.hide(); return "ok"; }
		function state(): string {
			return JSON.stringify({ path: Wallpaper.path, opened: Wallpaper.opened, items: Wallpaper.items.length, accent: Wallpaper.accent });
		}
	}

	IpcHandler {
		target: "cheatsheet"

		function toggle(): string { Cheatsheet.toggle(); return "ok"; }
		function close(): string { Cheatsheet.hide(); return "ok"; }
		function state(): string {
			return JSON.stringify({ opened: Cheatsheet.opened, groups: Cheatsheet.groups.length, binds: Cheatsheet.groups.reduce((n, g) => n + g.binds.length, 0) });
		}
	}

	IpcHandler {
		target: "lock"

		function lock(): string {
			if (!lockLoader.active) return "off";
			lockLoader.item.lock();
			return "ok";
		}
		function state(): string {
			// As with polkit: never load it just to report that it's off.
			return JSON.stringify(lockLoader.active ? lockLoader.item.status() : { enabled: false, locked: false });
		}
	}

	IpcHandler {
		target: "polkit"

		function state(): string {
			// A LazyLoader's `item` loads it: never read it while it's off, or a
			// status call would register an agent beside ii's.
			const surface = polkitLoader.active ? polkitLoader.item : null;
			return JSON.stringify({ enabled: polkitLoader.active, registered: surface?.registered ?? false, active: surface?.active ?? false });
		}
	}

	IpcHandler {
		target: "dock"

		function _windows() {
			const variants = dockLoader.item;
			return variants ? variants.instances.map(loader => loader.item).filter(Boolean) : [];
		}

		// One state object per screen, in screen order.
		function state(): string {
			return JSON.stringify(_windows().map(w => Object.assign(w.view.stateObject(), { pinned: Dock.pinned, icons: Dock.icons, toast: Dock.toast, toastSerial: Dock.toastSerial })));
		}

		// `id` is a desktop entry id (as in its .desktop file name).
		function pin(id: string): string {
			return Dock.pin(id);
		}

		function unpin(id: string): string {
			return Dock.unpin(id);
		}

		function setIcon(id: string, path: string): string {
			return Dock.setIcon(id, path);
		}

		// Opens the file picker for `id`'s icon, as "Change Icon..." does.
		function pickIcon(id: string): string {
			if (Dock.pinned.indexOf(id) < 0)
				return "not pinned";
			Dock.pickIcon(id);
			return "ok";
		}

		function resetIcon(id: string): string {
			return Dock.resetIcon(id);
		}

		function reorder(ids: string): string {
			let list;
			try {
				list = JSON.parse(ids);
				if (typeof list === "string") list = JSON.parse(list);
			} catch (e) { return "ids must be a JSON array"; }
			return Array.isArray(list) ? Dock.reorder(list) : "ids must be a JSON array";
		}

		// Pinned app `n` (1-based), as Super+Alt+n.
		function activate(n: int): string {
			return Dock.activateSlot(n);
		}

		function setVisible(visible: bool): string {
			_windows().forEach(w => w.view.userVisible = visible);
			return "ok";
		}
	}
}
