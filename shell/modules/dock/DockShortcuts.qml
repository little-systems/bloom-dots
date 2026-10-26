import QtQuick
import Quickshell.Hyprland
import qs.services

// Super+Alt+1–9 (D12) as Hyprland global shortcuts bloom:dock-1…9, bound in
// the Hyprland config. In its own file so the Hyprland module is only
// touched under Hyprland.
Item {
	Repeater {
		model: 9

		Item {
			required property int index

			GlobalShortcut {
				appid: "bloom"
				name: "dock-" + (index + 1)
				description: "Bloom dock: activate pinned app " + (index + 1)
				onPressed: Dock.activateSlot(index + 1)
			}
		}
	}
}
