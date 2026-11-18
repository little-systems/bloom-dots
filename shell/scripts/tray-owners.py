#!/usr/bin/env python3
"""The process behind each registered tray icon, for matching it to its app.

Prints a JSON list: for every StatusNotifierItem the watcher knows, its
service string (as Quickshell's pixmap URLs name it), Id, Title and IconName,
and its D-Bus connection's pid, parent pid and executable. The pid comes from
the bus daemon, not from the item, so an item can't claim another app. Items
that don't answer are left out; if the watcher itself doesn't answer, nothing
is printed and the exit status is 1. Read-only; every call is bounded."""
import json
import os
import subprocess
import sys

ITEM = "org.kde.StatusNotifierItem"
TIMEOUT = 2


def busctl(args):
    out = subprocess.run(["busctl", "--user", "--json=short", "--timeout=1"] + args, capture_output=True,
                         text=True, timeout=TIMEOUT, check=True, stdin=subprocess.DEVNULL).stdout
    data = json.loads(out)["data"]
    return data[0] if args[0] == "call" and isinstance(data, list) else data


def _process(pid, proc):
    with open(f"{proc}/{pid}/stat", encoding="utf-8", errors="replace") as f:
        text = f.read()
    # comm is in parentheses and may itself contain spaces and parentheses.
    ppid = int(text[text.rfind(")") + 2:].split()[1])
    return ppid, os.readlink(f"{proc}/{pid}/exe")


def _text(bus, name, path, prop):
    try:
        value = bus(["get-property", name, path, ITEM, prop])
    except Exception:
        return ""
    return value if isinstance(value, str) else ""


def collect(bus, proc="/proc"):
    try:
        services = bus(["get-property", "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
                        "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"])
    except Exception:
        return None
    found = []
    for service in services if isinstance(services, list) else []:
        if not isinstance(service, str) or not service:
            continue
        slash = service.find("/")
        name, path = (service, "/StatusNotifierItem") if slash < 0 else (service[:slash], service[slash:])
        try:
            pid = int(bus(["call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                           "GetConnectionUnixProcessID", "s", name]))
            ppid, exe = _process(pid, proc)
        except Exception:
            continue
        found.append({"service": service, "id": _text(bus, name, path, "Id"), "title": _text(bus, name, path, "Title"),
                      "iconName": _text(bus, name, path, "IconName"), "pid": pid, "ppid": ppid, "exe": exe})
    return found


def render(items):
    return json.dumps(items, separators=(",", ":"))


if __name__ == "__main__":
    items = collect(busctl)
    if items is None:
        # The watcher didn't answer: say so, so the shell keeps what it knew.
        sys.exit(1)
    sys.stdout.write(render(items) + "\n")
