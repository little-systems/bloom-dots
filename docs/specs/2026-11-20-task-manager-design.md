# Default task manager

Owner request (2026-11-20): a new default app, the task manager. Bloom bundles
Mission Center and sets it as the default. It opens from the dock's
right-click menu, Ctrl+Shift+Esc and the Command Center (owner's choices).

## Decisions

- **Setting:** `bloom-task-manager`, a desktop id, default
  `io.missioncenter.MissionCenter`. A task manager has no MIME type, so this
  is Bloom's own setting rather than an `xdg-mime` default.
- **Settings › Apps › Default apps:** a "Task manager" row after the six MIME
  rows. Its choices are installed, visible apps in the desktop `Monitor`
  category (Mission Center, htop, …), plus the current value if it isn't one.
- **Packaging:** `mission-center` (Arch `extra`) joins `bloom-shell-deps`.
- **Opening:** one `TaskManager.open()`. It runs the chosen app if it is
  installed, else the first installed `Monitor` app, else posts a notification
  that none is installed. Entry points:
  - the dock's empty-area menu: "Task Manager" first, above Add App (Bloom's
    taskbar menu lists it first too);
  - Ctrl+Shift+Esc in `hypr/desktop.lua`, through `bloom ipc taskmanager open`;
  - a Command Center round button (Lucide `activity`) between Restart and
    Settings; the row goes from five to six evenly spaced buttons.
- **Text:** Bloom's `ui.dock.taskManager` ("Task Manager") for the menu and
  button; ours for the Settings label and the notification.

The Command Center button and the dock entry are deliberate additions at the
owner's request; Bloom for Windows has no Command Center task manager button.

## Tests

- Pure choice logic: the chosen app, the fallback, none installed; the choice
  list (Monitor category, hidden entries skipped, current kept).
- Schema default; Settings row shows the choices and writes the setting.
- Dock background menu lists Task Manager first and runs it.
- Command Center button emits its request.
- Integration: `bloom ipc taskmanager open` launches a stub task manager
  installed in a throwaway XDG data dir.
