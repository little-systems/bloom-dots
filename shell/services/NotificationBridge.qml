pragma Singleton
import Quickshell

// Small signal bridge between the always-available notch and the optional
// notification module. Importing it never claims the notification bus.
Singleton {
	property int unread: 0
	signal historyRequested()
	function openHistory() { historyRequested(); }
}
