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
            const err = Settings.set("bloom-theme-mode", "light");
            state.save({ changed: true });
            console.log("RESULT settings-refused=" + (err !== "")
                + " settings-kept=" + (Settings.values["bloom-theme-mode"] === "dark"));
            finish.start();
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
            const err = Settings.set("bloom-theme-mode", "light");
            if (err !== "") { Qt.exit(1); return; }
            retried.start();
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
