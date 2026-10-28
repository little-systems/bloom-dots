# Phase 5: notch panels

Status: implementation in `codex/phase-5-notch-panels`. Owner requested Phase 5 on 2026-10-28. The live shell stays on `main` until all panels and services pass review and an owner-visible live check is ready. No push.

## Target

Port Bloom's tool panels into the existing native notch without changing its collapsed music/status behavior. The panel order is Calendar, Command Center, Devices. A click on the collapsed clock opens the remembered panel; arrows and wheel switch only among enabled panels. Live music, timer, shelf and alerts are separate activities, not remembered as tool panels. Panel dimensions and motion follow the design spec and the Windows source.

## 5A — panel frame and Command Center

1. Add settings for panel availability, default panel and memory, with schema and generated docs. Keep all new panels disabled in the owner's live settings until the reviewed check. Add pure panel-state rules for opening, closing, cycling and the active geometry; unit-test disabled-panel and music-activity cases.
2. Extend the fixed-size `NotchWindow`/`NotchView` stage and input mask to host one lazy panel at a time. Add IPC for `notch panel open|close|next|previous|state`, plus click, wheel and arrow navigation. Keep music and notification history independent.
3. Add services for NetworkManager and BlueZ that observe via D-Bus/monitor events while needed, use bounded commands for mutations, and report missing hardware/tools instead of fake controls. Build Command Center at 350×230, and Wi-Fi/Bluetooth subpanels at 350×300. Include DND, volume, brightness, idle and night-light controls with truthful status. Do not alter the owner's network, Bluetooth, idle or colour settings during automated tests.

## 5B — Calendar, Pomodoro, Todo

1. Build calendar at 480×273/305, month navigation, current day, and the three tabs. Pure date-grid and timer parsing/state rules get unit tests including month boundaries and suspend/restart.
2. Persist todos and active Pomodoro state through `StateFile` with validated primitives. Timer deadlines use wall-clock timestamps and a visible-only UI tick; expiry produces one notification through the existing notification bridge. No background polling while closed.
3. Verify input, completion, deletion, countdown and restart in isolated integration tests.

## 5C — Shelf, devices, privacy

1. Build a bounded text/file Shelf at 380×130/176/190 with validated local paths, drag/drop, explicit open/copy/remove and optional persistence. Never interpret dropped text as a command; preserve user files. Test malformed paths, missing files and state restore.
2. Add read-only udev/PipeWire/BlueZ device events and the Connected Devices panel. Device alerts are transient 330×76 cards; no ownership handover. Test USB and audio events with fake sources. Earbud battery appears only if reported.
3. Observe mic capture and screencast use through PipeWire/portal state and show privacy dots in the collapsed notch. Confirm they disappear promptly when use ends, including a restart.

## Verification and live boundary

- Each part gets focused pure-rule tests and an isolated headless Quickshell integration run. `CI=true tests/run-all.sh` must pass at the end; inspect warnings, idle CPU and no new always-running helpers.
- Compare visible panels against the Windows source: dimensions, spacing, colour, typography and open/close motion. Capture screenshots on an isolated compositor before considering the owner's desktop.
- Local branch review fixes precede any merge. The live check will use read-only inspection and reversible settings first. Network, Bluetooth, idle, night-light and file mutations are not part of the live smoke test without a separate concrete owner approval. Keep ii's remaining surfaces available during Phase 5.
- Fast-forward local `main` only after the code and tests pass, then check the service, all enabled modules, notification ownership, panel navigation and restoration of the owner's previous settings. Do not push.
