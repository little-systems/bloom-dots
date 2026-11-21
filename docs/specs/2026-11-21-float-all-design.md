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
- Hyprland resets Lua state on a config reload. At first that ended the
  mode and stranded the windows it had floated (the owner hit it with
  Spotify): the next press saw them as floating on their own. The mode and
  its windows (address and process id) are now kept in
  `$XDG_STATE_HOME/bloom/float-all` (`hypr/float-mode.lua`) and read back
  after a reload; a window is taken back only if it's still floating and the
  same process, since some apps (Spotify) set their name late. A new
  Hyprland session starts with the mode off.

- Apps like Spotify hide to the tray and come back as the same window, and
  Hyprland reports the hide as `window.close`. Forgetting the window there
  stranded it floating (the owner hit it): it came back floating, so it read
  as floating on its own. A hidden window now stays remembered and only
  `window.destroy` forgets it; one hidden when the mode is turned off is
  tiled when it comes back. Hidden windows aren't floated by turning it on.

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
- Owner's next follow-up: the place is remembered too. A window goes back to
  its app's last position when that still fits its screen at the new size;
  otherwise it's centred. Windows landing on the same spot (same remembered
  place, or both centred) are nudged apart.
- Kept in `$XDG_STATE_HOME/bloom/floating-sizes` (`hypr/float-sizes.lua`),
  one tab-separated line per app (class, width, height, x, y; older lines
  without a place still read), so it lasts through reloads and restarts.
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
