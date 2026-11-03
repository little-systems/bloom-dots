# Dotfiles reliability research

Researched 2026-11-03 against first-party repositories and documentation. This is
an implementation comparison, not a popularity ranking or an endorsement of each
installer's safety. Source snapshots below were read through GitHub's API; no
upstream installer, package transaction or privileged command was executed. No
upstream implementation is copied into Bloom. The ii reference is behavioral
research only, as requested by the owner.

Owner-selected control scope: desktop services, hardware controls and diagnostics.
General system administration, bootloader policy, driver management and ownership
of the machine's normal package-update workflow are outside this hardening scope.
Installer dependency handling remains part of Bloom's own lifecycle contract.

## Sources and observations

### HyDE: explicit deployment policy

Snapshot: `HyDE-Project/HyDE` at
`fa2fd57afc7203b1b5653d3271f3a57ea3873f97`.

Its configuration manifest distinguishes populate/preserve, sync, overwrite and
backup policies per target, with package dependencies. Deployment handles dry-run
and backs up selected targets. This is clearer than a blanket copy operation.
The update documentation explicitly warns that selected configurations can be
overwritten and points to configuration backups. Sources:
[manifest](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Scripts/restore_cfg.psv#L11-L27),
[deployment](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Scripts/restore_cfg.sh#L167-L232),
[update contract](https://hydeproject.pages.dev/en/getting-started/update/).

The installer separates package, restore, service and pre-install operations; its
comments explicitly keep bootloader/pacman pre-install work out of ordinary
restore. Uninstall lists manual restoration of bootloader, pacman and SDDM
configuration and manual package removal. Thus backups exist, but a complete
transactional inverse is not established. Sources:
[installation phases](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Scripts/install.sh#L168-L178),
[uninstall limitations](https://github.com/HyDE-Project/HyDE/blob/fa2fd57afc7203b1b5653d3271f3a57ea3873f97/Scripts/uninstall.sh#L77-L97).

### end-4 / illogical-impulse: installed-path ledger and dependency groups

Snapshot: `end-4/dots-hyprland` at
`2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8`.

Deployment records installed paths, supports different directory-copy policies,
and offers backups of clashing targets. Uninstall lets the user inspect/edit
the deletion list before removal and points back to the backup location.
Recording a pathname is useful, but alone does not prove that deletion preserves
owner edits made later. Some deployment modes use destructive synchronization.
Sources:
[file deployment](https://github.com/end-4/dots-hyprland/blob/2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8/sdata/subcmd-install/3.files.sh#L12-L91),
[uninstall](https://github.com/end-4/dots-hyprland/blob/2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8/sdata/subcmd-uninstall/0.run.sh#L17-L107).

Arch dependencies are grouped into local metapackages; the script builds and
installs them and supports `--needed`. It also has a full-system-update step and
optional integration prompts. The observed scope is substantially broader than a
shell dependency check. Source:
[Arch dependencies](https://github.com/end-4/dots-hyprland/blob/2f2a376fdb2ad738bf55f693dd0b474b64bb0ab8/sdata/dist-arch/install-deps.sh#L42-L102).

### JaKooLit: phase logs and hardware choices

Snapshot: `JaKooLit/Arch-Hyprland` at
`7a3d6609b6419527c9ae79399a183b2ec6c1075d`.

The installer rejects root execution, writes timestamped installation logs,
checks existing packages and offers explicit choices for hardware/login-manager
work. Package helpers capture command output and verify installation afterward.
These are useful operational patterns, rather than evidence of whole-install
atomicity. Sources:
[installer](https://github.com/JaKooLit/Arch-Hyprland/blob/7a3d6609b6419527c9ae79399a183b2ec6c1075d/install.sh#L22-L55),
[package helpers](https://github.com/JaKooLit/Arch-Hyprland/blob/7a3d6609b6419527c9ae79399a183b2ec6c1075d/install-scripts/Global_functions.sh#L51-L129).

Its uninstall exposes selectable package/config removal and warns about system
stability. It performs recursive directory deletion; the inspected path does not
establish hash-based ownership protection for later user changes. Source:
[uninstall](https://github.com/JaKooLit/Arch-Hyprland/blob/7a3d6609b6419527c9ae79399a183b2ec6c1075d/uninstall.sh#L32-L74).

### Omarchy: coordinated OS update and explicit recovery limits

Snapshot: `omacom/omarchy`, default branch `quattro`, at
`5eb922f137422ff32a90869a9ba47525a428792d`. This is the inspected development
snapshot, not a claim about the currently released stable version.

The update flow holds a nonblocking inherited `flock`, records a terminal
transcript, installs cleanup/signal traps, checks free space, attempts snapshots,
and coordinates package updates, per-user migrations, hooks and restart checks.
The lock helper validates its inherited descriptor against the intended lock
path. Sources:
[update](https://github.com/omacom/omarchy/blob/5eb922f137422ff32a90869a9ba47525a428792d/bin/omarchy-update#L56-L106),
[lock](https://github.com/omacom/omarchy/blob/5eb922f137422ff32a90869a9ba47525a428792d/bin/omarchy-update-lock),
[coordination contract](https://github.com/omacom/omarchy/blob/5eb922f137422ff32a90869a9ba47525a428792d/docs/update-process.md#L20-L64).

Snapshot creation can be unavailable or fail, and the updater explicitly
continues with a warning. The recovery manual says root snapshots do not restore
home configuration or home-held migration markers; it also limits that recovery
feature to Limine installations. A successful snapshot therefore must not be
reported as complete application/configuration rollback. Sources:
[snapshot implementation](https://github.com/omacom/omarchy/blob/5eb922f137422ff32a90869a9ba47525a428792d/bin/omarchy-snapshot#L16-L47),
[updater fallback](https://github.com/omacom/omarchy/blob/5eb922f137422ff32a90869a9ba47525a428792d/bin/omarchy-update#L82-L90),
[recovery limits](https://github.com/omacom/omarchy/blob/5eb922f137422ff32a90869a9ba47525a428792d/manual/47-system-snapshots.md#L15-L21).

Its crash watcher consumes structured coredump journal fields, restricts notices
to the current UID, sanitizes executable names, deduplicates notices and waits
for notification ownership to recover. This is a useful example of diagnostics
surviving the shell that presents them. AI diagnosis is a separate optional
product behavior, not a requirement for Bloom. Source:
[crash watcher](https://github.com/omacom/omarchy/blob/5eb922f137422ff32a90869a9ba47525a428792d/bin/omarchy-crash-watch#L26-L108).

### Caelestia: component manifest and conflict-aware deployment

Snapshots: dotfiles `f9c50b542e338d6e426dc872ecf7a2b2932dd721`; CLI
`68d1c64144c6552d4906030b5eef7a099b0c84fd`.

The dotfiles declare component packages, deployment entries and hooks in a TOML
manifest. User override files are separate from managed Hyprland files. The
README states that the installer does not provide a login manager; the CLI
welcome likewise excludes driver/system-level setup. These are useful support
limits, rather than trying to own an arbitrary Arch installation. Sources:
[manifest](https://github.com/caelestia-dots/caelestia/blob/f9c50b542e338d6e426dc872ecf7a2b2932dd721/manifest.toml),
[configuration contract](https://github.com/caelestia-dots/caelestia/blob/f9c50b542e338d6e426dc872ecf7a2b2932dd721/README.md#L53-L67),
[CLI installer scope](https://github.com/caelestia-dots/cli/blob/68d1c64144c6552d4906030b5eef7a099b0c84fd/src/caelestia/subcommands/install.py#L100-L122).

The CLI persists the applied revision, selected components, deployed files and
package identities. Update computes changes against the previous revision,
handles conflicts via adjacent `.new` files, preserves differing unmanaged
files, and prompts for package removals. File placement uses a temporary file in
the destination directory and atomic replacement. These are useful seams, but
single-file atomicity is not whole-install crash recovery. Sources:
[update](https://github.com/caelestia-dots/cli/blob/68d1c64144c6552d4906030b5eef7a099b0c84fd/src/caelestia/subcommands/update.py#L25-L76),
[conflict handling](https://github.com/caelestia-dots/cli/blob/68d1c64144c6552d4906030b5eef7a099b0c84fd/src/caelestia/subcommands/update.py#L123-L188),
[atomic placement](https://github.com/caelestia-dots/cli/blob/68d1c64144c6552d4906030b5eef7a099b0c84fd/src/caelestia/utils/dots/deployer.py#L36-L61).

### chezmoi: reconciliation instead of repeated imperative copying

The current official documentation defines `apply` as ensuring target state and
prompting before overwriting a file modified since its last write. Dry-run and
selective targets are supported. Scripts have always/on-change/once modes, but
the documentation still requires every script to be idempotent and recommends
sparing use of imperative scripts. Sources:
[apply](https://www.chezmoi.io/reference/commands/apply/),
[script semantics](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/).

This is a strong model for Bloom's planner, not a recommendation to replace its
installer with another tool or a claim that chezmoi transacts package upgrades,
services and boot configuration. The source repository snapshot observed during
research was `a7bf9bafe9b63d3e6196060b79177a6c7bdab333`; the linked documentation
is live and can change.

## Platform contracts that matter more than copying another dotfiles repo

- Plain Hyprland and UWSM are distinct lifecycle adapters. UWSM documents
  compositor finalization, session-bound application units and environment
  cleanup; its shutdown path is `uwsm stop`. Bloom should explicitly detect and
  test supported profiles rather than combine their shutdown assumptions.
  [UWSM README](https://github.com/Vladimir-csp/uwsm),
  [Arch manual](https://man.archlinux.org/man/extra/uwsm/uwsm.1.en).
- systemd documents that `ExecCondition` exits 1–254 skip launch without marking
  the unit failed, while automatic restarts are subject to start rate limits.
  Model expected session teardown separately from a runtime crash.
  [systemd.service](https://www.freedesktop.org/software/systemd/man/259/systemd.service.html).
- Arch does not support partial upgrades. A package installer must not refresh
  the package database and then install a selected subset as if this were safe.
  Package transaction and rollback scope must be disclosed independently from
  Bloom's file/configuration transaction.
  [Arch system maintenance](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported).

## Recommended Bloom direction — conclusions from the comparison

These are proposals for Bloom, not guarantees inherited from the projects above.

| Area | Recommended contract | Failure test |
| --- | --- | --- |
| Ownership | Each resource records original state, applied state, hash, owner, operation ID and inverse; user edits cause a conflict, never silent deletion | Modify a managed file after install, then update/uninstall |
| Planner | Inspect → immutable plan → execute → verify; repeated apply of the same plan makes no changes | Install twice, update twice, remove twice; compare state and side effects |
| Crash recovery | One writer lock, write-ahead journal, atomic durable state, resumable or reversible stages | Interrupt before/after every mutation and manifest commit |
| Dependencies | Capability-level required/optional groups; record preexisting versus newly installed packages and actual package identities | Offline/denied auth/partial transaction/AUR build failure |
| Session | Explicit plain-Hyprland and UWSM adapters; readiness, display identity, ownership and teardown are separate states | Rapid relogin, stale environment, display missing, rate limit, two sessions |
| Runtime | Bound retries/timeouts; optional feature failure leaves the desktop usable; security-sensitive features fail closed | Drop each D-Bus owner/tool/device independently |
| Diagnostics | Stable event IDs and operation IDs, component/stage/outcome/duration/retry/exit fields; doctor distinguishes unavailable/degraded/failed | Trace one failure from action through process and recovery |
| Privacy | Redact before storage; bounded retention; explicit debug opt-in; support exports are previews, never automatic uploads | Put synthetic secrets in arguments, stderr and settings; verify none exported |
| Updates | Stage immutable revision; validate before activation; health acceptance; retain last-good code/config generation | Broken candidate, configuration migration failure, disk full |
| Recovery | TTY-capable doctor, safe mode, rollback/uninstall without the UI or network; backup catalog and retention aware of live manifests | Shell cannot start; restore from outside the graphical session |
| OS control | Enumerated typed actions and native authorization; show ownership and scope; no generic arbitrary-root command channel | Denied/cancelled polkit, hardware absent, service already desired state |

Package management is not equivalent to filesystem rollback. Snapshots may cover
root but omit home, and external services/hardware can have irreversible effects.
Acceptance should be a documented recovery contract plus injected-failure
evidence, never an assertion that every possible failure is eliminated.

### Patterns to avoid importing

- Do not inherit broad bootloader, SDDM, driver, pacman-policy or full-system-update
  mutations merely because an upstream desktop distribution implements them.
- Do not treat a pathname ledger as proof of current file ownership, or recursive
  backup folders as proof that interruption-safe rollback exists.
- Do not call an operation recoverable when snapshot creation failed or when its
  configuration, migration markers and package database are outside the restore.
- Do not turn full terminal transcripts into an indiscriminate logging policy.
  Prefer allow-listed diagnostic fields and explicit opt-in to sensitive debug
  material; keep local logs useful when Bloom's notification UI is unavailable.
- Do not add automated AI log upload/diagnosis, sudo timestamp keep-alive, package
  upgrade guards or competing session managers as incidental hardening changes.

## Limits of this research

This was a targeted first-party code/document review. It did not execute upstream
installers, verify every helper, audit dependencies or establish security of any
project. No source is a complete proven reference for fail-safe/idempotent
desktop management. Further Bloom implementation work should use its own tests,
isolated environments and real supported-session acceptance matrix.
