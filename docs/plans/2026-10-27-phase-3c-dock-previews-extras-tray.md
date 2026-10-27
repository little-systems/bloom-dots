# Phase 3C: Dock Previews, Extras and Tray — Implementation Plan

**Status:** proposed for owner review, 2026-10-27. Do not implement or enable tray from this plan until the owner approves it.

**Goal:** finish the dock's Phase 3 scope: live previews for an app's windows, Bloom-style drive/trash/folder extras, and SNI tray apps merged into the dock. Preserve the existing dock, notch, ii coexistence and the owner's live session.

**Base:** `bloom-dots` `main` at `2616425` (78 local commits ahead of `origin/main` when planned). The notch workspace pulse has been removed; the dock alone owns workspace UI. Implementation, when approved, uses `feat/phase-3c-dock` from current main. Do not push.

**Source of truth:** `docs/specs/2026-10-25-bloom-shell-design.md` D3–D8, §3.3–3.4, §4.1 Dock, §8 phases 3 and 6; Bloom `src/Dock.tsx`, `src/Dock.css`, `src/dockExtras.ts`, `src/dockApps.ts`. Bloom code is reference behavior; no code is reused from ii.

## Global constraints

- The live `~/.config/quickshell/bloom` symlink points to this working tree. Keep every QML save loadable; use whole-file atomic replacement when adding cross-references. Never check out an older tree. For eventual local merge, use `git fetch . feat/phase-3c-dock:main && git switch main`.
- Do not edit `~/.config`, `~/dots-hyprland` or the live ii configuration without separate owner approval. Do not start/stop/restart `bloom-shell.service`, call live `hyprctl dispatch`, mount/unmount a real drive, or empty the owner's trash as part of automated tests.
- A tray host is an exclusive handover in spec §3.4/§8 phase 6. Build the SNI adapter and dock UI in 3C behind the existing disabled `tray` module. **Do not activate it in the owner's live config in 3C.** The Phase 6 handover will switch ii's tray host and Bloom's tray path together after owner approval. See Ruling 1.
- Fixed dock surface: 640 px tall as of 3B; only its mask follows visible UI. Preview width, height and placement must fit at `bloom-scale` 0.8–1.3 and screen edges. No full-surface input region.
- Any `Spring`, animation or screencopy stream runs only while its visual is open. At rest, the dock still draws zero frames after animations and timers settle. Do not capture screens as a fallback for a missing toplevel; that could show other windows.
- Launch external apps through `Apps.run` in their own systemd scope. Build process argument arrays, never interpolate paths or labels into shell commands. Display a clear toast on a failed action.
- Run `CI=true tests/run-all.sh` before each commit (currently 322 QML tests plus integration/CLI/systemd). Tests use fake executables and isolated XDG paths; no real storage, trash, tray owner or Hyprland dispatch operations.
- Use conventional commits with `git -c user.name="Dhanush Santosh" -c user.email=dhanushsantoshs05@gmail.com commit ...` and a `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` trailer. Record any deviation as `Ruling: what — why — cost if wrong` in a 3C ledger.
- After implementation: fresh whole-branch review, RED→GREEN fixes for Critical/Important findings, owner live check, then local merge. This plan stops for owner review; none of those steps are authorized by this handoff.

## Review focus

1. **Preview identity and privacy.** A `Toplevel` is used only if its attached `HyprlandToplevel.address` exactly matches a window address already in that dock app's `windows`. Missing mapping, XWayland capture failure, stale address or `ScreencopyView.hasContent === false` yields the app's text tooltip. Never substitute monitor capture. Tests cover ambiguous app IDs and disappearing windows.
2. **Hover lifetime and performance.** Delay capture 300 ms as Bloom does; retain the card across the icon-to-card pointer bridge for 100 ms; stop streams immediately when the card, dock or setting closes. At most the visible cards run live capture. Motion tests check the first frame and settled position, not just the final state. Idle-frame test waits out timers before asserting zero.
3. **Extras are data, not commands.** Stable drive identity is filesystem UUID, falling back to an explicit device path; drive label is display text only. A stale device cannot be acted on after unplug. Never hide the root/EFI/system mount by treating it as a user drive. Tests cover duplicate labels, absent UUIDs, unplug during action, malformed settings and a user-dir resolving to `$HOME`.
4. **Destructive and privileged actions.** `udisksctl mount/unmount/power-off` may prompt through polkit; never add `--force` or `--no-user-interaction` by default. “Empty Trash” needs an in-UI confirmation and is not exercised against the real trash in tests. Open uses `gio open` with one validated URI/path argument.
5. **Tray merge safety.** SNI `id`/title/icon do not provide a process or Hyprland window address. Merge only by a unique desktop-entry ID or unique desktop-entry `startupClass` mapping (the installed Quickshell field for `StartupWMClass`), never display name alone. Ambiguous items remain separate tray-only items. `Status.Passive` is hidden; tray-only active items get one muted background dot; app windows retain their normal dots and preview behavior. Native menus use the SNI item handle and are never copied into a fake QML menu.
6. **Exclusive host boundary.** The live ii process currently owns `org.kde.StatusNotifierWatcher`; tests run SNI in an isolated user D-Bus. The 3C branch must be fully testable while `tray` remains disabled in the owner's settings. Activation belongs to the later explicit handover.

## Rulings proposed for owner review

1. **Tray handover:** spec §8 lists tray integration in phase 3 but the exclusive host switch in phase 6. Ruling: implement behind `bloom-enabled-modules` `tray` now, do not load `Quickshell.Services.SystemTray` in the always-live path, and defer live activation to phase 6. Cost if wrong: tray UI will not be visible during the 3C live check; enabling it early could contend with ii and violate the planned handover.
2. **Linux drive mapping:** use `lsblk --json` for stable structured discovery and UDisks2 (`udisksctl monitor`, `mount`, `unmount`, `power-off`) for changes. Show removable filesystems and user-mounted volumes; exclude `/`, boot/EFI, swap and other system mounts. A non-removable secondary volume not mounted by the user will not appear by default. Cost if wrong: a wanted internal volume needs a later explicit inclusion rule; this avoids presenting system partitions as casual dock actions.
3. **Hidden drives:** Bloom stores hidden drive letters. Linux stores a JSON array of stable filesystem UUIDs (`path:<device>` when no UUID), not labels. Cost if wrong: a path-only device can reappear under a new `/dev` name. UUIDs can be duplicated on cloned media; disambiguate a live duplicate by device path.
4. **Folders and trash:** keep Bloom's setting names, with default Downloads and the other XDG user dirs optional. If `xdg-user-dir DOWNLOAD` resolves to `$HOME`, use an existing `$HOME/Downloads` or omit Downloads; do not label the home directory “Downloads.” Trash uses GIO's `trash:///` URI and `trash::item-count`, which includes the GIO trash view rather than hand-counting only `$XDG_DATA_HOME/Trash`. Cost if wrong: unusual file managers may not open `trash:///`; the action returns a toast rather than opening the wrong path.
5. **Tray-only eligibility:** all non-Passive SNI ApplicationStatus/Communications items appear, even if they never had a window. Hardware/SystemServices remain separate tray items, not attached to an unrelated app by title. This differs from Bloom's observed-window gate because on Linux the dock is meant to host the system tray. Cost if wrong: more icons than Bloom's Windows taskbar for background-only apps.
6. **Preview rate:** `ScreencopyView.live` is true only while a visible preview card is on screen; offscreen cards pause. More than three windows scroll horizontally, with streams only for cards intersecting the viewport. No permanent polling. Cost if wrong: a visible multi-window app still costs GPU bandwidth while hovered; measure in the owner check.

## File map and interfaces

| File | Responsibility |
|---|---|
| `shell/services/settings.js`, `docs/SETTINGS.md`, `tests/qml/tst_settings.qml` | Preview and extras settings; tray remains an existing module flag |
| `shell/common/tokens.js`, `tests/parity/spring-parity.mjs` | Preview/extras geometry, colours and 150 ms motion tokens |
| `shell/modules/dock/previews.js`, `tests/qml/tst_dockpreviews.qml` | Exact address mapping, sort, hover delay/retention, viewport and placement rules |
| `shell/modules/dock/DockPreview.qml`, `tests/qml/tst_dockpreview.qml` | Preview card, `ScreencopyView`, fallback, focus/close controls |
| `shell/modules/dock/extras.js`, `tests/qml/tst_dockextras.qml` | `lsblk` JSON normalization, hidden IDs, XDG folder and trash rules, menu entries |
| `shell/services/DockExtras.qml`, `tests/integration/test_dock_extras.sh` | Discovery, UDisks monitor, GIO trash/folders, guarded argv actions |
| `shell/modules/dock/DockExtraIcon.qml` | Bloom-style tile and tooltip for drive, folder, trash |
| `shell/modules/dock/tray.js`, `tests/qml/tst_docktray.qml` | Unambiguous SNI matching and tray-only group rules |
| `shell/modules/dock/DockTraySource.qml` | **Lazy** SystemTray adapter, created only under `tray` module |
| `shell/services/Dock.qml`, `shell/modules/dock/dock.js` | Data merge, preview focus/close and extras/tray slot order |
| `shell/modules/dock/DockView.qml`, `DockWindow.qml`, `DockMenu.qml`, `DockIcon.qml` | Preview, extras and tray visuals and input mask |
| `shell/shell.qml`, `tests/integration/test_dock.sh`, `tests/qml/tst_dockview.qml` | Lazy tray gate, end-to-end disabled-path and dock interaction checks |

**Data contracts:**

- Preview candidate: `{ address: "0x…", title, focus, toplevel }`; `toplevel` is a Quickshell `Toplevel`, passed directly to `ScreencopyView.captureSource`. Pure rules receive plain `{ address, title, appId }` projections.
- Extra: `{ key, kind: "drive"|"folder"|"custom"|"trash", name, icon, path, device?, uuid?, removable?, mounted? }`; only `kind === "drive"` may call `udisksctl`.
- Tray projection: `{ key, sniId, title, icon, status, category, onlyMenu, item }`; `item` is the live `SystemTrayItem` for `activate()`, `secondaryActivate()` and `display(window,x,y)`. Pure rules use primitive projections and return a merge map; they never serialize a Qt object into state.
- `Dock.items` retains `{ pinned, unpinned }`; add `extrasLeft`, `extrasRight`, and tray-only app rows or a separate tray segment. Existing pinned slot numbers remain app-only (Super+Alt+1–9 do not count extras or workspace cells).

## Verified facts (owner's machine, 2026-10-27)

- `qs --version` is Quickshell **0.3.2**; Qt is 6.12. Installed `Quickshell.Wayland` imports `_Screencopy` and `_ToplevelManagement`. Local qmltypes expose `ScreencopyView.captureSource`, `live`, `hasContent`, `constraintSize`, `sourceSize`, `paintCursor`, `captureFrame()`; `ToplevelManager.toplevels.values`; `Toplevel.appId`, `title`, `activate()`, `close()`. The official [ScreencopyView API](https://quickshell.org/docs/types/Quickshell.Wayland/ScreencopyView/) says a `Toplevel` capture needs `hyprland-toplevel-export-v1`.
- Installed `Quickshell.Hyprland` qmltypes expose attached `HyprlandToplevel.address` and `.wayland`. A temporary one-pixel transparent, inputless Quickshell probe under `/tmp` observed **2** current `ToplevelManager` toplevels and **2** matching Hyprland addresses after model initialization; the first read was empty, so bindings must tolerate delayed population. The probe was removed by timeout; no owner window title or image was recorded. The current Hyprland is 0.56.2. A read-only Wayland registry probe observed `zwlr_foreign_toplevel_manager_v1` 3, `hyprland_toplevel_mapping_manager_v1` 1, `hyprland_toplevel_export_manager_v1` 2 and `zwlr_screencopy_manager_v1` 3. A second temporary `ScreencopyView` probe bound to one toplevel reached `hasContent=true` without saving or logging any image. Calling `captureFrame()` immediately in `onCaptureSourceChanged` warned that the recording context was not ready; the implementation must wait for readiness or use `live` while visible. The owner check must still verify real card appearance and cost, with text-tooltip fallback.
- Installed `DesktopEntry` qmltypes expose `startupClass`, the field used for the `StartupWMClass` mapping. Installed `Quickshell.Services.SystemTray` qmltypes expose `SystemTray.items.values`; item `id`, `title`, `status`, `category`, `icon`, `hasMenu`, `onlyMenu`, `menu`, `activate()`, `secondaryActivate()`, `scroll()`, `display(parentWindow,x,y)`. The [official item API](https://quickshell.org/docs/types/Quickshell.Services.SystemTray/SystemTrayItem/) confirms `display` opens its native menu. `busctl --user status org.kde.StatusNotifierWatcher` identifies ii's `qs -c ii` (PID 1046) as current owner; an SNI item is registered. No Bloom tray host was started.
- UDisks2 **2.11.2** is present and owns `org.freedesktop.UDisks2` on the system bus. `udisksctl` provides `status`, `monitor`, `mount`, `unmount`, `power-off`; `lsblk --json --bytes` returns device path, UUID, label, filesystem, mountpoint, removable/hotplug and type. The [udisksctl manual](https://storaged.org/udisks/docs/udisksctl.1.html) confirms mount/unmount/power-off semantics; no operation was performed. `Quickshell.Io` has `Process`, `StdioCollector` and `SplitParser.read` for event-driven scanning.
- `gio info trash:///` resolves and reports `trash::item-count: 0`; `gio trash --list` works. The [XDG Trash Specification](https://specifications.freedesktop.org/trash/latest/) allows trash on other mounted filesystems, so hand-counting only the home trash would be incomplete. `gio open`, `gio trash --empty`, `xdg-user-dir` and `jq` are installed. Here `xdg-user-dir DOWNLOAD` returns `$HOME` although `$HOME/Downloads` exists; the folder fallback in Ruling 4 is necessary.
- Bloom reference: `Dock.tsx` waits 300 ms before previews, keeps hover for 100 ms, sorts captures by last focus, displays 220×130 cards with close/focus, and uses a 150 ms entry/exit. Extras can be left/right/off and offer Open, Eject (removable drive) and Remove from Dock. `dockApps.ts` merges trays by actual owner handles on Windows; this exact signal is unavailable in SNI, hence the explicit Linux matching rule. `.background-indicator` is a muted grey dot.

## Task 1 — Settings and visual tokens

**Files:** settings schema/docs, tokens, settings QML test, spring parity.

- [ ] RED: tests for `bloom-dock-preview-enabled` (bool, default true); `bloom-dock-extras-position` (`off|left|right`, off); `-drives` (bool true); `-recycle-bin` (bool true); `-hidden-drives` (string, default `"[]"`); `-folders` (string, default `"downloads"`); `-custom-folders` (JSON string, default `"[]"`). Reject oversize strings and invalid enum; retain older Bloom string booleans.
- [ ] GREEN: add schema entries and generated `docs/SETTINGS.md`. Define preview card (max 220×130 image, gap 12, max 3 visible), extras tile 36, hover bridge and 150 ms transitions in `tokens.js`. Avoid increasing the fixed surface unless geometry tests prove necessary.
- [ ] Run focused settings/parity/docs tests and `CI=true tests/run-all.sh`; commit `feat: add dock preview and extras settings`.

## Task 2 — Preview identity and lifetime rules

**Files:** `previews.js`, `tst_dockpreviews.qml`.

- [ ] RED: map two same-title windows with distinct addresses; reject a missing/invalid address, stale toplevel, and an app-ID-only match; sort by Hyprland focus rank; retain hover for 100 ms while pointer crosses a 20 px gap; stop on menu, drag, hidden dock or setting off. Test 1/3/6 windows, screen-edge placement and scale 0.8/1.3 without clipping.
- [ ] GREEN: `candidates(item, toplevels)`, `previewPlacement(anchor, card, screen, scale)`, `previewVisible(state)` and `liveCards(viewport, cards)` as pure functions. Normalize addresses once (`0x` + lower-case hex); never map by title. Text tooltip is the fallback for candidates with no capture source/content.
- [ ] Focused tests, whole suite, commit `feat: add exact dock preview mapping rules`.

## Task 3 — Preview card and capture seam

**Files:** `DockPreview.qml`, `tst_dockpreview.qml`.

- [ ] RED: component-load test; multi-window labels and close buttons; focus and close signals carry one exact address; close tap cannot also focus; a missing `captureSource`/`hasContent=false` shows a neutral placeholder/text tooltip, not a monitor image; card has a hover bridge and clips at both screen edges.
- [ ] GREEN: each visible card owns a `ScreencopyView { captureSource: candidate.toplevel; live: root.open && card.visible && card.inViewport; paintCursor: false; constraintSize: Qt.size(220,130) }`. Card is created after the 300 ms dwell and destroyed/disabled when dismissed. A short exit opacity/scale animation stops at rest. Add an injectable capture delegate or `captureEnabled` seam so offscreen QML tests do not request real screencopy.
- [ ] Verify imports with installed `qmllint`; run QML component tests. Repeat the disposable Hyprland capture probe to verify `hasContent` and lack of warnings; **do not print or save image data**. Do not call `captureFrame()` synchronously on `captureSourceChanged` (the planning probe showed the recording context is not ready yet). If capture fails, record a Ruling and keep the tooltip fallback. Full suite; commit `feat: add live dock window previews`.

## Task 4 — Wire previews into the dock

**Files:** `DockView.qml`, `DockWindow.qml`, `DockIcon.qml`, `Dock.qml`, `tst_dockview.qml`, `test_dock.sh`.

- [ ] RED: hover a running app with one/multiple windows; opening menu or drag cancels preview; click focus and close act only on that address; exiting icon to card preserves hover; no preview for a tray-only app, non-running pin or `bloom-dock-preview-enabled=false`; old icon tooltip remains when no image loads. Test same-frame and settled card position at both dock scales.
- [ ] GREEN: map `ToplevelManager.toplevels.values` by attached Hyprland address at the per-window boundary, pass Qt objects only to the visual layer, and use existing validated Dock dispatch queue for focus/close. Extend the mask with the **visible preview box only**, not the full stage. Keep menu, popup and preview mutually exclusive; preview holds the smart/peek dock open while hovered. Handle a closed toplevel by removing just its card and stale address.
- [ ] Offscreen QML/headless sway tests must pass without screencopy or Hyprland. Run idle-frame checks after timers settle; whole suite; commit `feat: wire dock previews to windows and input mask`.

## Task 5 — Extras rules and discovery

**Files:** `extras.js`, `DockExtras.qml`, `tst_dockextras.qml`, `tests/integration/test_dock_extras.sh`.

- [ ] RED pure tests: `lsblk --json` normalization, duplicate labels, UUID/path hidden list, removable vs internal selection, `/`/EFI/swap exclusion, bad JSON, no device, unplugged action target; XDG folder IDs and custom JSON (duplicates, non-existent path, out-of-home path allowed only if explicitly selected); `xdg-user-dir DOWNLOAD=$HOME` fallback; GIO trash count parse. Test left/right/off order.
- [ ] GREEN: `DockExtras` runs `lsblk --json --bytes -o PATH,UUID,LABEL,FSTYPE,MOUNTPOINT,RM,HOTPLUG,TYPE`; `udisksctl monitor` through `SplitParser` debounces refresh, with a slow retry if monitor fails. Query configured folders via `xdg-user-dir` and trash via `gio info -a trash::item-count trash:///`; poll trash only while extras are enabled. Decode JSON defensively and preserve the last good state on a transient command failure. Avoid repeated scans while off.
- [ ] Actions validate the selected key against the **current** device list before `Process.command` is set: mounted path → `gio open`; unmounted permitted filesystem → `udisksctl mount -b <device>` then refresh/open returned mount path; removable/hotplug → `udisksctl unmount -b` then attempt `udisksctl power-off -b`, with a clear toast if the drive does not support power-off. No `--force`. Folders use `gio open <path>`; trash uses `gio open trash:///`. “Empty Trash” has a confirmation gate and `gio trash --empty` is never used in automated tests.
- [ ] Integration fakes `lsblk`, `udisksctl`, `gio`, `xdg-user-dir` on `PATH` in isolated XDG state. Assert exact argv and zero real mount/trash calls. Whole suite; commit `feat: add dock extras discovery and guarded actions`.

## Task 6 — Extras visuals and layout

**Files:** `DockExtraIcon.qml`, `DockView.qml`, `DockWindow.qml`, `DockMenu.qml`, `dock.js`, `tst_dockview.qml`, `test_dock_extras.sh`.

- [ ] RED: extra tiles appear before the app row for `left`, after it for `right`, with one divider only when apps exist; `off` leaves existing slot keys/width unchanged. Pinned app shortcut indices do not move. Open/Eject/Hide/Remove menu entries match kind; the trash icon/count and drive mounted status update without a duplicate slot; icon-only and light mode still work; left/right preview/card geometry stays inside the 640 px surface.
- [ ] GREEN: use Bloom tile/tooltip motion via existing `DockIcon` visual primitives, stable extra keys (`extra:<kind>:<id>`), `DockExtraIcon` for click/menu, and pure `dock.js` slot/layout changes. `DockMenu` delegates extra action keys to `DockExtras`. Add `DockConfirm` so Cancel and outside click never run Empty Trash, and only an explicit Confirm runs it; test all three with a fake `gio`. Use a reversible setting mutation for Hide/Remove, never delete the folder or drive. Maintain a narrow mask around each extra tile.
- [ ] QML, integration, idle-frame and whole-suite checks; commit `feat: show drives trash and folders in the dock`.

## Task 7 — SNI selection and merge rules

**Files:** `tray.js`, `tst_docktray.qml`, `dock.js`.

- [ ] RED: one exact desktop ID match merges into the running app and preserves window dots/previews; an SNI-only app gets one grey background dot and `activate()` action; Passive is hidden; two same-title apps never merge by name; ambiguous desktop match stays separate; 2 tray handles on one app yield two labelled menu actions; disappearance clears tray-only slot and observed state; pinned slot order/shortcut numbers remain intact.
- [ ] GREEN: pure `selectTray(items, desktopEntries, running, pinned)` returns exact matches and separate rows. Prefer normalized SNI ID ↔ desktop-entry ID; use `DesktopEntry.startupClass` only if uniquely mapped. No PID/name guess. Keep Qt `SystemTrayItem` references outside the pure test data model.
- [ ] Focused tests, whole suite; commit `feat: add safe SNI dock merge rules`.

## Task 8 — Lazy tray adapter and UI

**Files:** `DockTraySource.qml`, `shell.qml`, `Dock.qml`, `DockView.qml`, `DockWindow.qml`, `DockMenu.qml`, `test_dock.sh`, isolated D-Bus test.

- [ ] RED: with `tray` absent from `bloom-enabled-modules`, the adapter is not created, SystemTray is not referenced from any always-live singleton, and the existing dock state/integration remains unchanged. In isolated D-Bus, fake SNI items drive add/remove/status/menu behavior. A tray-only item's left click activates the item or opens its menu when `onlyMenu`; middle click calls `secondaryActivate`; context action invokes `item.display(parentWindow,x,y)` after closing Bloom's menu. No second click closes the native menu immediately.
- [ ] GREEN: `LazyLoader` creates `DockTraySource` only for the `tray` module; it projects `SystemTray.items.values` into Dock's merge layer. `DockTraySource` removes its projection on destruction. Native menu calls use the current live item handle and dock `PanelWindow`, not serialized IDs. Make `Status.Passive` disappear without animation churn. Tray-only icons use the SNI image source; merged apps keep custom icon priority. A missing SNI watcher shows no placeholder and no warning storm.
- [ ] Run the isolated D-Bus test with `tests/integration/dbus-session.conf`, full `CI=true tests/run-all.sh`, and a fresh whole-branch review. Commit `feat: connect lazy SNI tray to the dock`. **Leave `tray` disabled in the owner's live settings.**

## Owner review and later acceptance

This handoff authorizes the plan only. After owner approval and implementation/review, live check previews and extras with a disposable app window and test removable drive or a fake mount; verify no unwanted capture or live file mutation. The tray live check and ii watcher switch belong to the later Phase 6 handover, with explicit owner approval, backup, rollback and verification of watcher ownership. No merge/push or real-session action is part of this planning task.
