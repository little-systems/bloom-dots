# Alt + Tab window switcher

Owner request (2026-11-21): Alt + Tab switches between windows. Tiled windows
take focus; floating ones also come to the front, as on Windows. Owner's
choices: the current workspace only, most recent first, a Bloom switcher with
live previews while Alt is held, and Alt + Shift + Tab going backwards.

## Behaviour

- Alt + Tab selects the window used before the current one; holding Alt,
  each Tab steps further back and Shift + Tab steps forward, wrapping.
- Releasing Alt switches: focus, plus bring-to-front for a floating window.
- Esc while Alt is held cancels. Clicking a tile switches to it.
- The card appears only once Alt has been held for a moment (120 ms), so a
  quick tap flips to the previous window without a flash.
- A workspace with fewer than two windows does nothing.

## Approach

Each round trip through `bloom ipc` costs about 56 ms, so the switching itself
lives in Hyprland's Lua (`hypr/alt-tab.lua`) where it is immediate: it takes
the most-recent-first snapshot (`focus_history_id`), steps, and focuses on
release. It tells the shell what to draw through `bloom ipc switcher open
<addresses> <index>`, `select <index>` and `hide`; addresses are hex, so the
command needs no quoting. The shell looks titles, app ids and live captures up
itself (ToplevelManager, Apps).

A click focuses from the shell. On Alt release Lua sees the active window is no
longer the one the cycle started from and leaves it alone.

Esc is bound only while a cycle runs (the keybind object unbinds itself after),
so Alt + Esc stays free for apps otherwise. The Alt release binds pass the key
on to apps (`non_consuming`) and match with any modifiers (`ignore_mods`).

## Shell

- `services/Switcher.qml`: what's shown (`addresses`, `index`), the 120 ms
  reveal, `choose(index)` for clicks. IPC target `switcher`.
- `modules/switcher/SwitcherWindow.qml` + `SwitcherView.qml`: a centred card
  of tiles, each a live capture (DockCapture, like the overview) with the app's
  icon and title; the selected tile has the accent outline. Loads with the
  `overview` module, so nobody's module list needs editing.
- Its layer, `bloom:switcher`, joins the card layers' blur rule (0.55) and
  fades through Hyprland like the other card windows. The previous rule pair
  becomes a legacy form that upgrades on the next save.

## Tests

Plain-Lua cases for ordering, stepping, wrapping, commit, click, cancel and
the Esc bind's lifetime; switcher.js and SwitcherView QML tests; the store's
rule cases; an integration test driving `bloom ipc switcher` under sway.
