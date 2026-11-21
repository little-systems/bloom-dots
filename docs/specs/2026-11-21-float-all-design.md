# Float or tile every window

Owner request (2026-11-21): the float/tile keybind should act on all windows,
not just the focused one. One press floats every open window; the next tiles
them all back.

## Decisions (owner's choices)

- **Scope:** every window on every workspace.
- **New windows:** while the mode is on, windows that open tiled float too.
- **Keybind:** Super + Alt + Space becomes the all-windows toggle; the
  single-window toggle goes away.

## Behaviour

- Turning it on floats every tiled window and remembers which ones it floated.
- Turning it off tiles those windows again. Windows that were floating
  already (file dialogs and other rule-floated windows, or ones floated by
  hand) stay floating, so "back to tiling" restores the layout as it was.
- While on, a window that opens tiled is floated and remembered; one whose
  rules float it is left alone.
- Hyprland resets Lua state on a config reload, so a reload ends the mode.
  Windows it floated stay floating until tiled by hand or the mode runs again.

## Shape

`hypr/float-all.lua` returns `new(hl)` → `{ toggle, opened, closed, active }`,
kept free of globals so plain Lua can test it with a stand-in `hl`.
`hypr/desktop.lua` loads it from the checkout, binds Super + Alt + Space to
`toggle` and subscribes `opened`/`closed` to `window.open`/`window.destroy`.

## Tests

Plain-Lua cases (tests/units): floats only tiled windows, tiles back only
those, new windows float while on and not after, rule-floated windows stay,
closed windows are forgotten; the bind and subscriptions exist in desktop.lua.
