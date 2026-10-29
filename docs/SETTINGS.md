# Bloom settings

Generated from `shell/services/settings.js` by `node tools/gen-settings-doc.mjs`; do not edit by hand.

Settings live in `~/.config/bloom/settings.json` (`$XDG_CONFIG_HOME/bloom/settings.json`) as one flat JSON object. Edits apply live. An invalid or missing value uses its default and logs a warning; a file with a syntax error is ignored (the last good settings stay) until it is fixed. Values in Bloom for Windows' string form (`"true"`, `"0.8"`) are accepted.

| Key | Type | Default | Allowed | Description |
|---|---|---|---|---|
| `bloom-theme-mode` | enum | `"dark"` | `dark`, `light`, `custom`, `adaptive` | Theme mode. Adaptive follows the wallpaper; until wallpaper theming exists it falls back to dark. |
| `bloom-theme-color` | color | `"#007aff"` | `#rgb` or `#rrggbb` | Accent colour for the custom theme (#rgb or #rrggbb). |
| `bloom-theme-opacity` | number | `0.8` | 0.1 to 1 | Surface opacity. Hovered and open surfaces add 0.12. |
| `bloom-theme-saturation` | number | `0.5` | 0 to 1 | Background saturation for the custom and adaptive themes. |
| `bloom-theme-brightness` | number | `0.15` | 0 to 1 | Background lightness for the custom and adaptive themes. Above 0.55 the text turns dark. |
| `bloom-enabled-modules` | list | `[]` | `notch`, `dock`, `osd`, `notifications`, `launcher`, `overview`, `session`, `lock`, `polkit`, `tray`, `regiontools`, `wallpaper`, `cheatsheet` | Bloom surfaces to run. Anything not listed is left to another shell (e.g. illogical-impulse). |
| `bloom-notch-mode` | enum | `"fixed"` | `fixed`, `smart`, `peek` (`auto-hide` = `smart`) | Notch visibility. fixed = always shown; smart = hides while the focused window sits under it; peek = hidden until hovered or an event shows it briefly. |
| `bloom-notch-edge-delay` | number | `200` | 0 to 2000 | In smart and peek mode, how long (ms) the pointer must rest on the top edge before a hidden notch appears. 0 reveals it at once. |
| `bloom-calendar-enabled` | bool | `true` | `true`, `false` | Show the Calendar and timer panel in the notch. |
| `bloom-notch-command-center-enabled` | bool | `true` | `true`, `false` | Show Command Center and its Wi-Fi/Bluetooth subpanels in the notch. |
| `bloom-notch-devices-enabled` | bool | `true` | `true`, `false` | Show the Connected Devices panel in the notch. |
| `bloom-notch-default-panel` | enum | `"calendar"` | `calendar`, `command-center`, `devices` | Tool panel opened by clicking the collapsed notch when panel memory is off or unavailable. |
| `bloom-notch-panel-memory` | bool | `true` | `true`, `false` | Reopen the last used notch tool panel. |
| `bloom-shelf-persist` | bool | `false` | `true`, `false` | Keep Shelf items across shell restarts in local state. |
| `bloom-status-widgets` | widgets | `{"left":["weather"],"right":["battery"]}` | `{"left": [...], "right": [...]}` of `weather`, `battery`, `cpu`, `ram`, `disk`, `net` | Widgets in the hovered status strip, left and right of the clock. |
| `bloom-weather-enabled` | bool | `true` | `true`, `false` | Show the weather widget (fetches from Open-Meteo; without coordinates the location comes from IP geolocation). |
| `bloom-weather-city` | string | `""` | text, up to 100 characters | City name shown with the weather. Empty means the IP-geolocated city. |
| `bloom-weather-lat` | number | `null` | -90 to 90, or `null` | Latitude for the weather. null uses IP geolocation. |
| `bloom-weather-lon` | number | `null` | -180 to 180, or `null` | Longitude for the weather. null uses IP geolocation. |
| `bloom-temp-unit` | enum | `"celsius"` | `celsius`, `fahrenheit` | Temperature unit for the weather widget. |
| `bloom-time-format-24h` | bool | `false` | `true`, `false` | 24-hour clock in the notch; otherwise 12-hour with AM/PM. |
| `bloom-low-battery-threshold` | number | `20` | 5 to 50 | Battery percentage at or below which the battery fill turns red and the notch shows a low-battery pulse. |
| `bloom-show-update-indicator` | bool | `true` | `true`, `false` | Check for pacman updates hourly (needs pacman-contrib) and show a green dot under the clock while some are pending, with a pulse when new ones arrive. |
| `bloom-dock-mode` | enum | `"smart"` | `fixed`, `smart`, `peek` (`auto-hide` = `smart`) | Dock visibility. fixed = always shown, with its strip reserved; smart = hides while a window covers it; peek = hidden until the pointer rests on the bottom edge. |
| `bloom-dock-edge-delay` | number | `200` | 0 to 2000 | In smart and peek mode, how long (ms) the pointer must rest on the bottom edge before a hidden dock appears. 0 reveals it at once. |
| `bloom-dock-icon-only` | bool | `false` | `true`, `false` | Show dock icons without their tile background. |
| `bloom-dock-separator-enabled` | bool | `true` | `true`, `false` | A divider between pinned apps and other running apps. |
| `bloom-dock-adaptive` | bool | `false` | `true`, `false` | Fixed dock only: stretch to the full screen width while the focused window is maximised. |
| `bloom-dock-win-number-enabled` | bool | `true` | `true`, `false` | Super+Alt+1–9 activate the matching pinned dock app: launch it, focus it, or cycle its windows. |
| `bloom-dock-workspaces-enabled` | bool | `true` | `true`, `false` | Show this monitor's workspaces at the start of the dock (Hyprland). |
| `bloom-dock-preview-enabled` | bool | `true` | `true`, `false` | Show live previews of an app's windows after hovering its dock icon. |
| `bloom-dock-extras-position` | enum | `"off"` | `off`, `left`, `right` | Show drive, trash and folder extras beside the dock apps. |
| `bloom-dock-extras-drives` | bool | `true` | `true`, `false` | Include removable and user-mounted drives in dock extras. |
| `bloom-dock-extras-recycle-bin` | bool | `true` | `true`, `false` | Include the XDG trash in dock extras. |
| `bloom-dock-extras-hidden-drives` | string | `"[]"` | text, up to 8192 characters | JSON array of hidden drive UUIDs, or path:device IDs when a UUID is unavailable. |
| `bloom-dock-extras-folders` | string | `"downloads"` | text, up to 8192 characters | Comma-separated XDG user folders to show, such as downloads and documents. |
| `bloom-dock-extras-custom-folders` | string | `"[]"` | text, up to 8192 characters | JSON array of custom folder paths to show in dock extras. |
| `bloom-osd-timeout` | number | `1000` | 250 to 10000 | Milliseconds an OSD stays visible after a volume or brightness change. |
| `bloom-volume-protection-enabled` | bool | `false` | `true`, `false` | Limit sudden output-volume increases and enforce a maximum level. |
| `bloom-volume-max-jump` | number | `10` | 1 to 100 | Largest allowed output-volume increase in percentage points at once when protection is enabled. |
| `bloom-volume-max-level` | number | `99` | 0 to 200 | Maximum output volume in percent when protection is enabled. |
| `bloom-notifications-dnd` | bool | `false` | `true`, `false` | Do Not Disturb suppresses normal and low notification cards while retaining history; critical cards still appear. |
| `bloom-notifications-timeout` | number | `7000` | 1000 to 60000 | Default notification card timeout in milliseconds when the sender does not specify one. |
| `bloom-notifications-history-limit` | number | `200` | 0 to 500 | Maximum number of non-transient notifications retained in local history. |
| `bloom-scale` | number | `1` | 0.8 to 1.3 | Size of Bloom's surfaces. |
| `bloom-music-mode-enabled` | bool | `true` | `true`, `false` | Show playing media in the notch: album art, visualizer and the music player. |
| `bloom-music-compact-notch` | bool | `true` | `true`, `false` | Show playing media in the collapsed notch. When off, music appears only when you hover the notch. |
| `bloom-media-layout` | enum | `"classic"` | `classic`, `compact` | Music player layout: classic = large album art; compact = small art with a progress bar. |
| `bloom-media-visualizer-enabled` | bool | `true` | `true`, `false` | Audio visualizer bars in music mode (needs cava). Also read from `bloom-visualizer-enabled`. |
| `bloom-media-album-art-enabled` | bool | `true` | `true`, `false` | Album artwork in the collapsed notch. |
| `bloom-media-ambience-enabled` | bool | `true` | `true`, `false` | Coloured glow from the album art behind the open player. |
| `bloom-media-compact-glow-enabled` | bool | `true` | `true`, `false` | Glow around the album art in the collapsed notch. |
