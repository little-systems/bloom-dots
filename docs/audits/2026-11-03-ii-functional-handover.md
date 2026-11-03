# ii functional handover

## Logout and subsequent login recovery

The owner confirmed that logout returned to SDDM after replacing whole-user
termination with Hyprland's normal exit dispatcher. The subsequent login exposed
a separate failure: Bloom retried against the departed display, exhausted its
restart limit, and could not start when the new session requested it.

The service now skips launch while its Wayland socket is absent. On each
Hyprland start, the hook imports the new environment, resets only Bloom's failed
state, and restarts Bloom to replace any process retaining the previous display.
A failed environment import does not start the service. Focused tests execute
the real Lua hook with stub services and exercise the unit's socket guard. Real
systemd unit probes also confirmed missing-display skips and live-display starts.
These checks do not end the owner's session. A further owner logout/login is
still required to validate the complete corrected handoff.

## Agreed scope

The owner confirmed on 2026-11-03 that Bloom keeps its notch, dock and integrated
AI design. Alternate ii bars and a detached sidebar are not required. Google
Lens and booru remain excluded. The target is independent daily operation,
not reproduction of every ii setting or visual layout.

## Coverage checked against the current implementation

| ii responsibility | Bloom implementation |
| --- | --- |
| Bar, vertical bar, dock and workspace controls | Notch, dock, dock workspaces; visibility IPC and fixed/smart/peek modes |
| Left sidebar | Launcher apps, files, calculator, command/web modes, clipboard, emoji and integrated AI |
| Right sidebar and media controls | Notch command center and music panel; NetworkManager, BlueZ, PipeWire and UPower services |
| Notifications | Dedicated notification server and corner card stack, history and DND |
| Authentication and tray | Polkit agent and StatusNotifier watcher/host |
| Lock and session | Session lock with PAM, session action confirmation and running-upgrade/download warnings |
| Wallpaper and theme | Background layer, wallpaper picker/video support and optional adaptive app themes |
| Overview and cheatsheet | Workspace/window overview and generated live keybindings |
| Region selector and screen translator | Screenshot, annotation, OCR, translation and recording scripts |
| Music recognition | songrec integration |
| On-screen keyboard and overlay | OSK, draggable notes, crosshair, stats, mixer and recording controls |
| Timer, todo and file shelf | Notch calendar/timer, todo and shelf panels |
| Privacy activity | Microphone and screen activity indicators |
| Settings | Search, keyboard focus/accessibility, exact number input, separate font/UI scales, system and shell settings |

The 2026-10-31 Settings audit is historical: several of its findings have already
been implemented. Current controls include notification history/timeout/DND,
volume protection, media art/visualizer options, fonts, reduced motion and exact
numeric entry. It must not be treated as a current list of missing features.

## Final concrete gaps addressed

- Fullscreen recording shortcuts previously depended on ii's recording script.
  `region run record-screen` and `record-screen-audio` now select the focused
  display without opening a region picker. They share the existing stop action.
  A missing focused display is an error, never permission to capture all outputs.
- `dock toggleVisible` provides a native shortcut target for the old bar toggle.
- Owner-specific cleanup is maintained outside Git: retire ii global shortcuts,
  map supported actions to Bloom, and remove ii IPC from clipboard producers.
  Original files remain in the local migration undo journal.

## Boundaries and validation

Bloom uses standard external tools and services: Hyprland, hypridle, PAM,
NetworkManager, BlueZ, PipeWire, UPower, cliphist, recording/OCR/translation and
optional theme tools. These are not ii shell processes. Personal compositor
configuration and independent utility scripts are preserved.

This is not exhaustive option-for-option parity. ii-specific decorative layouts,
font-role counts, sensitive-content policies and configuration internals are not
requirements. Automatic power actions must not be enabled merely to match an ii
default; preserve the owner's existing sleep policy.

Focused recording contracts check silent/audio recording, focused-output
selection, stop behavior, cancellation and a missing output. Headless dock
integration checks visibility toggling along with existing pin/reorder behavior.
The owner confirmed the live lock/unlock check. Final suite and live-soak results
are recorded separately; code existence alone does not validate next-login startup.

The live dock/notch soak completed 1,200 cycles each over ten minutes with no
restarts or warnings and 0.19 MiB RSS growth after warmup. The live launcher
check still reports Qt Wayland text-input focus warnings that do not reproduce
in the isolated integration test. Deferring initial focus alone did not remove
them. Experimental surface-lifetime changes were reverted. Warning-free live
launcher acceptance remains open; it must not be presented as passed.

The device-art CI timing expectation was also wrong: the WebP lasts 2,110 ms,
including its final 390 ms frame, whereas DeviceArt stops when that frame first
appears and holds it indefinitely. The corrected test expects arrival at about
1,720 ms and separately verifies the preceding 530 ms and 110 ms holds.
