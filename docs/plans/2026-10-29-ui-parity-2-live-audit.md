# UI parity 2: live audit of Windows Bloom and the port plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the notch, dock, OSD and device alert to Bloom's look and motion on Windows at the owner's 125 % display scale, from a live run of Bloom's own UI instead of reading its CSS.

**Method (2026-10-29):**
- Bloom @ b5fb962 ran in headless Chromium (Playwright's cached `chrome-headless-shell`) from a scratch copy of the fork, with Tauri's backend mocked: `tools/bloom-audit/bloom-mock.ts`, `drive.cjs` and `drive2.cjs`.
- Each state was captured at Bloom's CSS pixels with its geometry (rects and computed fonts) and `.bloom`'s rect every frame through each transition.
- Ours was rendered in the same states offscreen (pure views), and live for the panels.
- Captures: `docs/audit/2026-10-29-bloom/`.

**Owner facts:** Windows display scale 125 %; one monitor here (eDP-1, scale 1).

## Findings

### 1. Scale is the "cramped" feeling

At equal CSS pixels the collapsed notch, the status strip, the music pill, the classic player, the Command Center, the calendar, the battery hub and the dock match Bloom within a pixel or two (`bloom-vs-ours-notch.png`).

On Windows at 125 % every CSS pixel drew as 1.25 screen pixels: the 140 × 36 pill was 175 × 45, the 13 px clock 16.25 px, the dock's 36 px tiles 45 px. Ours draws 1 : 1.

- **Fix:** `bloom-scale` 1.25. Every surface already applies it: notch, dock, OSD, notifications.
- **Needs the owner's OK:** this changes `~/.config/bloom/settings.json`.

### 2. Device alert (the "half-baked" one)

| | Bloom | Ours |
|---|---|---|
| Pill | 330 × 76 | 330 × 76 ✓ |
| Art | 60 × 60 at (26, 8) | 40 at (35, 18) |
| Art choice | by kind: a mouse draws the mouse | guessed from the name; "MX Master 3" draws the generic device |
| AirPods / earbuds | the case opens and the buds rise (drawn by script, `caseArt.ts`) | blank: the generated static SVG has no case |
| Motion | each drawing's connect animation (`phase="play"`, about 30 keyframe sets in `devices.css`) and its disconnect (`"leave"`) | a 0.42 s scale and fade |
| Ring | 28 px, stroke 2.6 | ✓ |

The same blank stem-buds and round-buds art shows in the Connected devices rows.

### 3. Panels keep the status widgets

With a panel open Bloom's top row is still the main row: weather on the left, battery on the right, beside the clock and arrows (`bloom-notch-states.png`: calendar, Command Center, devices, Wi-Fi, Bluetooth). Ours shows only the clock.

### 4. Motion

`.bloom` was sampled through hover (140 → 300 over about 0.5 s), opening the calendar (300 × 36 → 480 × 273), switching panels, closing (350 × 300 → 140 × 36), opening the player (200 × 36 → 340 × 120) and the device alert (200 × 36 → 330 × 76).

Our springs are framer's, with the parity test in `run-all.sh`. The shapes match; there are no findings beyond §2.

### 5. Dock and OSD

- **Dock:** matches: 36 px tiles with Bloom's gradient, 2 px dots, divider, tooltip and menu. Bloom's first tile is Windows Start; ours is the workspace segment (spec D7).
- **OSD:** a 42 × 196 pill, 10 × 144 bar, percentage 22 × 12 under it. To compare against ours in Task 5.

## Tasks

### Task 1: Bloom's animated device art

- [ ] **Step 1: Record the art.** `tools/bloom-audit/record-device-art.cjs` renders each `DeviceArt` key alone in the headless page, for the `play` and `leave` phases.
  - It pauses every animation (`document.getAnimations()`, which includes CSS and Web Animations, so `caseArt.ts` and the pulses too) and steps time in 1/60 s.
  - It writes transparent animated WebP at 150 px (60 px × 2.5 for scale 1.25 on a sharp display) to `shell/assets/device-art/anim/<key>-play.webp` and `-leave.webp`, plus the final `play` frame as `<key>.png` for lists.
- [ ] **Step 2: Tests first** (`tst_deviceart.qml`):
  - `DeviceArt` with `phase` plays its animation once and holds the last frame;
  - `still` shows the final frame with no frames drawn;
  - a new `runId` replays it;
  - nothing draws at rest.
- [ ] **Step 3:** `DeviceArt.qml` on `AnimatedImage`, with `phase`, `runId` and `still`.
- [ ] **Step 4: Device alert to Bloom.**
  - The art is 60 at (26, 8), and its kind comes from BlueZ (the alert carries `kind`).
  - `leave` plays on disconnect.
  - Test the geometry and the art choice.
- [ ] **Step 5:** The Connected devices rows use the still frames. The suite passes. Commit.

### Task 2: Status widgets in the open-panel header

- [ ] With a panel open, the header shows the left and right status widgets as the main row does, with the clock and arrows.
- [ ] Test it, then commit.

### Task 3: Scale (needs the owner's OK)

- [ ] Set `bloom-scale` to 1.25 with the settings IPC, after backing up `settings.json`.
- [ ] Live screenshots against the Bloom captures scaled by 1.25.

### Task 4: OSD comparison

- [ ] Render ours in the OSD's volume, brightness and mixer states next to `bloom-osd-volume.png`.
- [ ] Fix differences test-first.

### Task 5: Remaining UI parity 1 work

- [ ] Wi-Fi and Bluetooth panels (Task 5 there).
- [ ] Shelf tiles.
- [ ] Owner live check.
- [ ] Whole-branch review.
