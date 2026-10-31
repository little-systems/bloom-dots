# Phase 7: Theming and extras

**Goal:** the cheatsheet, low-power mode, region tools, Bloom's own wallpaper with a picker and the Adaptive theme, and the settings app.

**Spec:** `docs/specs/2026-10-25-bloom-shell-design.md` (D9, D10, §3.4, §4, §8).

Windows Bloom has these only in part, so as in Phase 6, "1:1" here means Bloom's language. The settings app is the exception: Bloom has one, so it's measured against Bloom.

## Global constraints

Phase 6's apply: no ii code, nothing under `~/.config` or `~/dots-hyprland` without the owner's OK and a backup, tests never touch the real session, every external tool checked on the real machine, new modules opt-in.

## Order

Lowest risk first.

- **7A Cheatsheet:** generated from `hyprctl binds -j` descriptions, grouped by their `Group: text` prefix. Replaces `Super+/` once the owner OKs the rebind.
- **7B Low-power mode:** turns off the album-art glow and blur, throttles live thumbnails, keeps springs. Suggested on battery, can be forced on.
- **7C Region tools:** region and window selector over grim and slurp, OCR through tesseract, recording through wf-recorder, annotation through satty or swappy, whichever is installed (only swappy is here today).
- **7D Wallpaper and Adaptive:** ii draws the wallpaper today and no daemon is running, so Bloom needs its own background layer first. This is a handover like polkit, with a rollback. Then the picker (static, video through mpvpaper) and the matugen pipeline: shell, GTK3/4, Qt, kitty, fuzzel, Hyprland borders. The lock screen then stops reading ii's config.
- **7E Settings app:** a separate process, Bloom's tabbed window with live previews, import, export, reset and "needs X" hints. Last, so it covers every setting above.

## 7F: System settings (owner request, 2026-10-31)

The settings app becomes the desktop's Settings, shown in the launcher as "Settings" with Bloom's logo, and covers what Windows Settings does. Owner decisions: one grouped sidebar, Windows-style sections first and Bloom's own tabs under a Bloom heading; every area in the first round; Selawik for text, since Segoe UI can't ship.

Pages, each built on the existing `S*` controls and tested with fake tools:

- **System:** Display (`hyprctl monitors`, mode, scale, night light through hyprsunset), Sound (`wpctl`: outputs, inputs, per-app volume), Power and battery (`powerprofilesctl`, battery status), Storage (`df`), About (`hostnamectl`, kernel, hardware).
- **Network and Bluetooth:** reuse the `Network` and `Bluetooth` services the notch panels use.
- **Input:** keyboard layouts and repeat, touchpad, mouse, through Hyprland config.
- **Hyprland:** gaps, borders, rounding, blur, animations, keybind list.
- **Apps:** default apps (`xdg-mime`), startup apps, installed apps.
- **Time and language:** `timedatectl`, `localectl`.
- **Updates:** `checkupdates`, with the terminal for anything needing a password.

Rules: never enter a password. Anything needing root hands off to polkit through the tool's own prompt, or opens a terminal. Hyprland changes go in one Bloom-owned file (`~/.config/hypr/custom/bloom-settings.lua`), required once, so the owner's own files stay untouched and a mistake can be undone by removing one line. Tests never run real power, network or display commands.
