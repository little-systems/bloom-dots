# Window motion and behavior: design

Date: 2026-11-13. Status: draft for owner approval.

## Intent

Bloom owns how windows move and behave, the way it already owns the notch and
the dock. Today `hypr/desktop.lua` only turns animations on, so every curve is
Hyprland's stock default: windows pop in from 87%, close with a linear fade,
workspaces switch on a slow curve, fades run long. The owner wants it
**smoother and snappier, never slow**. The defaults "work"; the problem is
feel, not the model.

## Goals

- Windows (open, close, move, resize, swap), workspace switches, fades and
  layer surfaces move on **springs** built from Bloom's own motion values
  (`shell/common/tokens.js`), so the desktop and the shell feel like one
  system.
- Snappy: motion starts at once, lands quickly and settles **without bounce**,
  matching the shell's default `macos` animation style.
- Polished tiling (owner's choice: tiling-first, option 1):
  - a lone tiled window fills its workspace (no gaps, no border, no rounding),
  - a new window splits toward the side you're working on,
  - Super+drag moves, swaps and resizes tiled windows with the same springs,
  - dialogs and small tools keep opening floating and centred (rules exist
    in `desktop.lua`; check they cover the common cases).
- Bloom's **Reduce Motion** setting (`bloom-reduce-motion`) also turns
  Hyprland's animations off, so one switch covers the whole desktop.

## Non-goals

- No floating-first mode, edge snapping or snap previews (option 2/3, later).
- No new Settings UI or second motion knob (approach 2, later if wanted).
- No shell-driven window animation (approach 3, ruled out: Hyprland draws
  windows).

## Anti-goals

- Anything that feels slower, floatier or bouncier than today.
- Animations that stall input: a window must take focus and keys at once,
  whatever its animation is doing.
- Overriding the user: personal Hyprland config (`custom/bloom.lua`, their
  `hyprland.lua`) still wins, and the existing Animations toggle on the
  Windows settings page keeps working.

## Approaches considered

1. **Fixed Bloom defaults in `desktop.lua`, tied to Reduce Motion.** Chosen
   by the owner: snappy defaults, not options.
2. Same plus a Snappy / Smooth / Off "Window motion" choice in Settings:
   more flexible, but new UI and testing for a knob nobody asked for. Can be
   added on top of 1 later.
3. Bloom's shell animates windows itself: ruled out, Hyprland owns window
   drawing, so it would be slower, not snappier.

## Constraints

- Hyprland 0.57 Lua config: `hl.curve(name, { type = "spring", mass,
  stiffness, damping })`, `hl.animation({ leaf, enabled, speed, spring|bezier,
  style })`. The stock tree is in `/usr/share/hypr/hyprland.lua`.
- Everything lives in `hypr/desktop.lua` (loaded before the user's files), so
  later config overrides it.
- Reduce Motion applies at runtime and must survive a Hyprland reload and a
  login; turning it off restores the user's Animations preference, not
  blindly "on".
- Keep idle CPU where v1.0.0 measured it (0.91% on UHD 620); animations must
  not leave the compositor redrawing when nothing moves.

## Calls left to the builder (mine, correct them while reading)

- The exact spring per leaf, derived from `tokens.js` (e.g. `standard`
  500/30/1 for windows and workspaces, quicker and critically damped for
  close and fades). Target feel: open and workspace switch land in about
  200–250 ms, close in about 120–150 ms, no visible overshoot.
- Window open style: a short fade with a slight scale (`popin` near 95%)
  rather than 87%; close as a quick fade. Workspaces slide horizontally.
- How "split toward the side you're working on" maps to dwindle options
  (`smart_split` or cursor-follow), verified live.
- How Reduce Motion reaches Hyprland (the shell applies it at runtime when
  the setting changes and at start, reading the user's Animations preference
  to restore).
- Tests: the config loads in the session test stand-in, the Reduce Motion
  path has a test, and the owner does the final feel check live.
