# Phase 8: Shipping and reversible installation

Status (2026-11-11): the tooling is complete and on `main`: reversible install,
staged update and rollback, uninstall, recovery, the dependency metapackage, and
the documentation. Still open: owner-run checks (a managed install with the real
metapackage on the owner's machine, and release performance measurements), H6
release acceptance, and publishing (a version tag, release notes and an AUR
package).

## Public scope

- Arch/Hyprland/Quickshell preflight, dry-run installation, file ownership
  manifest, backups, Settings desktop entry/icons and user units.
- User-owned Lua templates and a marked loader; customized defaults get `.new`
  revisions rather than being overwritten.
- Fast-forward updates, dependency refresh, recorded rollback, and uninstall
  that restores original files and preserves user edits.
- Runtime dependency metapackage, installation/recovery documentation, and
  monitored visual soak tooling.
- Owner-specific desktop migration is maintained locally outside this repository.

## Validation

Lifecycle contracts use disposable homes, stub package/service tools, and local
Git remotes. Soak contracts use stub IPC/journal tools and real process memory.
The public branch must pass GitHub CI before merging. Actual package installs,
service handovers, login/lock checks and release performance measurements are
explicit owner-controlled operations.

The lifecycle core passed its full local gate (976 QML tests plus the script,
integration, CLI and systemd stages). The visual soak helper passed five
focused tests. The dependency metapackage built without being installed.
The migration-specific contracts are retained with the private maintenance tool.
