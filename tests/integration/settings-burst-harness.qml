import QtQuick
import Quickshell
import qs.services
ShellRoot {
    property int completed: 0
    property bool failed: false
    Timer {
        interval: 300; running: true
        onTriggered: {
            for (const value of [0.5, 0.6, 0.7, 0.8, 0.9]) {
                Settings.set("bloom-theme-opacity", value, error => {
                    if (error !== "") { failed = true; console.log("RESULT burst error=" + error); }
                    completed++;
                    if (completed === 1) throw new Error("disposed control fixture");
                    if (completed === 5) {
                        const ok = !failed && Settings.values["bloom-theme-opacity"] === 0.9;
                        console.log("RESULT burst-committed=" + ok);
                        Qt.exit(ok ? 0 : 1);
                    }
                });
            }
        }
    }
}
