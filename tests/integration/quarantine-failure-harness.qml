import QtQuick
import Quickshell
import qs.services
ShellRoot {
    StateFile {
        id: state
        name: "failure"
        defaultValue: ({})
        onLoadedChanged: if (loaded) save({ changed: true })
    }
    Timer {
        interval: 500
        running: true
        onTriggered: {
            const ok = state.error !== "" && state._quarantineNeeded && state._hasPending;
            console.log("RESULT quarantine-blocked=" + ok);
            Qt.exit(ok ? 0 : 1);
        }
    }
}
