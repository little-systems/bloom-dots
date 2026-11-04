import QtQuick
import Quickshell
import "settings"
ShellRoot {
    SystemStore { id: store }
    property bool requested: false
    property bool confirmed: false
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (!requested && store.hyprLoaded && store.monitors.length) {
                requested = true;
                store.setMonitor(store.monitors[0], "1280x720@60", 1.25);
            }
            if (store.pendingDisplay && !store.displayBusy && !confirmed && Quickshell.env("BLOOM_DISPLAY_TEST_ACTION") === "keep") {
                confirmed = true;
                store.keepDisplay();
            }
        }
    }
}
