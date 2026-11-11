#!/usr/bin/env python3
"""Keep the Bloom login screen in step with the desktop: copy the wallpaper and
write State.qml (wallpaper, lock screen colours, scale) into the login folder.

Reads JSON on stdin. The folder (/var/lib/bloom/login, group bloom-login) is made by
the installer; without it, or without write access, this does nothing. Only
validated colours and numbers reach the QML file the greeter loads."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

FOLDER = Path(os.environ.get("BLOOM_LOGIN_DIR", "/var/lib/bloom/login"))
COLOURS = ("accent", "bgExpanded", "text", "textMuted", "border", "groupBg")
IMAGES = (".jpg", ".jpeg", ".png", ".webp")
VIDEOS = (".mp4", ".webm", ".mkv", ".mov")
LIMIT = 64 * 1024 * 1024


def current_wallpaper():
    try:
        match = re.search(r'property url wallpaper: "(wallpaper-[0-9a-f]+\.[a-z]+)"', (FOLDER / "State.qml").read_text())
    except OSError:
        return None
    return match.group(1) if match and (FOLDER / match.group(1)).is_file() else None


def still(source):
    """An image to show: the file itself, or a video's first frame."""
    suffix = source.suffix.lower()
    if suffix in IMAGES and source.is_file() and source.stat().st_size <= LIMIT:
        return source.read_bytes(), ".jpg" if suffix == ".jpeg" else suffix
    if suffix in VIDEOS and source.is_file() and shutil.which("ffmpeg"):
        with tempfile.TemporaryDirectory() as temporary:
            frame = Path(temporary) / "frame.jpg"
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(source), "-frames:v", "1", str(frame)],
                           capture_output=True, timeout=30)
            if frame.is_file() and frame.stat().st_size <= LIMIT:
                return frame.read_bytes(), ".jpg"
    return None


def write(path, data):
    temporary = path.with_name(f".{path.name}.tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)
    with os.fdopen(fd, "wb") as stream:
        stream.write(data)
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def main():
    if not FOLDER.is_dir() or not os.access(FOLDER, os.W_OK | os.X_OK):
        return
    try:
        request = json.load(sys.stdin)
    except ValueError:
        return
    if not isinstance(request, dict):
        return
    name = current_wallpaper()
    picture = still(Path(str(request.get("wallpaper", "")))) if request.get("wallpaper") else None
    if picture:
        data, suffix = picture
        name = f"wallpaper-{hashlib.sha256(data).hexdigest()[:12]}{suffix}"
        if not (FOLDER / name).is_file():
            write(FOLDER / name, data)
    lines = ["import QtQuick", "", "// Written by Bloom when the wallpaper or theme changes.", "QtObject {"]
    if name:
        lines.append(f'\tproperty url wallpaper: "{name}"')
    for key in COLOURS:
        value = request.get(key)
        if isinstance(value, str) and re.fullmatch(r"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})", value):
            lines.append(f'\tproperty color {key}: "{value}"')
    for key, low, high in (("scale", 0.5, 4), ("zoom", 1, 4)):
        value = request.get(key)
        if isinstance(value, (int, float)) and not isinstance(value, bool) and low <= value <= high:
            lines.append(f"\tproperty real {key}: {round(float(value), 4)}")
    lines.append("}")
    write(FOLDER / "State.qml", ("\n".join(lines) + "\n").encode())
    for old in FOLDER.glob("wallpaper-*"):
        if old.name != name:
            old.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.SubprocessError):
        pass
