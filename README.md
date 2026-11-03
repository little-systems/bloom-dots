# bloom-dots

Bloom for Hyprland: a notch, dock, OSD, notifications, desktop panels, launcher,
lock screen, wallpaper, and system Settings for Arch Linux.

See [installation and recovery](docs/INSTALL.md) for the installer, dependency
metapackage, updates, rollback, uninstall, and release validation.

## Development

Requirements: Arch Linux with Quickshell, Qt 6 development tools, Node.js, npm,
jq, shellcheck, matugen, sway, grim, kitty, wtype, Python/PyGObject, and D-Bus.
GitHub CI provisions a headless Arch container and runs the same gate.

- Run every check: `CI=true tests/run-all.sh`.
- Focused lifecycle checks: `bash tests/cli/test_lifecycle.sh`.
- The design spec lives in `docs/specs/`, implementation plans in `docs/plans/`.
- UI reference: the original Windows Bloom application. Linux services perform
  the real actions; unsupported capabilities are reported explicitly.
