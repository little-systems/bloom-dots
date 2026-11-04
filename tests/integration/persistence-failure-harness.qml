import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    StateFile { id: state; name: "failure"; defaultValue: ({ initial: true }) }
    Timer {
        interval: 500
        running: true
        onTriggered: {
            Settings.set("bloom-theme-mode", "light", error => {
                console.log("RESULT settings-refused=" + (error !== "") + " settings-kept=" + (Settings.values["bloom-theme-mode"] === "dark"));
                finish.start();
            });
            state.save({ changed: true });
            const invalidBatch = Settings.setMany({ "bloom-theme-mode": "custom", "bloom-theme-opacity": 9 });
            console.log("RESULT batch-atomic=" + (invalidBatch !== "" && Settings.values["bloom-theme-mode"] === "dark"));
        }
    }
    Timer {
        id: finish
        interval: 300
        onTriggered: {
            console.log("RESULT state-error=" + (state.error !== "") + " pending=" + state._hasPending);
            if (Quickshell.env("BLOOM_TEST_RETRY") === "1") repair.running = true;
            else Qt.exit(0);
        }
    }
    Process {
        id: repair
        command: ["chmod", "700", Quickshell.env("XDG_CONFIG_HOME") + "/bloom", Quickshell.env("XDG_STATE_HOME") + "/bloom"]
        onExited: code => {
            if (code !== 0) { Qt.exit(1); return; }
            state.retry();
            Settings.setMany({ "bloom-theme-mode": "light", "bloom-theme-opacity": 0.7 }, error => {
                if (error !== "") { Qt.exit(1); return; }
                retried.start();
            });
        }
    }
    Timer {
        id: retried
        interval: 300
        onTriggered: {
            const ok = state.error === "" && !state._hasPending && state.value.changed === true;
            console.log("RESULT retry=" + ok);
            Qt.exit(ok ? 0 : 1);
        }
    }
}
