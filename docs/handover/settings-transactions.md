# Settings transactions

The shell and Settings app previously wrote their cached whole document. A
regression simulating an editor commit before the watcher event reproduced loss
of unrelated keys. Settings now submits validated patches to the same writer in
both processes (`shell/services/settings-store.py`). The settings JSON stays flat
and retains unknown keys; no schema migration or new daemon is required.

## Commit contract

- `Settings.set(key, value, completed)` and `setMany(changes, completed)` return
  `pending:<ticket>` for an accepted request, or a validation/backpressure error.
  A pending receipt **does not mean saved**. The callback receives an empty string
  only after a confirmed durable commit; other strings describe a refused or
  unconfirmed operation. Values are applied from committed storage, not optimistically.
- `Settings.result(ticket)` and `writeFinished(ticket, error)` expose terminal
  outcomes. The shell's `settings result` IPC exposes the former. Raw Quickshell
  callers must handle pending receipts. `bloom ipc` waits for these receipts and
  reports `ok` only after success, with a failing exit status on failed/unknown
  outcomes. Polling has a bounded per-call timeout.
- Requests are serialized within each QML process (at most 32 queued requests).
  Terminal metadata is bounded to 64 results. Tickets include a process-instance nonce
  so an old receipt cannot match a new writer after restart. A disposed/throwing
  completion listener cannot stall the queue. Normal absolute number/bool/enum/
  color edits follow earlier local intents; stale composite read/modify/write
  values retain their original base and conflict rather than dropping an edit.
- Across processes, a canonical adjacent owner-only lock covers fresh read,
  per-key conflict checks, merge, file sync, atomic replace and directory sync.
  Unrelated writes merge; an unexpected change to a touched key rejects the
  entire batch. Setting an already-committed value succeeds without rewriting.
  The reply includes a content revision. Requests/replies travel through pipes;
  settings values are never placed in argv or failure logs.
- The worker refuses malformed/non-object/oversized JSON, unowned/non-regular or
  final-symlink files, unsafe locks, and lock waits exceeding 1.5 seconds. QML's
  worker deadline is three seconds. A timed-out or unconfirmed operation must be
  re-read before retrying; it may have reached the rename before acknowledgment.
- New replacements are owner-readable/writable only. Existing parent permissions
  are not rewritten. A crash before replacement leaves the previous document;
  a crash afterward leaves the new complete document. Forced termination can
  leave an ignored owner-only `.settings-*.tmp` file; retention cleanup is pending.

## External editor limits

A fresh read preserves edits already present, and a second content check detects
an editor modifying the document during preparation. Editors that do not take
`.settings.lock` can still write in the final check-to-rename interval. Arbitrary
non-cooperating filesystem writers cannot be made atomic with advisory locking;
this is not a claim to prevent every simultaneous manual save. Same-key conflicts
already present at read time are explicitly refused. Settings file watchers still
apply hand edits, invalid values still fall back, and invalid JSON is retained.

## Scope and verification

This replaces only Settings persistence; StateFile is not yet a cross-process
merge store. UI state schemas, retention, independent display trial rollback,
generated compositor file transactions and theme ownership remain separate H2
work. No new full-suite approval is implied.

Focused checks exercise 24 independent simultaneous helper writes, two separately
loaded QML processes, editor interference, unknown-key preservation, same-key batch
conflict, rapid local edits, no-op commits, permission/retry, invalid input,
symlink refusal, lock timeout/release, injected pre-commit fsync failure, and
commit-callback durability. Shell/CLI, Settings app, wallpaper and affected media/
dock callers are checked separately. No live owner settings are changed by fixtures.
