# Settings audit against ii

**Date:** 2026-10-31. **Compared:** Bloom's settings app at `949f650` with ii's `modules/settings` and `settings.qml`, by reading the code. Neither app was driven by a person, so UX findings are judgements from the code, not user testing.

## Verdict

Bloom's app is wider and ii's is deeper. Bloom covers the system, which ii doesn't, and looks better. ii exposes far more of the shell's own behaviour, and its controls are more precise and work from the keyboard. Bloom's biggest weakness is that it can only be used with a mouse.

## Strengths and weaknesses

| Area | Bloom | ii | Better |
|---|---|---|---|
| System settings (display, sound, network, Bluetooth, power, storage) | Pages exist, some read-only | None | Bloom |
| Live previews | Real surfaces with sample data | None | Bloom |
| Visual design | Bloom's language, measured | Material, consistent | Bloom |
| Crash isolation | Own process | Own process | Tie |
| Shell behaviour settings | Partial | Very thorough | ii |
| Exact number entry | Sliders only | Spin boxes and sliders | ii |
| Keyboard use | None | Page shortcuts, focus | ii |
| Explaining options | Descriptions only | Tooltips and notes | ii |
| Narrow windows | Fixed size | Rail collapses at 900 px | ii |
| Font choice | None | Seven font roles | ii |
| Finding a setting | No search | No search | Neither |

## Accessibility and UX

| Check | Bloom | ii |
|---|---|---|
| Screen reader labels (`Accessible`) | None | None in the shared widgets |
| Tab through controls | **No.** Nothing takes focus | Partly |
| Keyboard page switching | **No** | Ctrl+Tab, Page Up and Down |
| Visible focus ring | No | From its widgets |
| Reduced motion | No | No |
| Text scaling | Follows Bloom's scale | Follows its own |
| Contrast | Muted text on translucent surfaces needs measuring | Same risk |

**UX problems in Bloom:**

- Network and Bluetooth are the notch's panels dropped into a page. They're too small, and their back arrow does nothing useful there.
- The Display page has no arrangement view.
- Rows don't say when a change needs a restart.
- A wrong value has no undo, and a display change has no "keep these settings?" timeout. **That one can leave a screen unusable.**
- Input and Windows pages show typical values, not yours, and don't persist yet.
- Default Apps can't be changed.

## Missing compared with ii

**Settings that already exist in Bloom with no control:** `bloom-volume-protection-enabled`, `bloom-volume-max-jump`, `bloom-volume-max-level`, `bloom-osd-timeout`, `bloom-notifications-dnd`, `bloom-notifications-timeout`, `bloom-notifications-history-limit`, `bloom-media-visualizer-enabled`, `bloom-media-album-art-enabled`, `bloom-wallpaper-dir`, `bloom-lock-wallpaper`.

| ii area | What we lack | Worth porting |
|---|---|---|
| Quick | Shell, terminal, launcher, GTK and Qt opacity; blur strength | Yes |
| Audio | Earbang protection controls | Yes, cheap |
| Battery | Critical warning, auto suspend, full warning | Yes |
| Sounds | Battery and timer sounds | Yes |
| Time | Seconds, custom format | Yes |
| Language | Interface language | Later |
| Policies, work safety | AI and anime toggles, hiding sensitive images | No |
| Bar | Notification count, workspaces shown | Partly; Bloom has no bar |
| Background | Wallpaper zoom, parallax, clock and weather widgets | Zoom only |
| Cheatsheet | Symbols, split keys, font sizes | Partly |
| Dock | Pinned on startup, tinted icons | Tinted icons |
| Lock screen | Blur, zoom, clock position, locked text, security options | Yes |
| Notifications | Timeout, forced monitor | Yes |
| Overlay | Crosshair, floating image | No |
| Region tools | Hint targets, aim lines, circle selection | Partly |
| Sidebars | Quick toggles, corner hover | Maps to the notch |
| OSD, overview | Timeout; rows, scale, icons | Yes |
| Fonts | Seven font roles | One or two |
| Services | Save paths, search prefixes and engine, update interval, weather GPS and polling, resource polling | Yes |
| Music recognition, AI | Whole features | Later, your call |
| Advanced | Per-target colour generation, terminal harmony | Yes, for Adaptive |

## Keybinds still pointing at ii

| Key | ii feature | Bloom replacement |
|---|---|---|
| Super+V | Clipboard | Launcher `;` mode (exists) |
| Super+. | Emoji | Launcher `:` mode (exists) |
| Super+N | Right sidebar | Notch command center |
| Super+M | Media controls | Notch player |
| Ctrl+Super+Shift+D | Light and dark | Theme toggle |
| Super+J | Bar toggle | Dock toggle |
| Super+A, B, O | Left sidebar (AI and more) | Needs a decision |
| Super+Alt+A | Detached sidebar | Needs a decision |
| Super+K | On-screen keyboard | Needs a new surface |
| Super+G | Overlay widgets | Needs a decision |
| Super+Shift+A | Google Lens | Decision: uploads screenshots |
| Super+Shift+T | Screen translate | Needs a decision |
| Ctrl+Super+P | ii panel family | Remove |
| Super held | Workspace numbers | Dock workspaces |

## Recommended order

1. Keyboard use: Tab focus, a focus ring, arrow keys on sliders, Escape, page shortcuts. Add a reduced-motion setting and screen reader labels.
2. Safety and truth: a display-change timeout, real values on every page, persistence, restart hints.
3. Controls for the settings listed above, plus lock, notifications, OSD and overview.
4. Full Network and Bluetooth pages, built for the window rather than borrowed from the notch.
5. A search box in the sidebar. ii has none, so this would beat it.
6. Sounds, opacity per surface, fonts and Adaptive options.
