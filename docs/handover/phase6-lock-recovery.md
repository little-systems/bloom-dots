# Lock screen recovery

**Status:** Bloom's lock became the real lock on 2026-10-31, through `lock_cmd` in `~/.config/hypr/hypridle.conf` (backup: `~/Projects/hypridle.conf.bloom-backup-20261031-201935`). hyprlock stays the fallback.

Hyprland holds the lock, not the shell. If the lock surface dies the session stays locked and shows a solid colour until a lock client takes over. Nothing below needs the graphical session to work.

## If the password field doesn't accept the password

1. Wait: PAM may be throttling after several wrong attempts (`pam_faillock`, about 10 minutes after 3 failures on Arch's defaults).
2. Go to a TTY: `Ctrl+Alt+F3`, then log in as yourself.
3. Clear the throttle if that's the cause: `faillock --user "$USER" --reset`.
4. Return to the session: `Ctrl+Alt+F1`.

## If the screen is stuck or a solid colour

From the TTY:

```bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
systemctl --user restart bloom-shell
```

Bloom sees its marker and locks again. If that doesn't bring a working lock, hand the lock to hyprlock, which stays installed as the fallback:

```bash
export HYPRLAND_INSTANCE_SIGNATURE=$(ls "$XDG_RUNTIME_DIR/hypr" | head -1)
hyprctl dispatch 'hl.dsp.exec_cmd("hyprlock")'
```

Back on `Ctrl+Alt+F1`, unlock in hyprlock.

## Last resort

This ends the session and closes every app, so unsaved work is lost:

```bash
loginctl terminate-session "$(loginctl show-user "$USER" -p Display --value)"
```

## Turning it off

Remove `lock` from `bloom-enabled-modules` in `~/.config/bloom/settings.json`, and restore `lock_cmd` in `~/.config/hypr/hypridle.conf` from its backup if that step was taken.
