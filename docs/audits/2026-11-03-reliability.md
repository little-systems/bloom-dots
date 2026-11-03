# Reliability, recovery and observability audit

Date: 2026-11-03. Source baseline: `86fb0c4`, including the two local session
fixes; public `main` remains `f00bf13`. This is an operational architecture
audit, not a claim that every code path has been exercised or a security
certification. No full suite, package installation, real logout, privileged
configuration change, push or merge was performed for this audit.

## Verdict

**Do not call Bloom generally production-ready yet.** Happy-path functionality
and a green historical CI run do not establish safe recovery from interrupted
operations, failed writes, missing backups or session changes. Four disposable
probes below demonstrate real failures. Fix those before expanding system
control or introducing more automatic repair.

The owner's scope is **desktop services, hardware controls and diagnostics**.
Bloom is not to become an unattended Arch package manager, boot repair tool or
general administrator. Preserve the Windows Bloom visual reference, existing
notch/dock/integrated AI layouts, native polkit authentication and owner changes.
Personal ii migration remains outside this public repository.

Research comparison: [established dotfiles](../research/2026-11-03-dotfiles-reliability.md).
Execution plan: [reliability hardening](../plans/2026-11-03-reliability-hardening.md).
Current implementation: [hardening progress](2026-11-03-hardening-progress.md).
Findings below describe the baseline; consult that ledger for repairs and
remaining acceptance limits.

## Evidence and limits

- Inspected lifecycle CLI, both systemd units, Hyprland loader, package metadata,
  runtime persistence, process execution, privileged controls, authentication,
  theme writers, diagnostic command, network helpers and CI structure.
- Survey inventory: 35 service QML files, 12 shell helper files, 25 Settings QML
  files and 101 module QML files. Across shell QML: 80 `Process` declarations,
  28 `Quickshell.execDetached` call sites, three `FileView` declarations and
  zero `onSaveFailed` handlers. Counts identify review scope, not defect counts.
- Read high-risk implementations directly; surveyed remaining presentation and
  pure-rule code through their callers/tests. This is not a line-by-line visual
  or accessibility review of all 101 presentation files.
- Ran temporary-home lifecycle probes and a real offscreen Settings write
  failure probe. No live configuration was used by these probes.
- Session regression tests and actual disposable systemd condition probes were
  executed during the immediately preceding fixes. The owner confirmed the
  corrected logout; the latest complete logout/new-login recovery still needs
  owner validation. Do not turn the current working session into that test.
- Historical full CI at `f00bf13` is not evidence for later commits. Existing
  happy-path tests have not been rerun as a complete gate during this audit.
- Not yet exercised: clean VM installation, real package failure/rollback,
  forced power loss, disk-full filesystem, daemon restart matrix, hardware
  disconnects, multiple simultaneous graphical sessions or suspend/resume soak.

Evidence classes: **reproduced** means an agent-run disposable probe demonstrated
the failure; **source-confirmed** means the behavior is visible in inspected
code; **unverified** means a risk needs a dedicated experiment before a fix is
claimed.

## Prioritized findings

### R01 — P1: uninstall can destroy the managed destination when recovery data is missing

**Reproduced.** `tools/bloom-lifecycle.py:328-354` checks for owner edits, stops
Bloom, then removes each destination before attempting to restore its backup.
It does not preflight existence, readability or recorded integrity of every
required backup. A missing backup produced `FileNotFoundError` after the
destination was deleted and the service had been disabled.

Probe: temporary managed file with its installed signature and a nonexistent
backup; stubbed service commands. Result:

```text
FileNotFoundError; managed_file_exists=False; service_mutated=True
```

Required: preflight the entire restore plan, stage recoverable originals,
journal uninstall steps and retain backups until final verification. A missing
or corrupt original must refuse before any service/file mutation. Killing
uninstall halfway must leave a resumable journal, not a partly consumed ledger.

### R02 — P1: settings can report success although nothing was saved

**Reproduced.** `shell/services/Settings.qml:38-48` calls `setText`, applies the
new in-memory settings and returns success without observing `saveFailed`.
`blockWrites` waits for completion but does not make a failing write successful.
`printErrors: false` also suppresses the built-in error output.

Probe: real Settings singleton in an offscreen copied harness, valid dark
settings file, parent directory changed to mode `0500`, set mode to light:

```text
Settings.set result=""; memory=light
disk={"bloom-theme-mode":"dark"}
```

Required: acknowledge persistence only on confirmed save, retain the last
committed value on failure, expose a typed persistence error and preserve the
failed intent for explicit retry. Test permission denial, ENOSPC and concurrent
Settings/shell/external writers. Atomic replacement alone does not prevent
last-writer-wins loss across processes.

Quickshell documents separate `saved` and `saveFailed` signals:
[FileView](https://quickshell.org/docs/v0.2.1/types/Quickshell.Io/FileView/).
The cited documentation version is older than the installed 0.3 runtime; the
offscreen probe above confirms the relevant behavior on this machine.

### R03 — P1: manifest containment checks accept traversal paths

**Reproduced.** `Context.validate_manifest`,
`tools/bloom-lifecycle.py:109-118`, uses lexical `Path.is_relative_to` checks.
A destination `config/../outside` passes. Backup paths have the same issue.
The manifest also allows a broad set of paths under config/data/state rather
than a closed set of owned operation types and destinations.

Required: strict schema/type/version/entry validation, no traversal, permitted
destination policy, and a deliberate policy for symlinked parent directories.
Check the parent chain without resolving away the final managed symlink.
Validate `created_dirs`, originals and signatures as well as entries. Repeat
validation under the mutation lock. Refuse malformed state before effects.

This is a data-loss guard against malformed/local state, **not** a demonstrated
privilege escalation or protection against a malicious same-user process.

### R04 — P1: interrupted installation is recorded but not generally resumable

**Reproduced at the destination-absent cut.** `Transaction.change`,
`tools/bloom-lifecycle.py:205-252`, records desired state, removes the old path,
then creates the replacement. A kill between removal and replacement leaves a
manifest entry that does not match the absent destination. The recovery
exception recognizes the original backup signature, but not this absent state.

Probe: temporary `status=installing` manifest, valid original backup and missing
destination. Retrying `change` refuses with `changed since installation`.
Further cuts and fsync durability remain unverified.

Required: explicit transaction states and per-step progress, adjacent staging
plus rename for file/link replacement, durable intent/backup before mutation,
and a recovery command that offers verified resume or restore. An intentional
owner edit must remain distinguishable from an installer-owned incomplete step.

### R05 — P1: display safety rollback lives inside the process being protected

**Source-confirmed architecture gap; crash behavior unverified.**
`shell/settings/SystemStore.qml:154-183` stores a display trial's rollback
state and 15-second timer only in the Settings process. A crash after changing
an unusable monitor mode can remove its rollback timer. Configuration and JSON
state are written by detached shell redirections, without a shared transaction
or completion acknowledgment.

Required: display trials owned outside the Settings window, identified by trial
ID, with independent deadline/revert and readback. Persist only on confirmed
Keep. Test process death, failed apply, unplug and restarted compositor. Do not
test destructive display modes on the owner's session.

### R06 — P2: recording ownership and stopping are not safe under reuse/concurrency

**Source-confirmed.** `shell/scripts/region.sh:10-17,79-106` treats `kill -0 PID`
as recorder identity, with no start-time/argv check or operation lock. It sends
SIGINT and announces saved immediately without verifying exit/final output;
recorder stdout/stderr are discarded. Concurrent starts can race on the PID file
and second-resolution filename. A stale reused PID can target another process.

Required: owned recording unit or PID plus start time/session/identity, a lock,
unique output staging, start verification and bounded finalize/readback. Logs
must not capture the recorded content. A recording failure must stay local to
recording, not take down the shell.

### R07 — P2: state corruption recovery can silently discard pending saves

**Source-confirmed.** `StateFile.qml:33-72` clears `_hasPending` before the write
and has no save failure handler. Corrupt-file backup logs claim a completed
move before it happens; `backup.onExited` flushes regardless of exit status.
A failed backup can allow a subsequent write to replace the corrupt evidence.
Numbered backups and history lack an explicit byte/age retention contract.

Required: preserve pending writes until acknowledgment, block replacement if
quarantine fails, separate read/corrupt/quarantine/save errors, schema/version
checks per document, private modes and bounded retention. Retention must not
prune active transaction originals or owner recovery archives.

### R08 — P2: command outcomes, deadlines and cancellation are inconsistent

**Source-confirmed across several callers, not every invocation.** Network,
Bluetooth, shelf and updates already use bounded subprocesses in several places.
Brightness, compositor queries and Settings' action queue do not share that
contract. A hung queue action can block later actions. Detached session,
wallpaper, OSK and region IPC can return `ok` when only dispatch was accepted.
NightLight lacks a common availability/failure/retry state.

Required: operation IDs and explicit accepted/running/succeeded/failed/cancelled
outcomes, bounded one-shot commands, bounded output, backend-specific readback,
process-start failure handling and retry policy. Long-lived monitors need a
different lifetime contract from commands; never timeout a recorder as though
it were a query. Cancellation must terminate the owned process tree only.

### R09 — P2: update rollback is a checkout rollback, not an installed-system rollback

**Source-confirmed.** `tools/bloom-lifecycle.py:286-325,368-407` installs packages
outside file rollback and uses mutable checkout symlinks. Git changes while the
shell may still use those files; the running updater continues executing the
old Python implementation after checkout moves. Error recovery checks out the
old commit but suppresses service-restore errors. No immutable deployment,
release eligibility/provenance gate or health-gated activation exists.

Required: staged versioned deployment, explicit compatibility/migration policy,
healthy activation before promotion, preserved previous deployment and truthful
partial rollback reporting. Separate desktop-file recovery from pacman state;
never promise arbitrary package downgrade or remove shared dependencies based
only on the metapackage. No unattended package changes are in the owner's scope.

### R10 — P2: logs exist, but cannot yet explain a complete operation

**Source-confirmed.** Current journal console messages, systemd failure reporter,
`bloom doctor` and soak tool are useful foundations. They lack a shared event
schema, operation/session correlation, persisted lifecycle ledger, bounded
error registry and safe support export. Doctor prints raw non-default settings
and recent journal text, without an allowlisted export/redaction policy or
machine-readable overall health verdict. OnFailure wording says repeated crash
although systemd can run it after individual failures.

Required: typed events and terminal outcomes, actionable subsystem health,
read-only doctor, explicit repair actions, rotation and secret/data redaction.
Logging every frame, password prompt, app title or device payload is neither
necessary nor acceptable. The plan defines event families for every subsystem.

### R11 — P2: theme restoration does not protect later owner edits or fully respect XDG

**Source-confirmed.** `adaptive-theme.sh` serializes theme changes and backs up
original targets, but `restore` copies/truncates them without validating the
current installed fingerprint. Owner edits after application can be lost.
Several targets use literal `$HOME/.config`/`.local` despite the installer's
XDG contract; writes across GTK, Qt, compositor, terminal and gsettings are not
one transaction. `app-theme.py:update_settings` rewrites settings directly.

Required: an ownership-aware theme transaction with preserved foreign fragments,
XDG-aware targets, explicit supported-app capability list, staged validation,
partial failure reporting and edit-aware restore. Do not overwrite the live
theme merely to exercise failure handling.

### R12 — P2: capability, ownership and daemon recovery checks are incomplete

**Source-confirmed gaps; daemon restart behavior unverified.** Notification bus
ownership is checked at startup with limited retries, not a common long-lived
reacquisition policy. Tray and polkit use different reporting. An installed
metapackage does not prove NetworkManager, BlueZ, PipeWire, portals, PAM or a
backlight are usable. Settings can expose controls independently of runtime
health. Preflight requires qs/hyprctl already installed before dependency setup;
`--no-deps` does not verify all enabled-module capabilities.

Required: capability discovery with unknown/available/missing/degraded/conflict
states; backend restart/name-owner handling; reconnection backoff and readback.
Never start a competing exclusive agent as automatic recovery or restart an
unrelated service without an explicit selected action.

### R13 — P2: current tests do not establish destructive-failure acceptance

**Source-confirmed coverage limit.** Existing disposable-home rollback and real
offscreen QML/integration tests are valuable. The newly reproduced failures were
not locked down by them. CI is an Arch container, not an SDDM login or fresh
machine. There is no exercised kill-at-every-step lifecycle matrix, full disk,
parallel writer, daemon disappearance or real install/uninstall VM gate.

Required: fault injection through the real operation interfaces, targeted tests
for each repair, plus a disposable Arch VM lifecycle gate. Full-suite execution
still requires owner approval. Do not substitute retries for investigated flakes.

### R14 — P3: external request policy is inconsistent

**Source-confirmed.** Weather has a Timer watchdog but falls back to HTTP IP
geolocation (`Weather.qml:78-81`). Settings city search creates independent XHRs
without the shared timeout/cancellation helper. Assistant has a socket timeout
and keyring/stdio secret handling, but no complete request-duration/output-size
budget. These are different data classes and need separate disclosure/budgets.

Required: HTTPS-only geolocation or explicit manual-location fallback, latest
query cancellation, bounded response/stream memory, retry/backoff rules and
non-sensitive request metadata. Never log prompts, keys or fetched content by
default. Do not silently send data to new fallback providers.

## Coverage matrix and required failure contracts

| Area / inspected modules | Existing protection | Required hardening / acceptance |
| --- | --- | --- |
| Installer, preflight, manifest, dependencies | dry-run, flock, originals, edited-file refusal | R01/R03/R04/R09; path, kill, package failure and rerun matrix |
| Login/logout, service, failure reporter | native compositor exit; socket guard; imported environment/reset/restart | owner retest; no stale session, retry storm or duplicate shell; UWSM/multi-session support must be declared/tested separately |
| Settings, StateFile, state.js | schema/defaults, last-good config, atomic writes, corrupt backups | R02/R07; acknowledged writes and concurrent writer detection |
| Theme, app-theme, wallpaper and picker | serialized writes, originals, argv paths | R11/R14; edited target, XDG, missing image, killed generator, absent video backend |
| SystemStore and settings-query | sequential action queue, some backend readback, display trial timer | R05/R08/R12; independent rollback, native auth cancellation, queue timeout |
| HyprState, HyprEvents, Overview, Cheatsheet | holder-driven reads; stale-signature backoff | bounded snapshot, validated shape, compositor restart/hotplug and stale target detection |
| Dock, Apps, launch.js, DockExtras, tray | desktop-entry argv, app scopes, removable-drive verification | launch result, stable drive identity, busy/eject race, package absent, bus owner loss; never kill launched apps on shell restart |
| Audio, Media, Cava, Sounds, Performance | PipeWire tracker, holder-driven work, volume guard, low power | daemon/device loss, invalid volume, crashed visualizer, failed sound; no busy spin or invented hardware state |
| Network and Bluetooth / agent | timeouts in several operations; Wi-Fi secret stdin; pairing lifecycle | daemon restart, radio/device disappearance, missing binary, rejected auth, stale response; no SSIDs/PINs in support logs |
| Brightness, NightLight, Battery, Devices | unavailable state, bounded device probes, monitor retry | bounded write/readback, no backlight, denied access, removed adapter, absent power backend |
| Notifications and cards | bounded history count, live notification tracking, startup ownership check | owner change, full disk, daemon reconnect, flood byte budget; no body/title in diagnostics |
| Lock/PAM and polkit | compositor lock remains secure after shell crash; PAM-only unlock; opt-in agent | auth cancellation, registration conflict, marker-write failure, multi-screen/hotplug recovery; never automatic unlock or password logging |
| Launcher and Assistant | typed modes/pure rules, keyring key, stdio request | request/action result, cancellation, hostile response size, no terminal, missing keyring; known live Qt focus warnings remain open |
| Region/OCR/translate/recognition | region cancellation, dependency checks, argv, selected output | R06/R08/R14; concurrent start, finalize error, disk full; sensitive OCR must not enter diagnostic logs |
| CalendarState, PanelState, ShelfState, OverlayState | state separate from settings; timer deadline; bounded shelf helpers | failed persistence, resumed timer exactly once, missing shelf path, bad preview, restart; notes/history not support payload |
| OSK, session menu, overlays | native actions, local state, confirmation UI | unavailable injection backend, duplicate destructive request rejection, clear accepted/completed semantics |
| Http, Weather, Updates, SystemStats | weather watchdog, last-good updates, stats warning backoff | request budgets, stale timestamps and daemon/tool errors; no partial system upgrade |
| Rendering/assets/fonts/generators | bundled assets, licenses, generated checks, motion policy | missing/corrupt asset fallback, zero-size/hotplug/scale, low-power/idle budget; preserve Bloom UI/UX |
| CLI doctor, IPC, dev tools, soak | diagnostic timeouts, own app scopes, soak restoration | typed health/exit status, redaction, development path-with-spaces handling, no diagnosis-triggered mutations |
| CI/docs/release/dependency supply | conventional commits, container checks, licenses, dependency metapackage | current-commit gate, pinned release policy, VM evidence, recorded supported versions and release/rollback procedure |

## Guarantees to build, not absolute promises

No desktop can be immune to kernel/compositor/storage/hardware failure. Bloom's
contract should be: validate before effects; mutate only owned state; never
claim completion without verification; fail visibly and locally; recover or
retain enough verified data for the owner to recover; never weaken lock or
native authentication. Idempotence means repeated desired-state requests
converge, not that a destructive action may be silently replayed.

Arch documents that partial upgrades are unsupported; existing `checkupdates`
is the right family of read-only check, while package administration remains an
explicit user action:
[system maintenance](https://wiki.archlinux.org/title/System_maintenance).
systemd documents that condition exits 1–254 skip rather than fail a service:
[service execution conditions](https://www.freedesktop.org/software/systemd/man/261/systemd.service.html).
