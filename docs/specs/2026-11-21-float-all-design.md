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

## Window sizes

Owner's follow-up the same day: floated windows came up at whatever size
Hyprland had for them, which looked random. Owner's choices: a default size,
remembered per app, always centred.

- A window it floats gets its app's remembered size, or 1280 x 800, never
  more than 80% of the screen (in layout pixels, so scaling counts), and is
  centred. Windows floated together on one workspace are nudged 32 px apart
  so they don't stack exactly.
- An app's size (by window class) is remembered when its window is tiled
  back, closed, or Hyprland reloads; tiny sizes and nameless windows aren't.
- Kept in `$XDG_STATE_HOME/bloom/floating-sizes` (`hypr/float-sizes.lua`),
  one tab-separated line per app, so it lasts through reloads and restarts.
  Windows that float on their own keep their own sizes.

## Shape

`hypr/float-all.lua` returns `new(hl, sizes)` → `{ toggle, opened, closed,
unloading, active }`,
kept free of globals so plain Lua can test it with a stand-in `hl`.
`hypr/desktop.lua` loads it from the checkout, binds Super + Alt + Space to
`toggle` and subscribes `opened` to `window.open`, `closed` to `window.close`
and `window.destroy`, and `unloading` to `config.unload`.

## Tests

Plain-Lua cases (tests/units): floats only tiled windows, tiles back only
those, new windows float while on and not after, rule-floated windows stay,
closed windows are forgotten; the bind and subscriptions exist in desktop.lua.
