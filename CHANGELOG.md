# Changelog

## 1.2.0 (2026-11-21)

Window management for Bloom: float or tile every window at once, switch with
Alt + Tab or a three-finger swipe, and floating windows that remember where
they were.

### Windows
- Super + Alt + Space floats every window on every workspace, and the next
  press tiles them back. Windows that open meanwhile float too; dialogs keep
  their own.
- A floated window opens at the size and place its app last had, or at
  1280 x 800 in the middle, and windows floated together are nudged apart.
- Float or tile all keeps track of its windows through a Hyprland reload and
  through apps that hide to the tray, such as Spotify.
- Alt + Tab switches between the windows on the workspace, most recent
  first. Tiled windows take focus as you go; floating ones get a card of live
  previews.
- A three-finger swipe goes back to the last window. Hold it to show the
  card, starting on the window you're in, and move right or left to step.
- A grab handle on the top edge of floating windows that draw no title bar,
  such as Spotify.

### Desktop
- A default task manager, Mission Center, on Ctrl + Shift + Esc, the dock's
  menu and a Command Center button; choose another in Settings.
- Card shadows no longer show a hard band, and the background blur fades
  with cards as they open and close.
- Bloom surfaces stay at least 60% opaque.

### Settings, Search and the guide
- Settings opens at once: it's ready from login, and each tab loads when
  you open it.
- Typing in Search ignores the mouse until it moves, so the selection stays
  put.
- The first-run guide shows where notifications live.

### The Dock
- Tray icons stay with the app whose window showed them, and never go to an
  app that didn't.
- Add App's keyboard highlight shows again.

## 1.1.0 (2026-11-18)

Bloom 3.10.2's new features come to Linux, along with agent live activities,
a first-run guide, Bloom's languages, and a dock that pairs tray icons with
their apps.

### Agents on the Island
- Live activities for Claude Code, Codex and OpenCode: what the agent is
  doing, how long it has been working, and an alert when it needs you.
- Connect each agent from Settings in two steps. Nothing leaves your machine.
- A turn you interrupt or rewind in Claude Code clears from the Island too.

### The Dock
- Tray icons join the app that owns them. A pinned app that is only in the
  tray shows a gray dot, and clicking it brings its window back.
- An unpinned app that you closed to the tray stays in the dock with its own
  icon. Show Background Apps hides these without changing pinned apps.
- The right-click menu has App options (the app's tray menu) and Quick
  actions (its launcher shortcuts), at one fixed width with dividers.
- Bloom's Settings icon.

### The Island
- Shelf drops and activity pills from Bloom 3.10.2.
- The calendar browses months and can start weeks on Monday.
- Mute and dim from the Command Center slider icons.
- The timer accepts m:ss.

### First run and languages
- A first-run guide that applies your choices live and can be replayed from
  Settings.
- Choose Bloom's language in Settings. The Island, Dock, Search, Settings and
  the rest of the desktop use Bloom's translations, falling back to English.

### Desktop
- Rounded screen corners, kept while locked; on by default.
- Reflective edge shine, with a switch in Appearance.
- Windows move on Bloom's springs, a lone window fills its workspace, and
  Reduce Motion turns window animations off too.
- Bloom's terminal: prompt, fastfetch with the Bloom logo and one blurred
  kitty palette.
- Twemoji is Bloom's emoji and Bibata Modern Classic its cursor everywhere.
- The installer can place Bloom in your account from a clone made anywhere.
- Settings credits the authors on its About page.

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
