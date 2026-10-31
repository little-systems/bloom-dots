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
