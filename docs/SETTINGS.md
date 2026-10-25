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
| `bloom-status-widgets` | widgets | `{"left":["weather"],"right":["battery"]}` | `{"left": [...], "right": [...]}` of `weather`, `battery`, `cpu`, `ram`, `disk`, `net` | Widgets in the hovered status strip, left and right of the clock. |
| `bloom-weather-enabled` | bool | `true` | `true`, `false` | Show the weather widget (fetches from Open-Meteo; without coordinates the location comes from IP geolocation). |
| `bloom-weather-city` | string | `""` | text, up to 100 characters | City name shown with the weather. Empty means the IP-geolocated city. |
| `bloom-weather-lat` | number | `null` | -90 to 90, or `null` | Latitude for the weather. null uses IP geolocation. |
| `bloom-weather-lon` | number | `null` | -180 to 180, or `null` | Longitude for the weather. null uses IP geolocation. |
| `bloom-temp-unit` | enum | `"celsius"` | `celsius`, `fahrenheit` | Temperature unit for the weather widget. |
| `bloom-time-format-24h` | bool | `false` | `true`, `false` | 24-hour clock in the notch; otherwise 12-hour with AM/PM. |
| `bloom-low-battery-threshold` | number | `20` | 5 to 50 | Battery percentage at or below which the battery fill turns red. |
| `bloom-scale` | number | `1` | 0.8 to 1.3 | Size of Bloom's surfaces. |
