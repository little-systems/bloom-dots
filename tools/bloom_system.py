"""Bloom's system phase: what a fresh Arch needs at root level, planned, recorded
and reversible. Everything reads and writes below system_root(), so tests use a
fake root and stub tools. Home directories are never touched here."""
from __future__ import annotations

import os
from pathlib import Path
import subprocess

NETWORK_SERVICES = ("NetworkManager", "systemd-networkd", "iwd", "connman", "netctl")


class Failure(RuntimeError):
    pass


def system_root():
    return Path(os.environ.get("BLOOM_SYSTEM_ROOT", "/"))


def regular_users(root):
    users = []
    try:
        lines = (root / "etc/passwd").read_text().splitlines()
    except OSError:
        return users
    for line in lines:
        fields = line.split(":")
        if len(fields) < 7 or not fields[2].isdigit():
            continue
        uid, shell = int(fields[2]), fields[6]
        if 1000 <= uid < 60000 and not shell.endswith(("nologin", "false")):
            users.append({"name": fields[0], "uid": uid, "gid": int(fields[3]) if fields[3].isdigit() else uid,
                          "home": fields[5]})
    return users


def choose_user(root, requested, ask):
    """The account Bloom is installed for. `ask(users) -> index` when several exist."""
    users = regular_users(root)
    if requested:
        for user in users:
            if user["name"] == requested:
                return user
        raise Failure(f"{requested} is not a regular user account on this system")
    if not users:
        raise Failure("no regular user account exists yet; create one (archinstall does this) and run again")
    if len(users) == 1:
        return users[0]
    if ask is None:
        names = ", ".join(user["name"] for user in users)
        raise Failure(f"several accounts exist ({names}); choose one with --user NAME")
    return users[ask(users)]


def display_manager(root):
    link = root / "etc/systemd/system/display-manager.service"
    if not link.is_symlink():
        return None
    return Path(os.readlink(link)).stem


def enabled_network(root):
    units = root / "etc/systemd/system"
    enabled = {path.stem for path in units.glob("*.wants/*.service")} if units.is_dir() else set()
    return [name for name in NETWORK_SERVICES if name in enabled]


def in_chroot():
    try:
        return subprocess.run(["systemd-detect-virt", "--chroot"], capture_output=True).returncode == 0
    except OSError:
        return False
