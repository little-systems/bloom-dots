import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
ShellRoot {
    FileView { id: editor; path: Settings.path; blockWrites: true; atomicWrites: true }
    function finish(error) {
        editor.reload(); editor.waitForJob();
        const disk = JSON.parse(editor.text());
        const ok = error === "" && disk["external-owner-key"] === "preserved"
            && disk["bloom-weather-enabled"] === false && disk["bloom-theme-mode"] === "light";
        console.log("RESULT external-edit-preserved=" + ok);
        Qt.exit(ok ? 0 : 1);
    }
    Timer {
        running: true; interval: 300
        onTriggered: {
            // Simulate an editor committing after our cache was loaded, before
            // its watcher event can run. A whole cached snapshot loses this edit.
            editor.setText(JSON.stringify({ "bloom-theme-mode": "dark", "bloom-weather-enabled": false, "external-owner-key": "preserved" }));
            const result = Settings.set("bloom-theme-mode", "light", error => finish(error));
            if (result === "") finish(""); // old synchronous implementation
        }
    }
}
