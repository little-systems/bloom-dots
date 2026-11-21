# Grab handle for floating windows

Owner request (2026-11-21): apps like Spotify draw no title bar, so a
floating one can't be grabbed and moved (Super + drag works but needs a
modifier). Owner picked a Bloom grab handle over title bars from a Hyprland
plugin (needs the plugin manager, doesn't look like Bloom).

## Behaviour

- The focused floating window (focus follows the mouse, so the one under the
  pointer) gets an invisible zone, 180 x 18 px, centred on its top edge, half
  above it and no wider than the window. Fullscreen and tiled windows get none.
- While the pointer is in the zone, a 56 x 6 pill in Bloom's colours fades in
  (150 ms) and the cursor is an open hand.
- Dragging it with the left button moves the window with the pointer and
  brings it to the front. The window keeps its top edge on screen and 64 px
  within reach, so it can't be lost.

## Shape

- `shell/modules/grab/grab.js`: which window, where the zone goes, where a
  drag puts the window, and the move dispatch. Pure.
- `GrabHandle.qml`: the zone and pill; reports the drag in its window's
  coordinates. Pure.
- `GrabWindows.qml`: a click-through `bloom:grab` layer (Top) per screen,
  taking the pointer only in the zone. Reads Hyprland's window list through
  Quickshell (socket, no processes), refreshed on Hyprland's events and every
  250 ms while a floating window is focused, since moving one sends no event.
  Moves at most once a frame over the socket. IPC `grab state` reports the
  zone per screen.
- Loads with the overview module and only under Hyprland.

## Tests

grab.js and GrabHandle QML tests. The drag itself needs a live Hyprland
window, so the owner checks it.
