# Phase 7 wallpaper switch

**Status:** done on 2026-10-31 with the owner's OK. Backups: `~/Projects/bloom-wallpaper-handover-20261031-213122` and `~/Projects/bloom-settings.backup-20261031-213122.json`.

ii draws the wallpaper today on the bottom layer. Bloom's layer sits there too, so ii's has to stop mapping or a restart of ii would put it back on top.

## Steps

```bash
BACKUP=~/Projects/bloom-wallpaper-handover-$(date +%Y%m%d-%H%M%S)
scripts/phase7-ii-wallpaper.sh apply ~/.config/quickshell/ii ~/dots-hyprland/dots/.config/quickshell/ii "$BACKUP"
```

1. Back up `~/.config/bloom/settings.json`, add `wallpaper` to `bloom-enabled-modules`, set `bloom-wallpaper` to the current wallpaper, and restart `bloom-shell`.
2. Restart ii: `pkill -f '^qs -c ii$'`. The watchdog brings it back within 5 seconds.
3. Check the picture hasn't moved, and open the picker: `qs -c bloom ipc call wallpaper toggle`.

Bloom's layer goes up first, so the screen never shows bare black.

## Rollback

Remove `wallpaper` from the modules, restart `bloom-shell`, then:

```bash
scripts/phase7-ii-wallpaper.sh restore ~/.config/quickshell/ii ~/dots-hyprland/dots/.config/quickshell/ii "$BACKUP"
```

Restart ii the same way. Nothing here affects the lock screen's ability to unlock: without a wallpaper it shows solid black.
