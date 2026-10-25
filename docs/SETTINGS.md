# Bloom settings

Generated from `shell/services/settings.js` by `node tools/gen-settings-doc.mjs`; do not edit by hand.

Settings live in `~/.config/bloom/settings.json` (`$XDG_CONFIG_HOME/bloom/settings.json`) as one flat JSON object. Edits apply live. An invalid or missing value uses its default and logs a warning; a file with a syntax error is ignored (the last good settings stay) until it is fixed. Values in Bloom for Windows' string form (`"true"`, `"0.8"`) are accepted.

| Key | Type | Default | Allowed | Description |
|---|---|---|---|---|
| `bloom-theme-mode` | enum | `"dark"` | `dark`, `light`, `custom`, `adaptive` | Theme mode. Adaptive follows the wallpaper; until wallpaper theming exists it falls back to dark. |
| `bloom-theme-color` | color | `"#007aff"` | `#rgb` or `#rrggbb` | Accent colour for the custom theme (#rgb or #rrggbb). |
| `bloom-theme-opacity` | number | `0.8` | 0 to 1 | Surface opacity. Hovered and open surfaces add 0.12. |
| `bloom-theme-saturation` | number | `0.5` | 0 to 1 | Background saturation for the custom and adaptive themes. |
| `bloom-theme-brightness` | number | `0.15` | 0 to 1 | Background lightness for the custom and adaptive themes. Above 0.55 the text turns dark. |
| `bloom-enabled-modules` | list | `[]` | `notch`, `dock`, `osd`, `notifications`, `launcher`, `overview`, `session`, `lock`, `polkit`, `tray`, `regiontools`, `wallpaper`, `cheatsheet` | Bloom surfaces to run. Anything not listed is left to another shell (e.g. illogical-impulse). |
