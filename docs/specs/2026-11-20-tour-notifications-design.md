# Tour: where notifications live

Owner request (2026-11-20): the first-run guide gets a page showing how to
check notifications in the top-right corner. Bloom for Windows has no such
page (Windows draws its own notifications), so this is a Linux-only page with
`linux.onboarding.*` text.

## Decisions

- **Place:** right after "A little less interruption" (volume and brightness
  HUDs), since both cover what appears on screen. The guide grows to ten pages.
- **Anchor `notifications`:** the card sits 96 px (scaled, capped like the
  other edges) from the top and right edges. Its arrow is Bloom's guide arrow
  mirrored, so it points up and to the right at the corner. Outside the card
  when the gap holds it (the same rule as the Island), inside otherwise.
- **Live corner:** the guide's input region is only the card and arrow, so
  the real corner target stays usable while the page is open.
- **Sample (owner's choice):** when the page first opens in a tour, Bloom
  posts one real notification via `notify-send -a Bloom` (libnotify is already
  a dependency), so there is something to see in the corner. Going back and
  forth doesn't post another; replaying the tour does.
- **Copy (English source, others fall back):**
  - title "Catch up anytime"
  - description "Notifications slide in at the top-right corner, then tuck
    themselves away. Bloom just sent you one to try."
  - hints: "Point at the very top-right corner to see them again",
    "Clear All empties the list", "Turn on Do Not Disturb in the Command
    Center"
  - sample: "Notifications land here" / "Point at the top-right corner any
    time to see them again."

## Tests

- Layout: placement for the new anchor, mirrored arrow outside and inside,
  input region.
- Pages: ten pages in order, the new page's keys exist in the English catalog.
- Card: the arrow is mirrored on this page only.
- Integration (headless sway): clicking through the guide reaches the page,
  the sample lands in notification history once, and the guide still finishes.
