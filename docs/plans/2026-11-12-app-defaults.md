# App defaults after ii (2026-11-12)

The owner removed ii and asked for everything ii's app configs gave that
Bloom lacks (audit of ii's dotfiles, 2026-11-12). Bloom's own versions, no ii
code. Each item lands as its own commit with targeted tests.

1. **Idle and lock.** Bloom runs hypridle with its own generated config while
   the lock module is on: lock after 5 min, screen off at 10, sleep at 15
   (Settings › General › Lock Screen; "Never" turns each off), and it locks
   before sleep. This also answers `loginctl lock-session`, which the session
   menu's Lock uses.
2. **Theme output in Bloom's own places.** kitty's colours go to
   `~/.config/kitty/bloom-theme.conf`, Hyprland's border colours to
   `~/.config/hypr/custom/bloom-colors.lua` (loaded by Bloom's integration);
   no more files in ii's folders and no fuzzel theme.
3. **kitty defaults.** `kitty/bloom.conf` (JetBrains Mono Nerd Font, padding,
   beam cursor with trail, copy-or-interrupt on Ctrl+C, scrollback on Ctrl+F,
   font size keys, Bloom's colours) is included first from `kitty.conf`, so
   the user's own lines win. Installed and removed like the Hyprland loader.
4. **Session environment and integration packages.** Qt apps use the KDE
   platform theme (Bloom's `kdeglobals` colours, icons), KDE apps get an
   application menu (`XDG_MENU_PREFIX=arch-`), Electron apps run on Wayland,
   and the cursor is Adwaita. The Qt platform theme also gives the shell its
   icon theme: without it the dock extras (folders, Trash, drives) had no
   icons. Packages: plasma-integration, archlinux-xdg-menu,
   xdg-desktop-portal-kde, ttf-jetbrains-mono-nerd.
5. **Floating dialogs.** Open/Save/upload dialogs, portal pickers, the volume
   mixer and network/Bluetooth editors float, centred.
6. **App defaults copied once** (kept if the user has their own): Chromium,
   Chrome, VS Code and Electron flags (Wayland, keyring password store,
   Wayland input methods, touchpad history swipe), the KDE file picker for
   portals, mpv keeps the window open at the end, Dolphin shows full paths.
7. **Lock and unlock leave the screen black** (owner report). Unlocking must
   bring the desktop back as designed: the lock fades out over the live
   desktop, panels and wallpaper intact.

Left out on purpose: Kvantum/Darkly/material-you (Bloom themes Qt itself),
wlogout and fuzzel (Bloom has its own), shell prompts and fish/zsh/foot
(personal), font smoothing (taste), geoclue (nothing needs location).
