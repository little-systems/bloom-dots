# Hardening implementation ledger

This follows the [baseline audit](2026-11-03-reliability.md) and
[program](../plans/2026-11-03-reliability-hardening.md). It does not replace
their historical evidence or declare the whole program complete.

## Current batch

| Area | Implemented | Validation and remaining limits |
| --- | --- | --- |
| R01 uninstall originals | Verify every required backup before stopping/changing files; fingerprint new originals; stage restore; journal complete removal plan; retain originals until service/file restoration commits | Missing/corrupt original and interrupted removal regressions pass. Legacy originals without saved fingerprints cannot establish historical integrity. Theme restoration remains a separate H2 gap. |
| R03 manifest/path/lock | Strict field/fingerprint/status/duplicate checks; closed public resource paths; reject traversal and redirected parent paths; canonical lock identity, owner checks and nonblocking exclusive lock | Malformed ledger, traversal, parent redirection and concurrent writer regressions pass. Not a security barrier against malicious same-user concurrent filesystem mutation. |
| R04 install interruption | Write-ahead pending steps; adjacent staged replace, file and directory syncs; inspect/resume/restore-originals CLI; settle intents no longer present in a regenerated plan | SIGKILL before/after every install replacement in the fixture passes; selected removal cut points and edit-after-cut refusal pass. Real power loss/ENOSPC, every uninstall syscall and immutable deployment rollback remain unverified. |
| Reconciliation | Matching install avoids service restart; explicit `--restart`; repeated removal is a no-op | Reinstall/no-op/roundtrip tests pass. Source edits inside live symlink targets need explicit restart or `update`; immutable deployments remain H5. |
| Journal compatibility | New mutations write manifest v2; reader accepts v1/v2 | Old v1-only lifecycle tools refuse v2. A rollback to old code does not downgrade the journal; retain a compatible recovery checkout. |
| R02 settings acknowledgment | Handle save failure; retain committed values; reload FileView cache before retry; validate import/reset as one batch; propagate errors through theme/wallpaper IPC | Actual offscreen read-only-directory failure, retry, batch rejection, durable-save and Settings-app integration checks pass. Settings patches now share the transaction writer described below; StateFile cross-process semantics remain pending. |
| R07 state/quarantine | Keep pending data on failed writes; explicit retry; restore committed value; block writes when read/quarantine fails; quarantine success logged after completion | Actual failed writes/retry/failed `mv` plus existing corruption/early-save races pass. Schema versions, document byte budgets and retention remain pending. |

No runtime package operation, live uninstall/reinstall, real logout or full
suite was used for the initial focused batch. The existing owner installation manifest and
available backup paths were validated read-only. Owner-local migration fixtures
were checked; their test expectation was adjusted locally for explicit reinstall
restart, without publishing migration code or changing the real migration.

## Approved complete-gate result and correction

The owner approved one complete local gate at `caff4e4`. That run passed all
978 QML cases and earlier checks, then failed notification integration waiting
for cleared history on disk. It did not finish the later integration/CLI/unit
steps. The private raw result is `hardening-ci-caff4e4.log`; exit status 1.

An isolated regression reproduced the cause: FileView emits no `saved()` event
for an identical-text write, leaving `_writing` set and preventing subsequent
state writes. `88b6819` makes a confirmed unchanged save an explicit no-op.
The new state regression, storage-failure/retry/quarantine checks and complete
focused notification integration (including clear-all) pass. This is a verified
focused correction. The owner then approved a second complete gate at
`fc7b358`: every check passed, exit status 0 (private log
`hardening-ci-fc7b358.log`). That green result covers that checkpoint; later
changes require their own validation and fresh approval for another full run.

## Scoped owner additions

- `c40dd62`: Settings fixed to the observed 1189 × 781 logical window size,
  independent of UI/font scale, clamped to smaller screens. Equal minimum and
  maximum size; actual live dimensions confirmed. Isolated Settings-app check
  passes. Main hardening work remained separate.
- `c93b258`: smart notch respects overlap during startup; fullscreen suppresses
  prior interaction and edge reveal. Pure rule/view regressions and a real
  headless-compositor controlled-window test pass. Smart visibility returns when
  the covering window leaves. This verifies those routes, not every possible
  cause of the owner's intermittent screenshot; recurrences should retain safe
  `startupAnimating`/`suppressed`/overlap/interaction diagnostics.
- `55877f7`: compact media card inside the secure lock surface, with artwork,
  title/artist and capability-guarded previous/play-pause/next. Shows after
  playback and remains after pause for resume; no desktop app-launch action.
  Settings → General has a privacy toggle (`bloom-lock-media-enabled`). Added
  transport guards outside secure lock / during unlock / when disabled. All 21
  lock-view cases, focused Settings toggle checks, a real isolated secure-lock
  media test and existing PAM/crash-recovery integration pass. Screenshot was
  inspected before bringing it into the live checkout. No real owner lock was
  triggered. Temporary feature worktree/branch was removed after reconciliation.

## Remaining program

Superseded by the status below (2026-11-11). This paragraph described the first
batch only.

H0–H5 are complete; the later sections record their batches and evidence. H6
release acceptance is open: a VM acceptance on the current `main`, plus physical
suspend/hotplug, a password greeter, UWSM and power-loss checks. Full-suite
execution still requires the owner's separate approval.

## Lock media design follow-up

The owner rejected the enlarged `d3dd0e6` card and requested the previous
360 × 134 footprint with complete playback controls. The revised layout has
artwork/metadata, elapsed/duration with seeking, previous/play/next, and output
volume. Seek and volume share the secure/locked/not-leaving/privacy guards;
values are finite and clamped, unsupported seeking is disabled. Position polling
is held only during secure lock media display and released on unlock/destruction.
No mixer or desktop app can be opened from this card.

The owner's circled controls exposed two problems: oversized pause relative to
skip glyphs and skip glyphs positioned at the left of larger hit areas. The shared
SkipButton now centers its glyph viewport; default-size notch controls retain
their geometry. Lock controls use equal 36-pixel hit areas, balanced glyph sizes,
and matching hover/press scales. All 23 LockView cases (including geometry and
seek/focus), focused music-component cases, and isolated secure-media integration
pass. Screenshot inspected before live update. No additional full gate ran.

## Smart notch recurrence

`04dbefd` replaces foreground-only overlap with all visible windows on the
active workspace (including pinned windows); a small focused floating window
cannot reveal the notch over a covering tiled application. New application focus
and newly arriving overlap cancel old reveal/panel state. The old decision fails
the new regression; the revised rule passes 15 logic and 67 view cases plus an
isolated compositor test of startup, fullscreen, floating focus, explicit reveal,
focus cancellation and visibility recovery. The owner's exact intermittent
screenshot was not captured live before its state changed; these are verified
failure routes, not proof of every possible cause. Safe IPC diagnostics now
include pointer/reveal sources, monitor/workspace, polling and client count.

## H2 settings concurrency batch

The old cached-snapshot save failed a deterministic editor-interference regression.
Settings now uses asynchronous validated patches with explicit pending receipts
and durable completion, a shared lock/fresh read/merge/atomic replacement writer,
per-key conflicts and content revisions. Callers wait for commit before reporting
success or performing dependent actions; CLI success still means committed data.
The prior synchronous `Settings.set` return contract is intentionally replaced:
raw IPC consumers must handle pending receipts. See
[settings transactions](../handover/settings-transactions.md) for the exact
contract, evidence, non-cooperating-editor interval and remaining limits.

No full suite, live settings mutation, package change, push or merge is included.
The next H2 priority is display rollback independent of the Settings window,
followed by generated configuration transactions and theme ownership restoration.

### Settings batch complete gate and activation

The owner approved one complete gate at `d2d9790` in the isolated worktree.
`CI=true tests/run-all.sh` passed: 987 QML tests, all integration and CLI checks,
lifecycle cases and systemd verification; exit 0. Private raw log:
`hardening-ci-d2d9790.log`. No second complete run was used.

The identical tested tree was reconciled locally as `87bbd91` and activated.
Bloom is active and answers `pong`; the Settings result interface is available.
The owner's settings SHA-256 was unchanged before/after activation. There was no
separate old Settings process to replace. No owner setting was changed to test
writes; write behavior was exercised in disposable fixtures. No push/main merge.

## Scoped About page addition

The owner requested distro metadata and original branding alongside Bloom.
About now reads allowlisted `/etc/os-release` data (fallback `/usr/lib/os-release`)
without evaluating shell text, resolves the system-provided LOGO asset without
recoloring it, and presents paired Bloom/distribution identities with metadata.
Unavailable fields are omitted and narrow widths stack the identities.

Data actions were real operations, but native dialog parentage and premature
export-success reporting needed correction. File dialogs now have the actual
Settings window parent. Export stages a private mode-0600 copy and reports success
only after file/directory sync and replacement; invalid input/unsafe targets keep
existing data. A real native-dialog export/import round trip passes in isolated
XDG/compositor state, so the working Data section is retained rather than removed.
Fourteen system-rule cases, focused About row/metadata checks, export failures,
qmllint, cursor and shell checks pass; screenshot inspected. No additional full
suite ran: the complete gate recorded above covers the earlier settings batch.
Main hardening remains at the independent display-watchdog/config-commit work.

## H2 independent display trials and atomic compositor document

An isolated batch replaces dual generated-Lua/JSON redirections with one owned,
versioned Lua document containing its state. Fresh revision checks, a private
lock, immutable prior snapshot and synced atomic replacement protect cooperating
writers. Legacy JSON remains read-only input, and inconsistent/manual edits are
refused rather than silently overwritten. The previous native geometry and trial
identity are recorded before applying a mode.

Display rollback now belongs to a transient user worker, independent of Settings.
The worker verifies apply/revert, expires unconfirmed trials, recognizes Settings
PID identity loss and reconciles interrupted Keep persistence. Settings only sends
owner-bound requests and observes terminal results. Unsupported advanced profiles
are refused before effects; outside changes and unplug are explicit outcomes.
See [display transactions](../handover/display-transactions.md) for contracts and
limits, including remaining live/VM, retention and recovery-tool acceptance.

Focused checks: nine compositor storage cases, sixteen display fault cases,
actual Settings process SIGKILL with independent worker rollback against fake
hardware, real Settings Keep-to-durable-store fixture, display UI controls,
Settings app startup/navigation, qmllint, shellcheck, cursor and diff checks.
This batch is not live, not pushed/merged, and has not run a new complete gate.
H2 remains open; the broader hardening program is not finished.

### Display batch complete-gate attempt

The owner approved one complete run at `2b0e7e2`. It passed lint, 990 QML
cases and parity/reference checks, then stopped at the generated Settings search
index check (exit 1). Four metadata rows from the preceding About addition were
missing from the index. The regenerated index passes its `--check`, and both
focused Settings search interaction cases pass. No integration/CLI/lifecycle
results are claimed from this incomplete full run; earlier focused results
remain separate evidence. The private log is `hardening-ci-2b0e7e2.log`.

The source correction is isolated; no live activation or push/main merge occurred.
The approved full run is consumed. A further complete gate needs fresh approval.


### Supervised display gate passed and reconciled locally

The next approved terminal-bound run at `dd8cbf8` was interrupted by SIGTERM
before a complete result; its sender is unconfirmed. The diagnostic Settings
View rerun passed all 64 cases. That interrupted run was not called green.

The owner then approved one supervised gate at the same immutable `dd8cbf8`.
The bounded transient user test unit completed successfully: 990 QML cases,
all script/integration/CLI/lifecycle/soak checks and systemd verification;
`FULL_SUITE_EXIT=0` with a matching completion receipt. Private artifacts:
`hardening-ci-dd8cbf8-supervised.log` and
`hardening-ci-dd8cbf8-supervised.result.json`. No further complete run was used.

Both tested commits were reconciled onto the local active hardening branch as
`a6739c7` and `c8ca3d3`; `git diff --exit-code dd8cbf8 HEAD` verified an identical
tree before this documentation update. Settings is closed and loads the new code
on its next open, so no shell restart or forced window close was necessary. Bloom
remains active and answers `pong`, and the new compositor reader accepts the live
legacy preferences read-only. The settings JSON, generated compositor Lua and
legacy compositor JSON hashes were unchanged across reconciliation. Private
activation receipt: `display-batch-activation-dd8cbf8.json`.

No owner monitor trial, push or main merge occurred. H2 still needs StateFile
schemas/concurrency/retention, ownership-aware theme restoration, and the remaining
live/VM fault acceptance; H3–H6 remain open. This gate is complete, not the entire
hardening program.

## H2 completion batch (2026-11-11)

Branch `hardening/h2-state-themes`, isolated worktree; the live checkout is
unchanged.

- `fb8af1f` app themes: renderers write into staging, and `theme-owner.py`
  installs and restores only files Bloom still owns. That means SHA-256
  fingerprints, a pending fingerprint before each write, conflicts for owner
  edits, deletions and symlinks (exit 3), XDG roots and legacy manifest
  adoption. See [theme ownership](../handover/theme-ownership.md).
- `1a51756` state documents: watched files, adoption of external replacements
  and announcement to callers, per-document shape checks and byte budgets,
  error kinds, and quarantine retention. See
  [state documents](../handover/state-documents.md).
- Retention: crash temporaries for settings, compositor and theme writers,
  compositor history (10) and finished display trials (10) are bounded.

Focused checks:
- Python: theme ownership (13), retention (6), settings, compositor and
  display store cases, lifecycle (all).
- Script: app-theme and wallpaper-theme tests.
- Integration: state store, persistence failures, settings concurrency and
  durability, compositor store, display trial (real Settings crash), dock order,
  notifications, dock.
- The full QML suite (993) ran as a plain `qmltestrunner` run, not a complete
  gate.

H2 status: the code contracts are implemented. Live/VM acceptance (real
monitor trial, power loss/ENOSPC) moves into the H6 matrix. A manual
compositor snapshot restore is deferred to H3's doctor/recovery tooling.

## H3 and H4 batches (2026-11-11)

- H3 `1a0828c`: typed operation results, a private redacted event ledger,
  read-only `bloom doctor --json` (exit 0/1/2) and `bloom support`. See
  [observability](../handover/observability.md).
- H4 `3833851`, `16332da`, `8313ad6` and this batch's follow-up:
  - supervised monitors with bounded backoff
  - a capability registry with IPC snapshot/retry, checked by doctor
  - NetworkManager/BlueZ missing-service classification
  - verified recorder identity and finish
  - Hyprland-only unit condition and UWSM detection
  - atomic overlay notes
  See [backend resilience](../handover/backend-resilience.md).
- Owner-requested live fix (outside the branch): `misc.focus_on_activate = false`
  was written through Bloom's compositor writer to
  `~/.config/hypr/custom/bloom-settings.lua` (backup
  `~/Projects/bloom-backup-20261111-085512-focus/`), so apps such as the ChatGPT
  window can't switch workspaces. It was verified after `hyprctl reload`.
- A doctor false positive was corrected: Bloom never runs `bluetoothctl`. The
  dependency map now lists only the commands Bloom invokes.

## H5 batch (2026-11-11)

- `5b273d1`: request, assistant and clipboard budgets. Weather no longer uses a
  plaintext lookup or a default location.
- This batch also adds:
  - staged `bloom update`: candidate validation before the checkout moves,
    plus a health-verified rollback with an honest verdict and `lastGood`
  - font license notices for all bundled fonts, with a test
  - documentation of app-theme limitations
- Ruling: immutable per-commit deployment directories are deferred; see
  [staged updates](../handover/staged-updates-and-budgets.md).

## Complete gate at 035e5c0 and correction (2026-11-11)

The owner approved one complete gate at `035e5c0`. `CI=true tests/run-all.sh`
passed lint, shellcheck and 998 of 999 QML cases, then stopped (exit 1) on
`BluetoothView::test_refreshKeepsTheScroll`: the glide did not settle within
0.2 px of its target. The later script, integration and CLI stages did not
run, so no result is claimed for them.

The failure did not reproduce alone, under CPU load, or with neighbouring test
files. Instrumentation found that the glide ends at 199.80 instead of 200 even
on an idle machine. `Spring` marks itself settled before it snaps its value, so
`ScrollGlide` never wrote the target, and the stopping point depends on frame
timing. Separately, a view's own sub-pixel layout rounding cancelled glides.

The corrected commit (next) adds regressions that failed first. All 1001 QML
cases and the notification and panel scroll integration tests pass in a plain
run. A new complete gate needs fresh owner approval.

## Released to `main` and activated (2026-11-11)

The owner approved a supervised full gate at `39ddb96`: exit 0, 1,002 QML
cases and all later stages (receipt
`hardening-ci-39ddb96-supervised.result.json`).

The first GitHub CI runs on the branch found faults that only appear in CI's
minimal container. Each was fixed and verified:
- the region-tools recorder fake raced its own signal handler
- an exited recorder was not reaped in the container
- missing system services were logged as warnings (now info)
- integration tests each kept their own copy of the allowed machine-noise list
  (now one shared list)
- the native file dialog was driven by keystrokes before it had focus
- Qt Quick's fallback file dialog could not be used from the keyboard, now
  replaced by `Qt.labs.platform` dialogs that start in the home folder
- shell helpers were still running during test cleanup
- `cmp` is unavailable in the container

GitHub CI passed at `2415b8f`. `main` was fast-forwarded and pushed
(`f00bf13..2415b8f`). The owner's live checkout now runs `main`. After a unit
reload and restart, `bloom doctor` reported healthy with 11 of 11 checks OK.
App-theme files were adopted into the ownership ledger: 11 targets, all with
their originals saved.

Rollback:

```sh
git switch --detach 1316527 && systemctl --user daemon-reload && systemctl --user restart bloom-shell
```

## H6 VM acceptance at `2415b8f` (2026-11-11)

A fresh disposable Arch VM passed `tests/vm/acceptance.sh` on the released
`main` (`2415b8f`) with 48 of 48 checks and `ACCEPTANCE_FAILURES=0`. The
stages were prerequisites, install (including a real `bloom-shell-deps` build),
session (autologin, relogin, crash-loop limit and recovery), state and
diagnostics (damaged state, support bundle preview, privacy and redaction),
update (healthy update, broken candidate refused, rollback) and uninstall
(restore, twice, reinstall, SIGKILL mid-uninstall then resume).

H6 still needs the checks the VM can't provide: suspend/resume and hotplug on
physical hardware, a password-entry greeter, a UWSM login and real power loss.


## Release gates for v1.0.0 (2026-11-13)

- **VM acceptance at `2fb28bb`:** 48 of 48, `ACCEPTANCE_FAILURES=0`. The run
  before it, at `2a66def`, found one regression (`install --no-deps` without
  Quickshell was no longer refused), fixed in `2fb28bb`. The fresh install from
  an archinstall-style chroot passed at `2a66def` (`CHROOT_INSTALL=ok`).
- **Idle CPU on the owner's Intel UHD 620 machine:** 0.91% of one core,
  averaged over 30 ten-second windows (301 s) in which the pointer and the
  focused window did not move; the busiest window was 3.4%. While the desktop
  is in use the shell takes 0.7–4%, with short bursts while surfaces animate.
- **Soak:** waived by the owner for this release.
- **Physical checks** (suspend/resume, monitor hotplug, UWSM login, power
  loss): the owner runs these on the live host. The password greeter is in
  daily use on that machine.
- **Owner live check** after the app-defaults work: lock fade, dock extras
  icons, kitty and the idle backend confirmed.
