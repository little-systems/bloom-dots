import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
    property var initialValues: Settings.values
    property bool started: false
    readonly property string role: Quickshell.env("BLOOM_WRITER_ROLE")
    FileView {
        id: gate
        path: Quickshell.env("BLOOM_WRITER_GATE")
        printErrors: false
        onLoaded: {
            if (started || text().trim() !== "go") return;
            started = true;
            const key = role === "a" ? "bloom-weather-city" : "bloom-theme-opacity";
            Settings.set(key, role === "a" ? "Concurrent City" : 0.7, error => {
                console.log("RESULT writer=" + role + " committed=" + (error === ""));
                Qt.exit(error === "" ? 0 : 1);
            });
        }
    }
    Timer { interval: 300; running: true; onTriggered: console.log("READY " + role) }
    Timer { interval: 50; repeat: true; running: !started; onTriggered: gate.reload() }
}
