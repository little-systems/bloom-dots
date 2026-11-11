# Display trials and compositor preferences

The complete gate passed at `dd8cbf8`; the identical tested tree was reconciled
locally as `c8ca3d3`. Settings loads this batch on its next open. Activation did
not change the owner's monitor/settings files, start a live trial, or restart
the running shell. Actual monitor/systemd crash acceptance remains open below.

## One configuration document

`compositor-store.py read|commit` owns the generated
`$XDG_CONFIG_HOME/hypr/custom/bloom-settings.lua`. The second comment line contains
versioned JSON state; the remaining Lua is generated from exactly that state.
This makes the applied configuration and saved preferences one atomic artifact,
replacing two unrelated shell redirections. The old
`$XDG_STATE_HOME/bloom/hypr-settings.json` is a read-only migration input. No
migration happens on read. Adoption requires the existing Lua and JSON to agree
with the previous serializer; hand-edited or inconsistent configuration is
preserved and mutation is refused.

Commit takes the expected content revision and typed top-level changes on stdin.
A canonical adjacent private lock serializes cooperating writers. Fresh reads,
a final source check, an immutable previous snapshot, private staging, file sync,
atomic replacement and directory sync precede success. Unknown state keys survive.
The previous snapshot is linked from the newly committed document. The document
has a 1 MiB budget; history records have a 4 MiB budget. Reads do not repair files.
Only known generated monitor/layer-rule syntax is adopted. Arbitrary Lua is never
parsed or evaluated by the storage helper.

## Independent trial ownership

`display-trial.py begin` receives output/mode/scale on stdin. It records the
Settings process PID plus `/proc` start identity, allocates a private trial ID,
and starts a transient user unit. The worker owns the display snapshot, native
apply/readback, 15-second confirmation deadline and persistence. Closing or
killing Settings cannot remove the watchdog. A worker restart conservatively
reverts an unconfirmed trial; PID reuse is not treated as the original owner.
Another concurrent trial is refused through a per-Hyprland-session lock.

`keep ID` / `revert ID` record a command for the same owner. The QML UI only
observes status and sends these requests; it no longer owns a rollback timer or
runs detached monitor changes. Confirmation controls wait while an operation is
in flight. A failed launcher or missing status never displays a successful Keep.
Each backend command has a deadline and streaming output budgets; timed-out or
flooding subprocess groups are killed. The worker unit also has an overall runtime
limit. Runtime state contains only required geometry and allowlisted capabilities,
not monitor serial numbers or EDID.

Keep rechecks the native mode and the original persisted entry for that output.
Unrelated saved preferences are retained. A durable confirmation intent identifies
the exact resulting revision before commit. If replacement succeeded but its
acknowledgement was interrupted, recovery recognizes that revision and retries
the durability barrier before reporting Keep. If persistence never committed,
the worker requests and verifies the previous native mode. An unresolved I/O
failure is reported with its recovery record retained; it is not described as a
successful rollback. External mode/profile changes are preserved rather than
overwritten. An unplugged output is reported as disconnected without persisting
a new choice.

## Explicit limits and follow-up

- Backend unit scheduling is tested through a fake launcher in disposable XDG
  state; actual owner monitor changes and real systemd crash acceptance remain
  separately authorized live/VM checks. The process test launches the exact
  worker independently, kills the actual QML Settings process, and verifies
  restoration through a fake hardware backend.
- Mirrored, VRR, non-sRGB and non-8-bit profiles are refused before applying a
  trial. General advanced-profile support is not claimed. Hotplug can prevent a
  physical rollback; the durable previous geometry remains available.
- A cooperating lock cannot prevent an arbitrary editor in the final
  check-to-rename interval. History and temporaries are bounded
  (`shell/services/bloom_retention.py`): the 10 newest compositor snapshots,
  the 10 newest finished trial records, and crash temporaries older than an
  hour. Manual snapshot restore is planned with `bloom doctor` (H3);
  power-loss/real ENOSPC acceptance remains open.
- Runtime records survive Settings/worker exit for the session, not reboot.
  Unconfirmed trials never write a new boot-time monitor preference. This does
  not provide guaranteed recovery from compositor/kernel/hardware failure.
- This is compositor/display persistence only. State documents and theme
  ownership are covered by [state documents](state-documents.md) and
  [theme ownership](theme-ownership.md); operation logging and H3–H6 remain open. No package change, real logout/lock, push, merge or full-suite
  authority follows from these focused tests.

Focused evidence: compositor migration/serialization/conflicts/backup faults;
16 display cases covering owner death, deadlines, rejection, external changes,
unplug, pre/post-replace failures, restart and bounded backend output; real
Settings-to-independent-worker crash and Keep fixtures; Settings display controls
and Settings app startup/navigation. Complete-gate results must name their
immutable commit and cannot be inferred from the earlier settings gate.
