import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// The polkit agent and its dialog on each screen. Loaded only when `polkit`
// is in bloom-enabled-modules: only one agent can register, so tests never
// load this file, and ii must have given its agent up first.
Scope {
	id: root

	readonly property bool registered: agent.isRegistered
	readonly property bool active: agent.isActive

	PolkitAgent { id: agent }

	Variants {
		model: Quickshell.screens
		delegate: PolkitWindow {
			required property var modelData
			screenData: modelData
			agent: agent
		}
	}
}
