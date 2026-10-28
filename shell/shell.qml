//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "modules/notch"
import "modules/dock"

// Bloom shell root: loads the core services, the surfaces enabled in
// bloom-enabled-modules, and the IPC interface used by `bloom ipc` and keybinds.
ShellRoot {
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
