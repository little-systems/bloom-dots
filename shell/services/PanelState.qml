pragma Singleton
import QtQuick
import Quickshell

// One remembered tool panel across monitors and restarts; live activities are
// never written here.
Singleton {
	id: root
	property string lastPanel: "calendar"

	function remember(panel) {
		if (["calendar", "command-center", "devices"].indexOf(panel) < 0) return;
		root.lastPanel = panel;
		state.save({ lastPanel: panel });
	}

	StateFile {
		id: state
		name: "notch-panel"
		defaultValue: ({ lastPanel: "calendar" })
		validate: v => v !== null && typeof v === "object" && !Array.isArray(v) ? v : undefined
		maxBytes: 4096
		onLoadedChanged: if (loaded) restore()
		onExternallyChanged: restore()
		function restore() {
			if (["calendar", "command-center", "devices"].indexOf(value?.lastPanel) >= 0)
				root.lastPanel = value.lastPanel;
		}
	}
}
