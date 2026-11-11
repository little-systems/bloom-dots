#!/usr/bin/env python3
"""Render supported application themes from Bloom's selected opaque palette.

The shell passes colors on stdin. Files are written under BLOOM_THEME_OUT, a
staging tree; adaptive-theme.sh and theme-owner.py own installation, backups,
locking and restore.
"""
import json
import os
from pathlib import Path
import re
import sys


def rgb(value):
    if not isinstance(value, dict):
        raise ValueError("missing color")
    color = tuple(value.get(k) for k in ("r", "g", "b"))
    if not all(isinstance(c, (int, float)) and 0 <= c <= 255 for c in color):
        raise ValueError("invalid color")
    return tuple(round(c) for c in color)


def mix(a, b, amount):
    return tuple(round(x * (1 - amount) + y * amount) for x, y in zip(a, b))


def hex_color(color):
    return "#" + "".join(f"{c:02x}" for c in color)


def gtk_theme(home, light):
    # Adwaita-dark is not a built-in GTK3 theme name on every distribution.
    # An unavailable name silently falls back to light, including in Electron.
    roots = [home / ".themes", home / ".local/share/themes"]
    roots += [Path(p) / "themes" for p in os.environ.get(
        "XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]
    for name in (("adw-gtk3", "Adwaita") if light else ("adw-gtk3-dark", "Adwaita-dark")):
        if any((root / name / "gtk-3.0/gtk.css").is_file() for root in roots):
            return name
    # Built-in Adwaita supports the prefer-dark setting without a separate theme.
    return "Adwaita"


def update_settings(path, values):
    text = path.read_text() if path.exists() else ""
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if line.strip() == "[Settings]"), None)
    if start is None:
        lines += ["", "[Settings]"]
        start = len(lines) - 1
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("[")), len(lines))
    section = lines[start + 1:end]
    for key, value in values.items():
        found = next((i for i, line in enumerate(section) if line.split("=", 1)[0].strip() == key), None)
        if found is None:
            section.append(f"{key}={value}")
        else:
            section[found] = f"{key}={value}"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines[:start + 1] + section + lines[end:]) + "\n")


def main():
    job = json.load(sys.stdin)
    surface, text, accent = (rgb(job[k]) for k in ("surface", "text", "accent"))
    light = job.get("light")
    if not isinstance(light, bool):
        raise ValueError("missing light/dark mode")
    # Selection foreground follows the actual chosen accent's luminance.
    linear = [c / 3294.6 if c <= 10 else ((c / 255 + .055) / 1.055) ** 2.4 for c in accent]
    luminance = sum(c * w for c, w in zip(linear, (.2126, .7152, .0722)))
    on_accent = (0, 0, 0) if luminance > .179 else (255, 255, 255)
    roles = dict(surface=surface, on_surface=text, primary=accent, on_primary=on_accent,
                 on_surface_variant=mix(surface, text, .65), outline=mix(surface, text, .4),
                 outline_variant=mix(surface, text, .25), surface_container_low=mix(surface, text, .025),
                 surface_container=mix(surface, text, .04), surface_container_high=mix(surface, text, .07),
                 error=(186, 26, 26) if light else (255, 138, 128),
                 secondary=(145, 108, 36) if light else (225, 195, 125),
                 tertiary=(40, 115, 70) if light else (155, 215, 175),
                 secondary_fixed_dim=(30, 120, 135) if light else (125, 210, 225),
                 tertiary_fixed_dim=(140, 65, 150) if light else (215, 170, 225))
    home = Path(os.environ.get("BLOOM_THEME_HOME", Path.home()))
    # adaptive-theme.sh renders into a staging tree and installs owned files.
    out = Path(os.environ.get("BLOOM_THEME_OUT", home))
    templates = Path(__file__).resolve().parent.parent / "theming" / "templates"
    targets = {"gtk3.css": ".config/gtk-3.0/gtk.css", "gtk4.css": ".config/gtk-4.0/gtk.css",
               "fuzzel.ini": ".config/fuzzel/fuzzel_theme.ini",
               "kitty.conf": ".local/state/quickshell/user/generated/terminal/kitty-theme.conf",
               "hyprland.lua": ".config/hypr/hyprland/colors.lua",
               "qt.colors": ".local/share/color-schemes/BloomAdaptive.colors"}
    outputs = {}
    for template, destination in targets.items():
        def substitute(match):
            value = hex_color(roles[match[1]])
            return value[1:] if match[2] == "hex_stripped" else value
        rendered = re.sub(r"\{\{colors\.([a-z_]+)\.default\.(hex|hex_stripped)\}\}",
                          substitute, (templates / template).read_text())
        if "{{" in rendered:
            raise ValueError("unresolved theme token")
        outputs[out / destination] = rendered
    # Validate all tokens before changing a file.
    for path, rendered in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_name(path.name + ".bloom-new")
        temporary.write_text(rendered)
        temporary.replace(path)
    for version in ("3.0", "4.0"):
        update_settings(out / f".config/gtk-{version}/settings.ini", {
            "gtk-theme-name": gtk_theme(home, light) if version == "3.0" else "Adwaita",
            "gtk-application-prefer-dark-theme": "false" if light else "true"})
    print("light" if light else "dark")


if __name__ == "__main__":
    try:
        if len(sys.argv) == 3 and sys.argv[1] == "--gtk-theme" and sys.argv[2] in ("light", "dark"):
            print(gtk_theme(Path(os.environ.get("BLOOM_THEME_HOME", Path.home())), sys.argv[2] == "light"))
        else:
            main()
    except (ValueError, KeyError, TypeError) as error:
        print(f"Invalid Bloom palette: {error}", file=sys.stderr)
        sys.exit(2)
