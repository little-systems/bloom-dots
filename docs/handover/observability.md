# Operations, events, doctor and support bundles (H3)

## Operation results

`shell/services/bloom_operations.py` `run_operation()` is the one runner for
Bloom's Python callers. It starts the command in its own process group, bounds
time (default 20 s) and output (64 KiB per stream), and kills the whole group
on a timeout, output flood or cancellation. Children left running when the
command exits are killed too. It returns exactly one terminal result with these
fields:

- `id`, `component`, `action`
- `state`: `success`, `failure` or `cancelled`
- `errorCode`: `start-failed`, `timeout`, `exit`, `signal`, `output-limit`,
  `verify-failed` or `cancelled`
- `startedMonotonic`, `durationMs`, `exitCode`, `signal`, `truncated`
- `retry`: the caller's statement that repeating the request is safe
- `verified`: the result of an optional readback

Toggles and destructive actions pass `retry=False` and must not be replayed after
an uncertain result. Events record the action and outcome, never argv, input or
output.

Migrated callers:
- Lifecycle `run()`: interactive package builds still inherit the terminal and
  have no deadline, but record their outcome.
- Doctor probes.

The QML `Process` callers move to the same vocabulary per backend in H4.

## Event ledger

`shell/services/bloom_events.py` writes envelope version 1 JSON lines to
`$XDG_STATE_HOME/bloom/log/events.jsonl`. Each record has these fields:

- `v`, `ts` (UTC), `mono`, `level`, `event`, `component`
- `op`, `session`, `stage`, `outcome`, `error`, `attempt`
- `detail`: allowlisted fields only. Other keys are dropped and counted as
  `omitted`.

Limits and safety:
- The file is mode 0600 in a 0700 directory. It rotates at 5 MiB into four
  generations, and files older than 14 days are deleted.
- Each process allows 60 events per event name per minute. The excess is
  reported once as `events.dropped`.
- The session token is a hash of the Hyprland instance or session ID. It
  contains no user, host or seat.
- Strings are redacted and capped at 160 characters. Redaction covers the home
  path, the user name, key/token/password assignments, Google `AIza…` keys,
  `sk-…`, GitHub tokens and long opaque blobs.
- Emitting never raises. A full or read-only disk returns False.
- Dry runs and plain `bloom recover` inspection are queries, so they write
  nothing. The log is kept after uninstall; remove `~/.local/state/bloom/log`
  to delete it.

Emitters:
- Lifecycle: started/finished/failed, plus each operation's start and finish.
- App theme commit/restore: outcome and conflict count.
- Display trials: phase only, never outputs, modes or geometry.
- Doctor: writes nothing.

## `bloom doctor`

`tools/bloom-doctor.py` is read-only, and every probe has a 3 s limit. It
checks:
- session and Hyprland reachability
- the user service, including restart-limit and failed states
- shell IPC
- settings file validity and permissions
- unreadable or set-aside UI state
- interrupted lifecycle operations
- app theme ownership
- required and optional dependencies, mapped to their packages
- owners of exclusive D-Bus names (notifications, tray)
- unfinished display trials

It prints human output, or versioned JSON with `--json`. Each check has
`id/status/summary/recovery`, and the report includes `recentFailures` from the
event ledger. Exit status is 0 healthy, 1 degraded, 2 failed. Human output adds
the lock-screen recovery steps and the last 30 journal lines. Those lines are
shown only and are never bundled. Paths under home and secrets are redacted.

## `bloom support`

`bloom support --preview` lists the contents and writes nothing.
`bloom support [--output FILE]` writes a mode-0600 tar.gz to
`~/.local/state/bloom/support/` containing:
- `doctor.json`
- `events.jsonl` (the last 2000 records, redacted again)
- `settings-keys.json` (names and value types only, never values)
- `versions.txt`

Nothing is uploaded.

Tests: `tests/cli/test_observability.sh` (22 cases: envelope, redaction,
rate cap, rotation and age, logging failure, operation states, tree kill,
output bound, cancel, readback, doctor without session/service/network,
interrupted lifecycle, restart limit, damaged state, foreign bus owner,
no-change/no-leak, support preview and bundle), lifecycle event recording, and
the CLI doctor checks in `tests/cli/test_bloom.sh`.

Deferred to H4/H5: the QML operation wrappers, per-backend capability events,
and manual compositor snapshot restore (`doctor` reports the snapshot count).
