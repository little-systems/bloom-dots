import QtQuick
import Quickshell
import Quickshell.Io
import "settings"
ShellRoot {
    SystemStore { id: store }
    property bool requested: false
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (!requested && store.hyprLoaded) { requested = true; store.setHypr("general.gaps_in", 8); }
            if (requested) saved.reload();
        }
    }
    FileView {
        id: saved
        path: Quickshell.env("XDG_CONFIG_HOME") + "/hypr/custom/bloom-settings.lua"
        printErrors: false
        onLoaded: {
            const line = text().split("\n")[1] || "";
            if (!line.startsWith("-- bloom-state-v1 ")) return;
            const state = JSON.parse(line.slice("-- bloom-state-v1 ".length)).state;
            const ok = state.hypr.general.gaps_in === 8 && text().includes("hl.config({ general = { gaps_in = 8 } })");
            console.log("RESULT compositor-committed=" + ok);
            Qt.exit(ok ? 0 : 1);
        }
    }
}
