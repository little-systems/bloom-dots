# Bloom for Hyprland: shell design

- Status: draft for owner review
- Date: 2026-10-25
- Owner: Dhanush
- Reference implementation: [Bloom](https://github.com/SehajveerSingh2005/bloom) (Windows, Tauri v2 + React 19), studied at fork `DhanushSantosh/bloom` @ `b5fb962`. Bloom's maintainer approved the port, the Bloom name and GPL-3.0 reuse with credit.

## 1. Goal

Bring Bloom's notch, dock and overlays to Arch Linux + Hyprland as a complete desktop shell that is installable as dotfiles. It is built for the owner first, and must also be installable by other people (the way end-4's illogical-impulse or Caelestia are).

The end state **replaces end-4 illogical-impulse (ii) entirely**. During development Bloom runs alongside ii and takes over one piece at a time.

### Success criteria

1. Every ported Bloom surface matches Bloom's look and motion: the sizes, colours, type and springs in Appendix A, checked side by side against Bloom's framer-motion reference.
2. The owner can drop ii with no loss of daily function: notifications, launcher, lock, polkit, session menu, screenshots, theming, personal binds.
3. The shell runs crash-free under its soak test, and idles under 1% CPU on an Intel UHD 620.
4. A stranger can install it, update it and uninstall it cleanly with one command each.

### Non-goals

- Distros other than Arch.
- Compositors other than Hyprland ≥ 0.56 with the Lua config.
- Alternative visual "families" like ii's waffle. There is one look: Bloom's.
- Translations. Strings are kept in one place so i18n can come later.
- From ii, dropped by owner decision: hot corners, desktop widgets, on-screen keyboard, game overlay, AI sidebar, booru, music recognition.

## 2. Decisions

| # | Decision | Choice |
|---|---|---|
| D1 | Audience | Owner first, publishable for others |
| D2 | Repo | Separate repo `DhanushSantosh/bloom-dots` (GPL-3.0), not inside the Tauri codebase |
| D3 | End state | Replace ii entirely; run alongside it during development |
| D4 | Build approach | Custom Bloom-style UI for every surface; off-the-shelf only for background services |
| D5 | Toolkit | **Quickshell (QML / Qt Quick)**. Validated by the spike (§10) |
| D6 | Layout | **Notch-only.** No top bar. Clock lives in the collapsed notch; tray in the dock |
| D7 | Workspaces | Switcher segment at the start of the dock (replacing Bloom's start button); overview on a keybind. (The notch peek on workspace change, built in 2C, was removed by the owner on 2026-10-27: workspaces live in the dock only.) |
| D8 | Monitors | A notch and dock on every connected monitor (Quickshell `Variants`). No setting. The owner runs a single eDP-1 1920×1080 |
| D9 | Kept from ii | Workspace overview, region tools (screenshot/OCR/recording), wallpaper picker + auto theming, keybind cheatsheet, todo (as a notch tab) |
| D10 | Visual language | Bloom only. Theme modes Light / Dark / Custom / Adaptive with opacity, saturation and brightness. On Linux, Adaptive takes its colours from the wallpaper (matugen), and **only Adaptive** also themes other apps |
| D11 | Install model | Hybrid: repo clone with the shell symlinked; user configs copied once (§7) |
| D12 | Keys | Super+1–9 = workspaces (unchanged). Dock app N = **Super+Alt+1–9** |
| D13 | Launcher | Centred floating panel (may be revisited later) |
| D14 | Notifications | Bloom-style cards stacked in the **top-right corner**. The notch is not used for popups. History is a notch panel |

## 3. Architecture

### 3.1 Processes

- **Shell:** one Quickshell instance, `qs -c bloom`, run by the systemd user unit `bloom-shell.service`: `PartOf=graphical-session.target`, `Restart=on-failure`, `RestartSec=1`, `StartLimitBurst=5` within 60 s. This replaces ad-hoc restart loops such as the owner's current 5-second `qs -c ii` loop.
- **Settings app:** a separate Quickshell process (`qs -p …/settings/settings.qml`), so a settings crash can't take down the shell.
- **Background tools:** hypridle, hyprsunset, cliphist, matugen, cava, grim/slurp, wf-recorder and tesseract run as their own processes. The shell starts long-running helpers only while something needs them; for example, cava runs only while media is playing.

### 3.2 Inside the shell

- `shell.qml`: `ShellRoot` → `Variants { model: Quickshell.screens }` for per-screen surfaces (notch, dock, notification cards, OSD). All other panels are `LazyLoader`s, created on first open.
- `services/`: singletons that wrap system APIs, one per concern: Audio, Media, Battery, Network, Bluetooth, Devices, Hypr, Notifications, Tray, Polkit, Weather, SystemStats, Updates, Todo, Pomodoro, Theme, Settings, State. **Modules never call system APIs or spawn processes directly**; they bind to services.
- `modules/`: one folder per surface (notch, dock, osd, notifications, launcher, overview, session, lock, polkit, regiontools, wallpaper, cheatsheet).
- `common/`:
  - `Spring.qml`: the spring engine (§10.1);
  - `EdgeSurface.qml`: the pill plus concave flares, shared by the notch, dock and OSD;
  - `Tokens.qml`: the Appendix A values;
  - shared widgets;
  - Bloom's SF Symbol icons.
- Pure logic (size rules, parsers, validation, grouping, maths) goes in plain `.js` files imported by the QML, so it can be unit-tested (§9).

### 3.3 Rules for every surface

1. **Layer surfaces never resize while animating.** Each surface is created at its maximum size, and only its input mask (`mask: Region { item: … }`) follows the visible shape. The spike's crash-free soak (§10) relied on this.
2. Each surface has a Hyprland layer namespace `bloom:<panel>` (e.g. `bloom:notch`, `bloom:dock`), so layer rules can target it.
3. Each panel exposes an `IpcHandler`, reachable through `bloom ipc <panel> <action>`. Hyprland binds call it with a fallback for when the shell is down, e.g. `bloom ipc launcher toggle || fuzzel`.

### 3.4 Running alongside ii

A setting, `bloom-enabled-modules`, lists which Bloom surfaces run. ii keeps everything else. Some pieces are **exclusive** (only one can run at a time): the notification server, the tray host and the polkit agent. Each of these moves from ii to Bloom in a single switch, never both at once (notifications in phase 4, polkit and tray in phase 6; §8).

### 3.5 Repo layout

```
shell/        shell.qml, modules/, services/, common/, settings/ (settings app)
hypr/         bloom.lua (defaults), binds.lua, rules.lua, custom/ (templates copied once)
theming/      matugen templates: shell, GTK3/4, Qt, kitty, fuzzel, Hyprland borders
bin/bloom     CLI: install, update, uninstall, migrate-from-ii, ipc, doctor, dev soak
systemd/      bloom-shell.service
packaging/    PKGBUILD for bloom-shell-deps (meta-package)
tests/        qml unit tests, spring parity, installer round-trip, headless load
docs/         specs/, plans/, SETTINGS.md
```

## 4. Components

All surfaces are built on `Spring` and `EdgeSurface` with Appendix A values.

### 4.1 Ported from Bloom (same behaviour, Linux back ends)

**Notch**
- Modes:
  - Status: clock, plus hover status widgets (default: weather left, battery right; optional cpu, ram, disk, net).
  - Music: collapsed visualizer + album art; classic and compact panels.
  - Command Center: Wi-Fi, BT, DND, volume, brightness.
  - Calendar + Pomodoro + **Todo** (new tab).
  - Shelf: drop files or text in, drag them out.
  - Wi-Fi, Bluetooth and Connected Devices panels.
  - Notification history (new, D14).
- Pulses: charging, low battery, update available.
- Device alerts: USB, headphone jack, earbuds with per-bud battery where the device reports it.
- Display modes: fixed, smart (hides when a window overlaps) and peek; edge-dwell reveal.
- Startup drop-in and "impact" animation.
- New on Linux:
  - privacy dots while the mic or screen-share is in use.

**Dock**
- Pinned and running apps; multiple windows per app; live thumbnails via `ScreencopyView`.
- Context menus, drag to reorder, custom icons.
- Extras (drives, trash) and tray apps (SNI).
- Modes fixed/smart/peek; adaptive width; overlap detection.
- The workspace switcher segment (D7) replaces the start button.
- Super+Alt+1–9 launches or focuses dock app N (D12).

**OSD**
- Volume as a pill flush to the left screen edge, brightness on the right edge, as in Bloom. Per-app volume mixer.
- New: ii-style volume protection, which caps how far the volume can jump in one step and sets a maximum.

**Settings app:** Bloom's tabbed window with live previews (FeaturePreview), import/export/reset, and a "needs X" hint for features whose tools are missing.

### 4.2 New in Bloom style

- **Notifications:**
  - our own server (Quickshell `NotificationServer`);
  - corner cards top-right (D14) with app grouping, actions, images and timeouts;
  - DND; history stored in `~/.local/state/bloom`; an unread count.
- **Launcher (D13):** a centred floating panel. App search, plus prefixes: clipboard (cliphist), emoji, calculator (qalc), shell command, web search, and user actions (scripts in `~/.config/bloom/actions`).
- **Workspace overview:** a grid of workspaces with live previews; drag windows between workspaces; search.
- **Session menu:** lock, log out, suspend, hibernate, reboot, shut down, firmware setup. Warns when pacman or a download is running.
- **Lock screen:**
  - `WlSessionLock` + PAM password; optional fingerprint; unlocks the keyring;
  - hypridle triggers it;
  - hyprlock is the fallback.
- **Polkit agent:** Bloom-styled authentication dialog.
- **Region tools:** region/window selector for screenshots (grim/slurp, annotation via satty), OCR (tesseract) and recording (wf-recorder, optional audio).
- **Wallpaper picker:** a grid; sets the wallpaper (static, or video via mpvpaper) and drives the Adaptive theme.
- **Keybind cheatsheet:** generated from the `description` fields of the binds.
- **Idle and night light:** hypridle and hyprsunset, with toggles in Command Center.
- **Update indicator:** pacman updates via `checkupdates`, plus `bloom update` for the shell itself.

## 5. Data flow

### 5.1 Sources

Services use events where the system offers them. **Nothing polls unless a visible surface needs the data.**

| Service | Source |
|---|---|
| Hypr | Hyprland event socket (Quickshell `Hyprland`) |
| Media, Audio | MPRIS, PipeWire; cava (pipewire input, raw output) while playing |
| Battery | UPower |
| Network, Bluetooth | NetworkManager, BlueZ (Quickshell built-ins; `nmcli`/`bluetoothctl` only where needed) |
| Devices | udev monitor and PipeWire device events |
| Notifications, Tray, Polkit | Quickshell servers |
| SystemStats | `/proc` every 2 s, only while a stats widget is visible |
| Weather | Open-Meteo every 30 min; IP geolocation or a configured city |
| Updates | `checkupdates` every hour |

### 5.2 Settings

- **File:** `~/.config/bloom/settings.json`, a flat object. Key names follow Bloom's (`bloom-notch-mode`, …), and values use native JSON types.
- **Schema:** one schema file (`shell/services/settings-schema.js`) lists every key's type, default and allowed values. The shell and the settings app both read it, and `docs/SETTINGS.md` is generated from it.
- **Writes are atomic** (temp file + rename). The shell watches the file (`FileView`), so a change from the settings app or a hand edit applies live.
- **Bad values:** an invalid or missing value falls back to its default and logs a warning. It never prevents the shell from starting.
- **UI state lives apart from settings**, in `~/.local/state/bloom/`: todos, pomodoro, notification history, dock order, the last panel. Resetting settings never touches it.

### 5.3 Theming

- **Light / Dark / Custom:** the Theme service turns the mode and the sliders into tokens (Appendix A).
- **Adaptive:** on a wallpaper change, matugen generates a palette and writes the shell's colours plus the app templates (GTK3/4, Qt, kitty, fuzzel, Hyprland borders). The Theme service reloads.
- **Leaving Adaptive** restores the previous app themes, which were backed up when Adaptive was first enabled.

### 5.4 Control

- **Hyprland binds** → `bloom ipc …`, each with a fallback.
- **The `bloom ipc` interface is documented**, so user scripts can drive the notch.
- **Shell → Hyprland:** the shell sends commands over Hyprland's socket, for example to switch workspaces or focus a window from the dock.

## 6. Error handling

- **Shell crash:**
  - systemd restarts it.
  - After the start limit it gives up and reports through `hyprctl notify`, which works without the shell.
  - Bind fallbacks keep the desktop usable.
- **Diagnostics:** `bloom doctor` gathers logs, versions, enabled modules and settings that differ from defaults.
- **Panel isolation:** each panel loads in its own `Loader`/`LazyLoader`. A load error disables that panel and logs a warning; everything else keeps running.
- **Lock safety:**
  - `bloom.lua` sets `misc:allow_session_lock_restore = true`, so if the lock surface crashes the session **stays locked** and the restarted shell locks again.
  - The TTY recovery steps are documented in `bloom doctor` output and the README.
- **Missing tools:** the feature hides and Settings shows "needs X" with the install command. External commands run with timeouts.
- **Network:** weather and other network widgets hide while offline.
- **Corrupt files:**
  - a corrupt state file is moved to `<name>.bak` and recreated, with a warning;
  - a bad `settings.json` falls back to defaults (§5.2).
- **Conflicts:**
  - At start, Bloom checks who owns the exclusive services (notifications, tray, polkit). Possible owners: mako, dunst, swaync or ii.
  - Bloom asks before stopping anything; it never kills processes silently.
  - Exclusive pieces left on ii through `bloom-enabled-modules` are simply not started.
- **Performance:** a low-power mode turns off the album-art glow and blur, throttles live thumbnails and drops extra animation layers (springs stay). It's suggested on battery and can be forced on.

## 7. Install, update, migration

### 7.1 Install

```
git clone https://github.com/DhanushSantosh/bloom-dots ~/.local/share/bloom
~/.local/share/bloom/bin/bloom install [--dry-run]
```

1. **Preflight:** Arch; Hyprland ≥ 0.56 with a Lua config; Quickshell ≥ 0.3. On failure it stops before changing anything.
2. **Dependencies:** `bloom-shell-deps` is built from `packaging/` with `makepkg -si`; the user enters their sudo password.
   - It depends on `quickshell` (satisfied by any provider, including `illogical-impulse-quickshell-git`), plus matugen, cava, cliphist, grim, slurp, wf-recorder, tesseract, hypridle, hyprsunset, brightnessctl, playerctl, libqalculate, inter-font and the portals.
3. **Shell:** symlink `~/.config/quickshell/bloom` → `~/.local/share/bloom/shell`.
4. **Hyprland:** add one marked line to the user's `hyprland.lua` that loads `~/.local/share/bloom/hypr/bloom.lua`. Copy the `custom/*.lua` templates once; after that they belong to the user.
5. **Services:** enable `bloom-shell.service`.
6. **Records:** every created or replaced file goes into `~/.local/state/bloom/install-manifest.json`. Replaced files are first backed up to `~/.local/state/bloom/backups/<timestamp>/`.
7. **Re-running** is safe.

### 7.2 Update: `bloom update`

- `git pull --ff-only`. It refuses if files inside the clone were edited, and points the user to `custom/`.
- Re-runs the dependency step if the PKGBUILD changed.
- If a default the user has customised changed upstream, the new version is written beside it as `<file>.new` and listed. It is never overwritten.
- Restarts the shell.
- `bloom update --rollback` returns to the previous commit, which is recorded before each update.

### 7.3 Uninstall: `bloom uninstall`

Removes everything in the manifest and restores the backups. Removes the Hyprland line and disables the unit. Then offers to remove `bloom-shell-deps`.

### 7.4 Migration from ii: `bloom migrate-from-ii [--undo]`

This runs once, at the final switch. During development, coexistence goes through `bloom-enabled-modules` instead.

1. Back up `~/.config/hypr`, `~/.config/quickshell/ii` and `~/.config/illogical-impulse`.
2. Disable ii's autostart, including restart loops in `custom/*.lua` (e.g. the owner's 5-second `qs -c ii` loop).
3. Keep the user's `custom/*.lua` unchanged; Bloom uses the same override layer. Personal binds and execs (wield-app, chatgpt.service, easyeffects, mpvpaper) carry over.
4. Import ii's dock pins and transparency settings into `settings.json`.
5. Hand the exclusive services over to Bloom.
6. `--undo` restores everything from the backup.

Nothing under `~/.config` or `~/dots-hyprland` changes until the user runs one of these commands.

## 8. Delivery phases

The project is too large for one implementation plan. Each phase gets its own plan, built on this spec, and ends usable alongside ii.

1. **Foundation:**
   - repo skeleton;
   - `common/` (Spring, EdgeSurface, Tokens);
   - Settings and State services with schema;
   - Theme service (Dark/Light/Custom);
   - systemd unit;
   - `bin/bloom` with `ipc`, `doctor` and dev install (symlink only);
   - test harness (§9).
2. **Notch core:** Status, Music, startup animation, pulses, workspace peek, display modes.
3. **Dock:** pinned and running apps, thumbnails, menus, reorder, workspace segment, tray, Super+Alt+N.
4. **OSD + notifications:** volume/brightness OSD with protection; notification server, corner cards and history panel. The first exclusive handover from ii.
5. **Notch panels:** Command Center, Calendar/Pomodoro/Todo, Shelf, Wi-Fi/BT/Devices, device alerts, privacy dots.
6. **System surfaces:** launcher, overview, session menu, lock screen, polkit agent. Handover of polkit and the tray.
7. **Theming + extras:** Adaptive (matugen pipeline), wallpaper picker, region tools, cheatsheet, low-power mode, settings app.
8. **Ship:** full installer, update, uninstall, `migrate-from-ii`, `bloom-shell-deps`, docs; the final switch on the owner's machine.

## 9. Testing

**CI** (GitHub Actions, Arch container, every push):
- `qmllint` on all QML; `shellcheck` on `bin/` and scripts.
- Qt Quick Test unit tests for the pure-logic modules: spring engine, notch/dock size rules, settings schema and fallbacks, launcher prefix parsing, notification grouping, volume protection.
- **Spring parity:** a Node script runs framer-motion's `spring` generator (motion-dom 12.43) for every spring in Appendix A and fails if our engine differs by more than 0.01 px over 0→100 px, sampled each millisecond until framer reports the spring at rest (framer snaps to the target at that point, so the comparison stops there).
- **Headless load:** start the shell in a headless wlroots compositor (sway with `WLR_BACKENDS=headless`, to be confirmed in phase 1). Any QML warning or error fails the build.
- **Installer round-trip** in a throwaway HOME:
  - `install --dry-run`, then `install`, then `uninstall`, then a diff of HOME (any leftovers fail);
  - `migrate-from-ii` then `--undo` against a fixture ii setup.

**Release gates** (owner's machine):
- **Soak:** `bloom dev soak <surface>` cycles each surface's states every 250 ms for 10 minutes. Pass = 0 restarts, 0 warnings, memory flat after the first minute.
- **Performance budget:** idle CPU < 1%; no polling while hidden; memory reported per release.
- **UX parity:** for each ported component, a checklist from Appendix A, compared side by side against the framer-motion reference page, with grim screenshots attached to the release.

**Not done:** pixel-diff screenshot tests in CI. Blur, fonts and GPU differences make them flaky.

## 10. Spike results (2026-10-25)

A throwaway "hello notch" was built in the session scratchpad and not kept. It contained:
- a top-centre pill matched to Bloom: flush top with flares, startup drop-in;
- collapsed clock/music;
- status hover;
- the classic music panel with MPRIS, PipeWire volume and cava.

### 10.1 Motion

- **Integrator:** a semi-implicit Euler integrator (1 ms substeps) drifted about 1 px from framer-motion.
- **Closed form:** replaced with the exact closed-form damped-spring solution, stepped from the current position and velocity each frame. It matches framer-motion 12.43's generator to 3 decimals at every sample, with identical settle times (e.g. width spring 362 ms, height 326 ms).
- **Interruptions:** retargeting mid-flight keeps position and velocity, as framer-motion does.
- **Rest thresholds:** follow framer-motion's defaults: 0.5 / 2, or 0.005 / 0.01 for moves under 5 units.
- **Feel:** the owner confirmed it matches Bloom.

### 10.2 Stability and cost

- **Soak:** 10 minutes cycling collapsed → hover → open every 250 ms, about 2,400 morphs. Results: 0 restarts, 0 warnings, memory flat at about 256 MB after the first minute.
- **Interpretation:** ii's "fatal Wayland surface errors" appear to come from ii itself, not from Quickshell. The fixed-size surface rule (§3.3) is adopted.
- **CPU:** about 0.1% at idle. About 21% of one core during non-stop animation, which is the worst case; a real notch animates for a few hundred ms at a time. This motivates the low-power mode.

### Hybrid spike (2026-10-26)

The owner asked whether Bloom's real React UI could run on Linux so upstream releases flow into the dotfiles. A throwaway spike loaded Bloom's built notch bundle with a fake Tauri runtime:

- **Inside Quickshell:** impossible. Chromium (QtWebEngine) aborts at start because Quickshell creates its app without a program name.
- **WebKitGTK on a gtk-layer-shell surface** (Tauri's Linux stack): the page runs but gets no animation frames (2 in 14 s), so the notch never drops in. The usual `WEBKIT_DISABLE_*` switches don't help.
- **In ordinary windows** with music playing, the notch costs about 48–50 % of a core (WebKitGTK and Chrome) against about 18 % native. Memory is 290–590 MB against 116 MB for the whole native shell.
- **Backend surface:** the frontend calls 102 Windows backend commands, all of which would need Linux versions.

**Decision (owner, 2026-10-26):** stay native (D5 stands). Upstream Bloom changes are ported deliberately: diff each upstream release against the last ported commit and turn its UI changes into small port tasks.

## Appendix A: Bloom notch design tokens

Source: Bloom `App.tsx`, `App.css`, `theme.ts`, `components/EdgeSurface.*` @ `b5fb962`.

### Motion (framer-motion springs: stiffness / damping / mass)

- Pill: width 400/31, height 450/29, y 550/45/0.8 (restDelta 0.001), corner radii 1000/40, default 500/30.
- Clock/timer flip: rotateX ±90°, 600/30. Visualizer bars: scaleY 600/30/0.5.
- Buttons: hover ×1.2, press ×0.9, spring 400/25. Large album art: ×1.05 / ×0.95.
- Prev/next: slide-push. Two icons in a 32×16 clip, ±30 px, 180 ms, cubic-bezier(0.4, 0, 0.2, 1); the skip fires on finish.
- Content swaps: wait-mode opacity fade, 0.1 s. Status widgets: 0.2 s fade. Background colour: 0.3 s ease.
- Pulses: opacity + scale 0.95 → 1 → 1.05, with blur 4 px in and out.
- Startup: a 30.6×44.2 pill with 18 px radii at y = 250, opacity 0 → 1 over 0.2 s, springs to y = 0. After 240 ms: top radii → 0, flares fade in over 0.3 s, the pill expands to 140×36.

### Geometry (px)

| State | Size |
|---|---|
| Collapsed | 140×36 (24-hour clock trims 16 px) |
| Music, collapsed | +30 for the visualizer (while playing), +30 for the album art |
| Status hover | max(min(200 + 50 × widgets, 380) − trim, fit) |
| Music panel | classic 340×120; compact 300×116 or 132, +36 with volume |
| Calendar | 480×273 or 305 |
| Shelf | 380×130 / 176 / 190 |
| Command Center | 350×230 |
| Wi-Fi / Bluetooth | 350×300 |
| Device alert | 330×76 |
| Announcement | 380×148 or 168 |
| Pulses | 200 wide |

- Flush to an edge: top radii 0; bottom radii 18 (28 in calendar).
- Flares: a 13 px concave cubic with handles at 10 px (fuller than a circle's 7.2 px). The pill and flares are painted opaque, then faded as one layer, so no seams show.
- Spacing: pill padding 0 12; main row 36 tall; side-content gap 8; widget group gap 10; icon-label gap 5.

### Colour (Dark default)

- Background black at 0.8; hover/expanded 0.92 (opacity setting + 0.12).
- Text #fff; muted text 0.6; border 0.1; group background 0.04; accent #007aff.
- Light: white background at the opacity setting; expanded #f5f5f7; text #1c1c1e; muted 0.65.
- Custom/Adaptive: a background tinted from the accent. Defaults: saturation 0.5, brightness 0.15.
- Status: green #32D74B (charging, update), red #FF453A (low battery, finished timer).

### Type

- Inter 400/500/600 (installed as `inter-font`).
- Clock 13/500, tracking 0.3. Widget labels 11/500 at 0.85.
- Track title 14.5/600, tracking −0.15, 8 s marquee with an 8 px fade mask. Artist 12/400 muted.
- Tooltip 11/500, padding 8×11, radius 11.

### Components

- **Collapsed music:**
  - left: 5-bar visualizer (3 px bars, 2.5 px gap, 20 tall; 0.95 opacity playing, 0.5 paused; minimum scale 0.2, or 0.1 paused);
  - right: album art 24 px (20 when paused), radius 6;
  - glow behind the art: blur 6, saturate 2.5, brightness 0.8, opacity 0.6; larger on hover.
- **Classic music panel:**
  - art 96 px, radius 12, with a 0.5 px border at white 0.1 and a shadow; gap 22;
  - title and artist;
  - 5×18 visualizer at the top-right, which swaps to an audio-output button on hover;
  - controls with gap 24: prev/next 32×16 SF icons, play/pause in a 44 px box with a 26 px icon;
  - volume row 12 tall: icons 12/14 at 0.5; track 5 px, radius 2.5, white 0.15 (0.2 on hover), white fill.
- **Battery icon:** 20×10 shell, radius 2.4, stroke at 0.35, a tip. Fill width 10.4 × level: green while charging, red at or below the threshold, white otherwise. Bolt overlay while charging.
- **Icons:** Bloom's SF Symbols SVGs (play, pause, backward, forward, music.note, speaker.*, headphones, slider).
