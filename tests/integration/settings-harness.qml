import QtQuick
import Quickshell
import qs.services
// Completion, rather than a queued receipt, is the durable acknowledgment.
ShellRoot {
    property int durable: 0
    property var modes: ["light", "dark", "custom", "light", "dark"]
    function next() {
        if (durable === modes.length) { console.log("RESULT durable=5/5"); Qt.exit(0); return; }
        const mode = modes[durable];
        Settings.set("bloom-theme-mode", mode, error => {
            const xhr = new XMLHttpRequest();
            xhr.open("GET", "file://" + Settings.path, false); xhr.send();
            if (error !== "" || JSON.parse(xhr.responseText)["bloom-theme-mode"] !== mode) { Qt.exit(1); return; }
            durable++; Qt.callLater(next);
        });
    }
    Timer { interval: 300; running: true; onTriggered: next() }
}
