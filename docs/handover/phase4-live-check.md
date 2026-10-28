# Phase 4 live check and ii handover

**Status:** prepared for owner approval; no live Phase 4 setting, ii file, keybind, or device value has been changed. Do not run the switch before owner approval.

## Reviewed change

- Phase 4 implementation branch: `codex/phase-4-osd-notifications` in `bloom-dots-4`. The full `CI=true tests/run-all.sh` suite passes. The `osd` and `notifications` modules are disabled in the owner's settings.
- Exact ii source change: [ii-notification-optout.patch](ii-notification-optout.patch). It creates ii's `NotificationServer` only when `bloomOwnsNotifications` is false, guards old calls when no server exists, hides ii's popup and history entry points in both panel families, and disables ii's OSD surfaces after Bloom's OSD is checked. ii's tray, polkit, sidebars, launcher, lock and other services remain loaded.
- Apply and restore tool: `scripts/phase4-ii-notifications.sh apply|restore LIVE_II_ROOT TRACKED_II_ROOT BACKUP_DIR`. It never restarts a shell. It checks the patch against both roots before writing, backs up all four touched files in a new directory, and restores both roots if an apply fails.
- The patch and its inverse were checked byte-for-byte on two disposable copies. A private D-Bus/Wayland run of the patched ii notification service loaded and left `org.freedesktop.Notifications` unowned. This is not a live session result.

## Current owner session snapshot (recheck immediately before switch)

On 2026-10-28, live Bloom is `bloom-shell.service` from `/home/dhanush/Projects/bloom-dots/shell`, enabled modules are `["notch","dock"]`, and ii PID 1046 owns `org.freedesktop.Notifications`. ii's top bar is already disabled in both live and tracked dotfiles. The audio sink was at 1.00, unmuted; `intel_backlight` reported 1666/1666 (100%). These are observations, not values to assume later.

## Sequence after owner approval

1. Recheck the exact four ii files against the patch; capture ii/Bloom PIDs, notification bus owner, the module list, `wpctl get-volume @DEFAULT_AUDIO_SINK@`, and `brightnessctl -m -c backlight info` in a fresh private backup directory. Keep the exact raw brightness and mute state for restoration.
2. Fast-forward the reviewed branch into local `bloom-dots` `main` and restart `bloom-shell.service`. Enable **only** `osd` using `bin/bloom ipc settings set bloom-enabled-modules` with the previous list plus `osd`. Confirm ii still owns notifications and Bloom's OSD can show read-only state. Adjust volume by at most 2 percentage points and brightness by at most 5, then restore the recorded values and mute state. If OSD fails, restore the original module list and stop before touching ii.
3. Apply the exact ii patch to `/home/dhanush/.config/quickshell/ii` and `/home/dhanush/dots-hyprland/dots/.config/quickshell/ii` with the script and a new backup directory. Restart ii by stopping its current `qs -c ii` process; its existing supervisor starts it again. Confirm ii's other surfaces/services remain available and the notification name is unowned. Keep the old ii history file as a backup; do not delete it.
4. Enable `notifications` in Bloom's module list, preserving all other entries. Confirm `busctl --user status org.freedesktop.Notifications` reports Bloom's `qs` PID, and `bin/bloom ipc notifications state` reports `ownership: "owned"`. Send one test notification with an action, one replacement, one timeout, and one critical item under DND. Check each appears once, the action reaches its sender, the close reason is recorded, and `bin/bloom ipc notifications openHistory` opens the notch history sheet. Clear only the temporary test items.
5. Restore device baselines, check ii's OSD/popups stay hidden, inspect both shell logs and bus ownership, run the full suite, and record results in AGC. Do not push.

## Immediate rollback

1. Restore the exact saved Bloom module list, removing `notifications` and `osd`; verify the notification name is unowned.
2. Run `scripts/phase4-ii-notifications.sh restore LIVE_II_ROOT TRACKED_II_ROOT BACKUP_DIR` with the paths used in step 3, then restart ii through its existing supervisor. Verify ii again owns `org.freedesktop.Notifications` and receives a test notification once.
3. Restore recorded audio, mute and brightness values. Retain the backup directory and logs for diagnosis. The local Bloom code merge may stay present with Phase 4 modules disabled; do not rewrite Git history to roll back a live check.

The ii source patch and rollback are the approval boundary for Phase 4C. The preceding OSD hardware check also requires the owner's explicit approval.
