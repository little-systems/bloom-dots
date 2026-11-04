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

The complete corrected logout/login handoff still needs owner acceptance.
H1's remaining fault matrix/VM evidence and H2's remaining state-store semantics,
independent display rollback and ownership-aware themes are open. H3 operational logging /
doctor, H4 device/daemon recovery, H5 staged activation / request budgets and H6
real Arch lifecycle acceptance are not implemented by this batch.

Full-suite execution requires the owner's separate approval. Historical green
CI at `f00bf13` does not validate these commits. No push or merge is included.

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
