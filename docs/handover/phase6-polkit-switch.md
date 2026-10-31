# Phase 6 polkit switch

**Status:** waiting for the owner's OK. Nothing here has been run on the live system.

Only one polkit agent can register per session, so ii's has to go before Bloom's starts.

## The change

- `docs/handover/ii-polkit-optout.patch`: one file, `services/PolkitService.qml`. ii keeps its polkit UI code, but its `PolkitAgent` loads only when `bloomOwnsPolkit` is false.
- `scripts/phase6-ii-polkit.sh`: patches both ii roots, backs up first, refuses to run if the patch doesn't fit exactly.
- `~/.config/bloom/settings.json`: `polkit` added to `bloom-enabled-modules`, backup first.

## Steps

```bash
BACKUP=~/Projects/bloom-polkit-handover-$(date +%Y%m%d-%H%M%S)
scripts/phase6-ii-polkit.sh apply ~/.config/quickshell/ii ~/dots-hyprland/dots/.config/quickshell/ii "$BACKUP"
```

1. Restart ii: `pkill -x qs -f '^qs -c ii$'`. The watchdog loop in the session starts it again within 5 seconds.
2. Add `polkit` to the modules and restart `bloom-shell`.
3. `qs -c bloom ipc call polkit state` must read `"enabled":true,"registered":true`.
4. The owner runs `pkexec true` and types the password into Bloom's dialog. Also try a wrong password once, and Cancel once.

Between steps 1 and 2 no agent is running, so any polkit prompt in that window fails with an error. It doesn't hang.

## Rollback

Remove `polkit` from the modules, restart `bloom-shell`, then:

```bash
scripts/phase6-ii-polkit.sh restore ~/.config/quickshell/ii ~/dots-hyprland/dots/.config/quickshell/ii "$BACKUP"
```

Restart ii the same way. If the desktop is unusable, run the same commands from a TTY (Ctrl+Alt+F3). sudo doesn't go through the agent, so it keeps working throughout.
