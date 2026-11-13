# Changelog

## 1.0.0 (2026-11-13)

The first release of Bloom for Linux: the official Bloom desktop shell and
dotfiles for Arch Linux and Hyprland, built with Quickshell. It is a complete
desktop on its own, and it can also run beside illogical-impulse.

### The Island
- A notch with Bloom's look and motion, in Fixed, Smart or Peek mode.
- Music with album art, playback controls and an audio visualizer.
- Command Center: Wi-Fi, Bluetooth, power profiles, Do Not Disturb, volume
  and brightness, with device alerts and privacy indicators.
- Status, weather, calendar with a focus timer and todos, and the Shelf for
  files and text.

### The Dock
- Pinned and running apps, drag to reorder, custom icons and app actions.
- Live window previews, a workspace segment, the system tray and dock extras
  (folders, Trash, drives).
- Fixed, Smart and Peek modes.

### The rest of the desktop
- Search: apps, files, windows, calculator, web, clipboard history, emoji and
  AI chat (with your own key, kept in your keyring).
- Notifications as corner cards with history.
- Lock screen that fades over the live desktop, session menu, polkit
  prompts, workspace overview and a keybinding cheatsheet.
- Idle handling: lock, screen off and sleep after times you choose, and a
  lock before sleep.
- Screenshots, annotation, OCR, translation, screen recording, a wallpaper
  picker, an on-screen keyboard and a widget overlay.
- Bloom Settings for display, sound, power, network, Bluetooth, input,
  appearance and every Bloom surface.

### Theming
- Dark, Light, Custom and Adaptive (from the wallpaper) themes that also
  colour GTK and Qt apps, kitty and Hyprland's window borders.
- Light and dark Bloom wallpapers, and a Bloom login screen (SDDM) that
  follows the desktop's wallpaper and colours.

### Install, update, uninstall
- One command installs everything Bloom needs, from a fresh archinstall
  chroot or on a system you already use; `--dry-run` shows the plan first.
- Without another shell, Bloom is the whole desktop: its own Hyprland setup
  and shortcuts, a terminal, file manager, browser, text editor, image viewer
  and video player, and sensible app defaults copied only where you have
  none.
- `bloom update` checks the new version before switching and rolls back if
  it isn't healthy; `bloom uninstall` puts back what was there before.
- `bloom doctor` checks the shell, services, login screen, keyring and
  more, and says how to fix what it finds.

### Requirements
Arch Linux with Hyprland 0.56 or newer (Lua configuration). Bloom installs
Quickshell, Hyprland and its other packages itself; you need `git`.
