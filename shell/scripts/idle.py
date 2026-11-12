#!/usr/bin/env python3
"""Bloom's idle handling: write hypridle's config from the idle settings and run
hypridle with it. Usage: idle.py LOCK SCREEN_OFF SLEEP (minutes, 0 = never).

hypridle also answers `loginctl lock-session` (the session menu's Lock and the
lock before sleep) by asking Bloom's lock screen to lock."""
import os
from pathlib import Path
import sys
import tempfile

LIMIT = 24 * 60


def render(lock, screen_off, sleep):
    lines = ["# Written by Bloom from Settings > General > Lock Screen.",
             "general {",
             "    lock_cmd = qs -c bloom ipc call lock lock",
             "    before_sleep_cmd = loginctl lock-session",
             "    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'",
             "    inhibit_sleep = 3",
             "}"]
    steps = ((lock, "loginctl lock-session", None),
             (screen_off, "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'",
              "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'"),
             (sleep, "systemctl suspend", None))
    for minutes, action, resume in steps:
        if minutes:
            lines += ["listener {", f"    timeout = {minutes * 60}", f"    on-timeout = {action}"]
            lines += [f"    on-resume = {resume}"] if resume else []
            lines.append("}")
    return "\n".join(lines) + "\n"


def main(argv):
    if len(argv) != 3 or not all(a.isdigit() and int(a) <= LIMIT for a in argv):
        print(f"usage: idle.py LOCK SCREEN_OFF SLEEP (whole minutes, 0 to {LIMIT})", file=sys.stderr)
        return 2
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        print("idle.py: XDG_RUNTIME_DIR is not set", file=sys.stderr)
        return 2
    folder = Path(runtime) / "bloom"
    folder.mkdir(mode=0o700, exist_ok=True)
    os.chmod(folder, 0o700)
    path = folder / "hypridle.conf"
    fd, temporary = tempfile.mkstemp(prefix=".hypridle-", dir=folder)
    with os.fdopen(fd, "w") as stream:
        stream.write(render(*(int(a) for a in argv)))
    os.replace(temporary, path)
    os.execvp("hypridle", ["hypridle", "-c", str(path)])


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
