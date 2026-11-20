import QtQuick
import Quickshell
import "settings"
// Settings starts its queries after the first frame: a store told not to
// auto-start runs nothing until start().
ShellRoot {
    SystemStore { id: store; autoStart: false }
    property bool asked: false
    Timer {
        interval: 1500; running: true
        onTriggered: {
            console.log("RESULT idle=" + (!store.started && store.disks.length === 0));
            asked = true;
            store.start();
        }
    }
    Timer {
        interval: 100; running: asked; repeat: true
        onTriggered: if (store.started && store.disks.length > 0) { console.log("RESULT started=true"); Qt.exit(0); }
    }
}
