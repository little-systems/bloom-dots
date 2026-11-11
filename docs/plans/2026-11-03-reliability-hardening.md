# Bloom reliability hardening program

Status (2026-11-11, `main` at `2415b8f`): **H0–H5 complete**, with two
deferrals recorded below. **H6 open**: release acceptance on the current commit
and the physical-hardware and login-screen checks remain. See the
[implementation ledger](../audits/2026-11-03-hardening-progress.md). Baseline
`86fb0c4`. The owner requested this audit on 2026-11-03 and selected desktop
services, hardware controls and diagnostics as the scope of Arch control.

Inputs: [audit](../audits/2026-11-03-reliability.md) and
[upstream research](../research/2026-11-03-dotfiles-reliability.md).

## Non-negotiable contracts

1. A query is read-only. Diagnosis never silently restarts a daemon, changes
   configuration, replaces an exclusive agent or uploads data.
2. Desired-state setters converge on repeated calls. Toggles, notifications,
   prompts, recording, launching and destructive actions are explicit events;
   they must not be retried as though they were setters.
3. `accepted` means queued; `succeeded` means the required persistence/backend
   readback completed. UI state is not proof that hardware changed.
4. Mutations target declared owned resources. An owner edit is a conflict to
   preserve. Missing recovery data is a refusal before effects.
5. An interrupted operation leaves a durable, understandable next action:
   resume, restore, resolve conflict or acknowledge irreversible effects.
6. Optional backend failure degrades its feature, not the entire desktop.
   Security-sensitive failure never unlocks a session or bypasses native auth.
7. Privileged operations use enumerated actions and the existing tool's native
   authorization. No password handling, generic root command channel or sudo
   keep-alive. Bootloader, drivers and general OS administration are out of scope.
8. Preserve Bloom's UI/UX, personal configuration and local-only migration data.
   Architectural work is not a redesign. Full-suite runs need owner approval.

## Target architecture: deepen existing seams

Keep QML for presentation/reactivity and Python/stdlb for lifecycle/file work.
Use systemd and native D-Bus/tool interfaces rather than invent a privileged
daemon or replace every subsystem at once. Do not route authentication secrets
through a generic command/logging module.

| Module | Small interface callers use | Implementation hidden behind it |
| --- | --- | --- |
| Lifecycle | inspect, plan, apply, recover, remove | strict resource ledger, lock, staged durable files, recovery steps, dependencies and service verification |
| Persistent store | read document, commit expected revision, observe result | schema/version, atomic replacement, acknowledgment, conflicts, quarantine, private modes and retention |
| Operation runner | start typed operation, cancel owned operation, observe result | process-start errors, deadline, bounded stdout/stderr, process-tree ownership, terminal event and readback |
| Capabilities / health | snapshot, observe changes | required tools/versions, hardware presence, D-Bus ownership, service readiness, stale age and recovery guidance |
| Diagnostics | emit allowlisted event, read health, export preview | redaction, bounded error registry, session/operation correlation, journal and lifecycle log retention |
| Session integration | inspect profile, start shell, end session | separate tested plain-Hyprland and future UWSM adapters, imported environment, display readiness and ownership |

There are real adapters at the process seam: QML `Process` and Python subprocess.
Share result/error/event vocabulary, not a large cross-language framework.
File storage has CLI and QML callers, which justifies a shared persistence
contract. Keep device-specific validation/readback close to the device module;
a universal `run(command)` interface would simply move caller complexity around.

Replace one existing cluster at a time and delete its duplicate handling. Do not
retain an old path plus an unconnected wrapper and claim the architecture fixed.
Public lifecycle behavior must remain compatible with the owner's local-only
migration tools until those tools are explicitly adapted locally.

## H0 — Baseline and acceptance ledger

- Preserve `9f00510` and `86fb0c4`; record exact tested commit for each gate.
- Convert each R01–R14 finding into a work item with evidence class, failure
  trigger, expected outcome, impacted files and an acceptance test.
- Keep a supported-profile statement: Arch, Hyprland Lua version, Quickshell,
  native session startup; record UWSM/multiple graphical sessions as unverified
  until adapter-specific tests exist.
- Finish the owner relogin check without automating logout or entering passwords.
- Retain Windows visual reference and owner-local migration separation.

Exit: audited baseline is reproducible and the known limitations are explicit.

## H1 — Make installation and removal recoverable first

Addresses R01, R03, R04 and the lifecycle part of R09/R13. This is the **first
implementation work package**, ahead of expanding logging or controls.

1. Add disposable regression tests for the reproduced missing-backup,
   traversal and interrupted-destination failures before changing behavior.
2. Validate all manifest fields and owned paths before effects. Explicitly
   handle parent symlinks, malformed documents, unknown versions, duplicate
   destinations and missing/corrupt originals; reject unsafe plans.
3. Separate inspection/planning from execution and verify that dry-run has no
   desktop/package effects. Make an already-converged install a no-op apart
   from explicitly requested health repair.
4. Stage replacements beside destinations and preserve metadata. Journal
   transaction ID, generation, step, original/applied fingerprints and status.
   Write durable intent and originals before replacement; fsync state and parent
   directories where crash durability is promised.
5. Preflight an entire uninstall/restore plan before stopping Bloom. Retain all
   originals until the inverse operation is verified and committed. Journal
   progress so repeat/remove/recover does not consume evidence twice.
6. Introduce explicit `recover`/inspection behavior through the CLI; ambiguous
   owner edits refuse automatic repair. Report incomplete service/package
   restoration instead of swallowing its error.
7. Keep package installation separate from desktop-file transaction guarantees;
   record preexisting/new package state and authorization outcome, no automatic
   shared dependency removal. Do not change pacman databases for a dry run.

Tests: failure before/after every journal/backup/replace/activation step;
SIGTERM/SIGKILL; read-only path, ENOSPC, missing original, invalid manifest,
symlinked parent, two lifecycle writers, custom XDG paths, spaces in checkout,
repeated install/remove/recover. Use disposable homes and stub external effects.
Power-loss/filesystem durability needs a separate VM test, not just exceptions.

Exit: no injected cut deletes an unverified original or leaves unexplained
state; owner edits survive; rerun converges or returns a precise conflict.

## H2 — Acknowledged settings, state, themes and display trials

Addresses R02/R05/R07/R11.

- Add real offscreen permission-denied regressions for Settings and StateFile.
  Handle `saved`/`saveFailed`; do not apply/acknowledge a committed state on failure.
- Serialize/coalesce writes safely; revisions detect competing shell, Settings
  and external-editor changes. Define migration and reset semantics per document.
- Make quarantine conditional on successful preservation. Keep failed pending
  intents and distinguish unreadable, malformed, invalid schema and unwritable.
- Own display rollback independently of the Settings window, with trial ID,
  deadline, previous state and backend verification. Crash/close must revert.
- Replace detached dual-file redirections with a transaction for generated
  compositor settings. Keep a tested known-good generation.
- Use the same ownership/fingerprint rules for app theme apply and restore.
  Respect XDG roots and preserve edits made after applying a Bloom theme.

Tests: permission denial/full disk, backup move failure, concurrent writes,
schema migration failure, trial-owner crash, display unplug and apply rejection,
theme midway failure and owner-edited theme target. Actual display changes only
in a disposable compositor/VM; no live owner experiment.

Exit: disk and UI agree on committed values, trials revert without the window,
and restore cannot silently replace foreign edits.

## H3 — Observable operations and useful diagnostics

Addresses R08/R10 and gives later device work a common contract.

Operation result fields: `id`, `component`, `action`, `state`, `errorCode`,
`startedMonotonic`, `durationMs`, `retry`, `exitCode`, `signal`, `verified`.
Terminal states are success, failure or cancellation exactly once. Duplicate
desired-state requests coalesce; destructive actions require a distinct request
and may not auto-replay after an uncertain result.

Event envelope (version 1): UTC timestamp, monotonic duration, level, stable event
name, component, operation ID, session identity, stage, outcome, error code,
attempt and allowlisted detail fields. Session identity must not contain a
username, SSID or application title. Emit request/terminal/recovery transitions,
not per-frame or repeated successful poll output.

| Event family | Required events / safe data |
| --- | --- |
| Lifecycle | plan, validation failure, conflict, lock contention, step committed, interrupted, recovered, rollback incomplete; operation/step IDs and content fingerprints, not file contents |
| Session and shell | profile/readiness, environment imported, start/skip/stop, abnormal exit, rate-limit recovery; session generation and reason |
| Storage/settings | read/validate/quarantine/save/conflict/migrate outcome; document/key identifiers, revision, bytes and error class; never values by default |
| Backend capability | available/missing/degraded/conflict/recovered; backend name/version and age |
| Process/operation | accepted, started, timeout, cancelled, exited, readback failed; allowlisted executable/action, exit/signal and bounded duration |
| Network/Bluetooth | radio/connect/disconnect/pair lifecycle and errors; opaque per-session device token, no SSID/MAC/PIN/password |
| Audio/display/brightness/power | requested/verified hardware state, absence, denial and trial-revert; safe numeric values, opaque device token |
| Notifications/tray | ownership acquisition/loss/conflict, ingest/drop counters and persistence errors; no notification body/title or app content |
| Lock/PAM/polkit | lock requested/secure/recovery, auth success/failure/cancel, agent registered/conflict; no response, PIN, keypress or PAM prompt content |
| Launcher/OSK/apps | action kind accepted/completed/failure, injection unavailable; no search text, shell command text, window titles or typed keys |
| AI/weather/external requests | provider, request category, duration, status/error, timeout/cancel; no API key, prompt, answer, IP/location or query string |
| Recording/OCR/shelf | operation state, byte counts, finalization/error; no screenshots, paths, clipboard, OCR text or notes |
| Theme/wallpaper | supported target, generation, conflict/apply/restore outcome; redact personal paths |
| Resources/rendering | aggregated CPU/RSS/event rates, dropped frames, asset failure, low-power transitions; opt-in sampling, no every-frame logs |
| Support/export | redaction version, included categories, size, creation outcome; no automatic upload |

Use journald for runtime/supervision, with a bounded private lifecycle JSONL
ledger because the CLI must also work outside the desktop. Proposed initial
ledger policy: mode `0600`, private `0700` directory, 5 MiB × 4 generations,
maximum 14 days. Validate budgets rather than claiming these are implemented.
Runtime retention follows system journal policy; do not alter global journald
configuration. Debug categories expire and cannot disable secret redaction.
Active transaction originals are not ordinary logs and cannot age out.

Doctor needs human and versioned JSON output, explicit healthy/degraded/failed
verdict/exit status, last failures and recovery instructions. It should probe
socket/session, service limit, persistent state, enabled capabilities, exclusive
bus owners, dependencies and last-good deployment even when Bloom will not start.
Support export is an allowlisted, previewable private artifact; raw journal and
settings dumps are not a safe export format.

Tests: missing binary/start failure, hang/large output/cancel/process-tree exit,
out-of-order completion, event-rate cap, synthetic secret redaction, retention,
disk-full diagnostics and doctor without service/session/network. Failure to log
must not prevent locking or destroy the operation's recovery journal.

Exit: every migrated operation has one traceable terminal outcome; doctor
identifies the fault without leaking user content or making changes.

## H4 — Desktop capability and backend resilience

Addresses R06/R08/R12 and runtime portions of R13.

- Migrate one existing backend cluster at a time to the operation/health contract:
  compositor/session → hardware display/audio/brightness/power → NetworkManager/
  BlueZ → exclusive notifications/tray/polkit → region/recording → optional tools.
- Define capability state separately from configured intent and observed device
  state. A setting being true is not proof that a daemon is present or responsive.
- Handle D-Bus owner changes, missing optional tools, hotplug and suspend/resume;
  bounded exponential backoff with caps and user-visible retry, no global loops.
- Recorders get owned unit/process identity and verified finalization; shell
  restart must not accidentally terminate a recording or unrelated app.
- Centralize desired-state setters; keep device-specific readback and auth
  policies in their backend. Keep secrets on dedicated private paths.
- Expose controlled repairs for Bloom-owned resources. Any requested restart of
  a shared desktop daemon names the impact and uses native authorization. No
  broadkill, competing notification agent or silent network radio changes.
- Separate native Hyprland and UWSM session profiles; do not infer either from
  a binary merely being installed. Detect and refuse unsupported profiles.

Tests: drop/restart each backend while the corresponding panel is active,
unplug a device mid-operation, deny/cancel auth, stale response, reentrant request,
multiple screens, repeated relogins, lock crash and reconnect. No real password
or power action in automated tests; secure-session tests remain isolated.

Exit: the coverage matrix has verified failure/recovery outcomes per supported
backend; optional failure does not take down unrelated UI or security surfaces.

## H5 — Staged release activation and request/privacy budgets

Addresses R09/R11/R14 and release/dependency handling.

- Introduce immutable candidate/last-good deployments and a small activation
  interface. Build and inspect candidate before changing the live pointer.
- Validate config compatibility and health acceptance, then commit promotion;
  retain previous code and configuration generation for explicit rollback.
- Report package and filesystem recovery separately; never promise an automatic
  OS downgrade. Verify declared optional/required capabilities before activation.
- Standardize bounded HTTPS requests and latest-query cancellation. Remove
  undisclosed plaintext geolocation fallback; degrade to explicit location setup.
- Bound AI streaming memory/time, image/preview bytes and notification/history
  bytes. Record metadata only. Preserve keyring/stdio secrets and native auth.
- Document app-theme support limitations and keep the source/code/asset licenses
  and reproducible generation provenance attached to releases.

Exit: a broken candidate cannot silently replace the last-good desktop, rollback
scope is truthful, and external requests/diagnostics respect declared privacy.

## H6 — Release acceptance from installation to removal

Run focused tests while changing each work package. Ask the owner before a full
suite run. A public release requires current-commit CI plus a disposable Arch VM
acceptance ledger covering:

1. Clean prerequisite install, dry run, normal install, repeated install.
2. Missing dependencies, offline mirror, denied package auth and failed build.
3. Existing owner config, customized XDG roots, spaces and absent optional tools.
4. Cold SDDM login, repeated logout/login, shell crash and service rate limit.
5. Owner-confirmed lock/unlock plus isolated lock crash/PAM cancellation tests.
6. Suspend/resume and hardware disconnect/reconnect on available test hardware.
7. Config/state failure and recovery; support bundle redaction and bounded logs.
8. Healthy update, broken candidate, interrupted activation, rollback and retry.
9. Uninstall twice, interrupted uninstall, missing/corrupt original, edited files.
10. Validate original owner files, shared services and preexisting packages remain
    intact; no active manifest references deleted backups; no orphan daemons.

Repeat resource/idle/visual soaks only for changes affecting them. The ten-minute
historical dock/notch soak does not prove a new architecture's resource behavior.
Publish supported capabilities, measured gates and remaining limitations; never
replace this ledger with an absolute claim of handling every possible failure.

## Work tracking / completion rule

Every work package ends with its tests, removed experiments, migration notes,
documentation and an AGC handoff tied to a commit. Findings close only with
evidence at the real interface; source edits alone do not close them. Preserve
the baseline and owner-local rollback data until their dependents are retired.

Current state (2026-11-11):

- **H0–H5: complete.** Contracts and evidence are in the ledger and handover
  docs: theme ownership, state documents, observability, backend resilience,
  staged updates and budgets.
- **Deferred, with rulings:**
  - Immutable per-commit deployment directories (H5). They need an
    install-layout migration. Until then, updates rely on candidate validation
    and a health-verified rollback.
  - A manual compositor snapshot restore command in `bloom doctor` (H2/H3).
    Doctor reports the snapshot count.
- **H6: open.**
  - The disposable Arch VM acceptance passed 48 of 48 checks on the released
    `main` (`2415b8f`). Earlier VM SDDM, suspend, USB hotplug and ENOSPC
    checks passed at `1ae4730`.
  - Not yet tested: suspend/resume and hotplug on physical hardware, a
    password-entry greeter, a UWSM login, and real power loss.
- **Verification on `main`:** the last supervised full local gate passed at
  `39ddb96`. GitHub CI is green at `2415b8f`.

This document is not approval to run a full suite or mutate unrelated
services/packages.
