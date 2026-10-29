# UI parity with Windows Bloom

The source of truth for appearance and interaction is the sibling Windows
checkout, `../bloom/src`. Linux service APIs differ; the UI should keep the
same layout and action sequence wherever the capability exists.

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
