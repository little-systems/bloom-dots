# UI state documents

`shell/services/StateFile.qml` keeps one JSON document per feature in
`$XDG_STATE_HOME/bloom/<name>.json`. Settings are separate
([settings transactions](settings-transactions.md)). The shell is the only
cooperating writer; Settings and the CLI never write these files.

## Contract

- **Load:** each document goes through three checks in order: a UTF-8 byte
  budget, JSON parsing, and the document's `validate` shape check. A failure is
  classified as `too-large`, `malformed` or `invalid` (`errorKind`). The file is
  moved to `<name>.json.bak`, and the default is used. Writes stay blocked until
  that move succeeds; if it fails, `quarantine-failed` blocks writes and keeps
  the evidence.
- **Retention:** quarantine keeps the newest plain `.bak` and the two newest
  numbered `.bak.~N~` backups. Pruning can't fail a quarantine.
- **Save:** a save larger than the budget, or of the wrong shape, is refused
  (`save()` returns false). The last committed value and the file are kept.
- **Save failure:** an `unwritable` failure keeps the value pending for
  `retry()`, which reloads the file first.
- **External edits:** the file is watched. A valid replacement by another
  program is adopted: `value` follows it and `externallyChanged` fires. A local
  save that hasn't started writing yet is dropped, with `errorKind` set to
  `external`, rather than overwriting the newer file. Bloom's own writes, and
  reloads that differ only in formatting, are not reported as changes.
- **Deletion:** a document deleted while running falls back to the default,
  announces the change, and is recreated by the next save.
- **Limit:** a save already in flight can still land after an outside write in
  the same instant. Advisory locking can't stop a writer that doesn't cooperate.

## Documents

| Document | Shape check | Budget | On external change | Reset / migration |
| --- | --- | --- | --- | --- |
| `dock` | object | 64 KiB | dock order recomputes from `value` | default `{pinned: [], order: []}`; no versions yet |
| `notifications` | object, `entries` array if present | 1 MiB | history restored from the file (history limit applies) | default `{entries: []}`; restore drops malformed entries |
| `notch-panel` | object | 4 KiB | last panel re-read if it's a known one | default `calendar` |
| `weather` | object | 16 KiB | cache only; the next refresh replaces it | default `{}` |
| `calendar` | object | 4 KiB | timer state restored; an expired timer finishes | default 25-minute idle timer |
| `shelf` | array | 2 MiB | items cleaned and re-pruned when shelf persistence is on | default `[]` |

All documents are at format version 1, which is the current unversioned format.
Shape checks are deliberately top-level only, because each feature's restore
function already normalises fields. That way an odd field never quarantines a
whole history. A future format change must add a version field and a
migration, and treat a version newer than the code knows as `invalid`, so the
file is quarantined rather than overwritten.

Tests: `tests/integration/test_state.sh` (store behaviour, including external
edits, shape, budgets and retention), `test_persistence_failures.sh`
(permissions, retry and quarantine failure) and `tests/qml/tst_state.qml`.
