# Typing ignores the mouse until it moves

Owner request (2026-11-20): while typing in any search box, the mouse must not
interfere in any way until the owner moves it. Approved approach: hover only
(option 1). The pointer stays visible; nothing global changes in Hyprland.

## Why

Result rows select themselves on hover. Typing changes the results, rows slide
under a pointer that has not moved, Qt re-delivers hover at the same position
and the selection jumps to whatever row is now under it. Hover highlights
flicker the same way. Bloom on Windows has the same behaviour (`Dock.tsx`
selects on mouse enter), so this is a deliberate deviation the owner asked for.

## Design

- `shell/common/TypingGuard.qml`, a `HoverHandler` placed on a search view's
  root. `typed()` sets `typing` and remembers where the pointer is. The guard
  clears `typing` once the pointer's scene position moves more than
  `Tokens.typingGuard.slop` (4 px) from there, or enters from outside when no
  position was known. Rows moving under a still pointer never clear it.
- Every row/cell hover in a search view is gated on `!guard.typing`: hover
  selection and hover highlights are both off while typing. Clicks and taps
  stay live (a click is a clear intent).
- Views and what counts as typing (text edits and the view's navigation keys):
  launcher (incl. emoji/clipboard modes), dock Add App popup, wallpaper
  picker, overview, Settings search, Settings › Notch weather city search.
  `SField` gains an `edited()` signal (user edits only) for Settings search.
- Found on the way: Add App rows all had index -1 (`indexOf` on Repeater
  copies), so hover set the selection to -1. Fixed separately by matching ids.

## Non-goals

Hiding the pointer (Hyprland `cursor:hide_on_key_press`), any change under
`~/dots-hyprland`, changes to non-search hover (dock, notch, tabs).

## Tests

- `tst_typingguard.qml`: same-position hover keeps `typing`; a real move
  clears it; slop is respected.
- Each view: hover a row, type so results change under the still pointer,
  selection/highlight does not follow; move the pointer, hover works again.
