//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Bloom shell root. Phase 1 has no surfaces yet: it loads the core services
// and exposes the IPC interface used by `bloom ipc` and keybinds.
ShellRoot {
	Component.onCompleted: console.log(`bloom: shell started (theme ${Theme.mode}, settings ${Settings.path})`)

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
			let parsed;
			try {
				parsed = JSON.parse(value);
			} catch (e) {
				parsed = value;
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
}
