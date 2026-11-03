import QtQuick
import Quickshell
import qs.services

ShellRoot {
    StateFile { id: state; name: "noop"; defaultValue: ({ entries: [] }) }
    Timer {
        interval: 300; running: true
        onTriggered: { state.save({ entries: [1] }); change.start(); }
    }
    Timer {
        id: change; interval: 200
        onTriggered: { state.save({ entries: [] }); finish.start(); }
    }
    Timer { id: finish; interval: 300; onTriggered: Qt.exit(0) }
}
