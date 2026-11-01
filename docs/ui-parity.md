# UI parity with Windows Bloom

The source of truth for appearance and interaction is the sibling Windows
checkout, `../bloom/src`. Linux service APIs differ; the UI should keep the
same layout and action sequence wherever the capability exists.

## Motion

Owner override, 2026-11-01: use macOS-inspired motion throughout the Linux UI.
Keep panel contents at their final size while fading, scaling slightly and
sliding into place. Springs settle without overshoot. Content scrollers use
the shared `ScrollGlide` for wheel easing and touchpad momentum, with immediate
interruption by a press, scrollbar or keyboard navigation. Respect Reduce
Motion during entry and while an animation is running.

The previous Bloom size morphs and bouncing springs are available only through
`"bloom-animation-style": "bloom"` in settings.json. The default is `"macos"`;
the Settings UI has no animation-style control. This motion policy supersedes
matching the Windows animation curves. Settings text is also intentionally
larger at the owner's request: 16 px row labels and 13 px descriptions.

## Surface references

| Linux surface | Windows reference | Required comparison |
| --- | --- | --- |
| Notch and panel strip | `App.tsx`, `App.css` | Spring geometry, clock, arrows, click, wheel, corner radii |
| Calendar and timer | `App.tsx` Calendar/timer split view, `App.css` | Split columns, current month grid, editable timer, play/reset, presets |
| Command Center | `App.tsx` controls, `App.css` | 2×2 monochrome tiles, circular actions, volume and brightness sliders |
| Wi-Fi and Bluetooth | `components/WifiPanel.tsx`, `BluetoothPanel.tsx`, `QuickPanel.css` | Clock strip, back/title/radio header, expandable rows, explicit actions |
| Connected devices and alerts | `components/ConnectedDevicesPanel.tsx`, `devices/*`, `QuickPanel.css` | Grouped device rows, Bloom drawings, reported battery meters |
| Shelf | `App.tsx` shelf, `App.css` | Empty drop target, horizontal preview cards, open/copy/drag/remove |

The 2026-10-29 Phase 5 parity pass ports these layouts and the original device
drawings. Platform features absent from the current Linux backend still need
follow-up: Bluetooth discovery/pairing and per-device appearance choices,
Windows-specific settings links, and animated device-art sequences. Keep these
visible capability gaps explicit as later phases add the corresponding
services. Do not substitute unrelated controls for them.

## Settings and supporting surfaces

Owner updates, 2026-11-01:

- UI Scale (`bloom-scale`) controls geometry; Font Scale (`bloom-font-scale`)
  controls text independently through `Fonts.px`. Existing text size is kept
  when adding the font setting. Settings ranges accept exact values through
  `SNumber`, independently of slider drag increments, with range validation.
- AI chat has a dedicated conversation layout in `ChatView` / `ChatMessage`,
  with stable streaming rows, a multiline composer, stop/retry/copy actions,
  common math normalization and opt-in following of new text while reading.
- The session menu groups break actions and power actions in a compact panel.
  Keep package/download confirmations intact when changing its layout.
- Dock content is clipped and revealed with its opening surface. Pinned apps
  and running apps can be reordered; running order is saved in dock state.
  Dropping a running app into the pinned area pins it at the selected position.
  Normalize Qt list signal arguments before saving app order. Exercise drag
  input through the compositor and verify the saved order after a shell restart;
  view-only drag tests cannot catch a rejected service write.
- The selected theme drives supported GTK, Qt, Kitty, Fuzzel and Hyprland
  palettes in every mode, through `Theme` and `scripts/adaptive-theme.sh`.
  GTK3 uses an installed light/dark theme (preferring adw-gtk3), rather than
  assuming Adwaita-dark exists: missing themes can make Electron's System
  appearance fall back to light even when the portal reports dark.
  Tests set `BLOOM_THEME_HOME` and `BLOOM_THEME_NO_RELOAD=1` for isolation.
  Application opacity is independent of Bloom; the Translucent Apps feature
  and its setting were removed.
