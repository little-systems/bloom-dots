import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "modules/wallpaper"
ShellRoot {
    PickerWindow { id: picker; modelData: Quickshell.screens[0] }
    IpcHandler {
        target: "picker"
        function reveal(): string { Wallpaper.show(); return "ok"; }
        function pickFile(): string { picker.chooseFile(); return "ok"; }
        function pickFolder(): string { picker.chooseFolder(); return "ok"; }
        function state(): string { return JSON.stringify({ dialog: picker.dialogOpen, visible: picker.visible, path: Wallpaper.path, folder: Wallpaper.folder, opened: Wallpaper.opened, error: Wallpaper.error }); }
    }
}
