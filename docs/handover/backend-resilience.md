# Backend capability and resilience (H4)

## Capability is separate from intent and device state

`Capabilities` (singleton) records each backend's current state:
`available`, `degraded`, `missing`, `stopped` or `unknown`. Each entry also has
a reason, an attempt count and a `since` time. This is kept apart from what the
owner configured (settings) and from what the device reports (for example
"no adapter"). Each state change is logged once. Two IPC calls use it:

- `bloom ipc capabilities snapshot` returns version-1 JSON.
- `bloom ipc capabilities retry <backend>` restarts a Bloom-owned backend
  process now. It never restarts shared system daemons.

`bloom doctor` reports degraded and missing backends while the shell answers.

## Supervised processes

`SupervisedProcess` replaces the ad-hoc monitors. It runs while `wanted` is
true. If the process exits, or can't start, while still wanted, it restarts
after a bounded exponential backoff (1 s, 2 s, 4 s … 60 s). The backoff resets
after 30 s of stable running, and there are no global loops.

A program that can't be found is reported as `missing`; Quickshell emits no
start or exit signal for it, only a drop in `running`. `restart()` applies a
new command, such as night-light warmth, without counting a failure.

Migrated monitors:

| Backend | Process |
| --- | --- |
| `network` | `nmcli monitor` |
| `bluetooth` | `dbus-monitor` BlueZ signals |
| `brightness` | `udevadm` backlight events |
| `devices` | `udevadm` USB/sound/video/block events |
| `audio-events` | `pactl subscribe` |
| `drives` | `udisksctl monitor` |
| `night-light` | `hyprsunset` |

Before this change, every monitor except brightness and drives stopped for
good when its daemon restarted. Those two retried on a fixed 30 s timer.

Query backends report their capability with a reason:
- `networkmanager`: a stopped NetworkManager or a missing nmcli is `missing`
  ("NetworkManager isn't running"). It is not reported as "no Wi-Fi".
- `bluez`: a stopped bluetoothd or no system bus is `missing` ("Bluetooth
  service isn't running"). It is not reported as "no adapter".

## Recordings

The recording record holds the PID, the kernel start time and the output path.
Only a process named `wf-recorder` with a matching start time is signalled, so
a PID reused after a crash is never interrupted. Old single-PID records aren't
trusted.

Stopping waits up to 10 s for the recorder to exit. It reports "Recording
saved" only when the file exists. Otherwise it reports that the recording
failed, or that the recorder is still finishing. Recording names never reuse an
existing file. Recordings run in their own session, so a shell restart doesn't
end them.

## Session profiles

- **Unit condition:** `bloom-shell.service` requires a live Wayland socket and a
  live Hyprland instance socket (`%t/hypr/<signature>/.socket.sock`, with a
  safe signature). Another desktop using `graphical-session.target`, or a dead
  session's leftover environment, therefore skips Bloom without using crash
  retries.
- **Start hook:** `hypr/bloom.lua` reads Hyprland's own cgroup. Under UWSM
  (`wayland-wm@…`), UWSM imports the environment and starts the target, so the
  hook does nothing. A native session imports the environment and restarts the
  service, as before.
- **Doctor:** it reports the profile. A binary merely being installed never
  decides the profile.

## Other

Overlay notes are written to a temporary file and renamed into place.

## Tests

- `test_supervised.sh`: backoff, missing program, stop, retry, restart and
  IPC retry.
- `tst_backends.qml`: backoff bounds and failure classification.
- `test_connectivity.sh`: stopped NetworkManager and BlueZ against the real
  shell, and their recovery.
- `test_region.sh`: recorder identity, finish verification, lost file and
  PID reuse.
- `session_start_cases.py`: the unit refuses non-Hyprland and dead sessions,
  and UWSM is left alone.
- `test_brightness`, `test_dock_extras`, `test_phase5_devices`,
  `test_bluetooth_agent`, `test_osk_overlay`, and the doctor capability case.

## Live/VM acceptance (H6)

Still to be checked live or in a VM: suspend/resume, real daemon restarts, real
hotplug and multiple screens, an actual UWSM login, and repeated relogins.
