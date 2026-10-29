# Bloom audit tools

These run Bloom's own React UI (the Windows app, `~/Projects/bloom` @ b5fb962) in a headless browser to measure it and record it. Nothing here ships.

## Setup

1. Copy the fork without `.git`, `src-tauri`, `node_modules` and `website`. Then run `npm install` in the copy.
2. Copy in the audit files:
   - `bloom-mock.ts` goes to `src/`. Add `import "./bloom-mock";` as the first line of `src/main.tsx`, `src/dock-main.tsx` and `src/Overlay.tsx`. It mocks Tauri's IPC with sample data and exposes `window.bloomMock.emit()`.
   - `art.html` goes to the root and `art-main.tsx` to `src/`. They render one `DeviceArt` drawing.
3. Start Vite: `npm run dev` (port 1420).
4. The drivers use `playwright-core` and Playwright's cached `chrome-headless-shell`. Set `PLAYWRIGHT_CORE` and `CHROME` if they're elsewhere.

## Tools

- `drive.cjs`, `drive2.cjs`: capture every notch, dock and OSD state as a PNG, with geometry JSON and `.bloom` motion samples. They produced `docs/audit/2026-10-29-bloom/`.
- `record-device-art.cjs <out>`: records each device drawing's connect and disconnect animation on a virtual clock (100 fps, exact). The output is `shell/assets/device-art/anim/`: `<art>-play.webp`, `<art>-leave.webp` and `<art>.png` (the still).
- `record-transitions.cjs <out>`: records Bloom's notch transitions at 60 fps on the same clock, for side-by-side checks against the shell.
- `drive-music.cjs <out> <art.jpg>`: captures the music player (classic and compact, with and without art) as PNGs with geometry JSON. `TITLE`, `ARTIST` and `LAYOUTS` override the track and layouts. Settings reach Bloom through the mock's `mock-settings` too: a key only in localStorage looks like a stale mirror to Bloom, which drops it and reloads forever.
- `record-glow.cjs <out.png> <art.jpg>`: Bloom's ambient glow alone (player controls hidden) for an art image, to diff against the shell's `Ambience` rendered with the same art. Findings: Chromium blurs with a transparent surround, applies the filter before the 1.8× transform (so σ = 52 × 1.8), and framer's `animate` sets the image's opacity to 1 over the stylesheet's 0.85.
