# Overview gestures

Owner requested replacing ii's four-finger vertical overview gesture.
Live and tracked `hypr/hyprland/general.lua` now use:

- Four fingers up: `qs -c bloom ipc call overview open`
- Four fingers down: `qs -c bloom ipc call overview close`

Horizontal workspace and three-finger gestures keep their existing actions.
Hyprland reloaded successfully and `hyprctl configerrors` was empty. The
physical four-finger gesture still needs an owner check.

Original files are backed up under
`/home/dhanush/Projects/bloom-gesture-backup-20261101-021432/` as
`live-general.lua` and `tracked-general.lua`. Restore each to its corresponding
`general.lua` and reload Hyprland to undo this change.
