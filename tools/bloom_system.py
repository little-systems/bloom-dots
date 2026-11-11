"""Bloom's system phase: what a fresh Arch needs at root level, planned, recorded
and reversible. Everything reads and writes below system_root(), so tests use a
fake root and stub tools. Home directories are never touched here."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

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


# ---------------------------------------------------------------- plan / apply

SOURCE = Path(__file__).resolve().parent.parent
MANIFEST = "var/lib/bloom/system-manifest.json"
THEME = "usr/share/sddm/themes/bloom"
DROPIN = "etc/sddm.conf.d/10-bloom.conf"
LOGIN = "var/lib/bloom/login"
DROPIN_TEXT = "# Bloom's login screen; removed by bloom uninstall.\n[Theme]\nCurrent=bloom\n\n[General]\nDefaultSession=hyprland.desktop\n"
SERVICES = ("bluetooth", "power-profiles-daemon")


def _digest_bytes(data):
    return hashlib.sha256(data).hexdigest()


def tree_digest(path):
    path = Path(path)
    if not path.is_dir():
        return None
    total = hashlib.sha256()
    for item in sorted(p for p in path.rglob("*") if p.is_file()):
        total.update(str(item.relative_to(path)).encode() + b"\0" + item.read_bytes() + b"\0")
    return total.hexdigest()


def theme_sources():
    """(source, path inside the installed theme). The greeter can't read the
    checkout, so the lock screen's own files travel with the theme."""
    sources = [(SOURCE / "sddm/bloom", Path("."))]
    # The lock screen borrows the notch's blur and media parts; QML compiles
    # only the types it uses, so the rest of the folder is inert here.
    for relative in ("shell/common", "shell/modules/lock", "shell/modules/notch", "shell/assets/fonts",
                     "shell/assets/bloom.png"):
        if (SOURCE / relative).exists():
            sources.append((SOURCE / relative, Path(relative)))
    return sources


def build_theme(destination):
    for source, relative in theme_sources():
        target = destination / relative
        if source.is_dir():
            # sddm/bloom/shell links back to the checkout for tests; the copy
            # takes only the parts listed above.
            shutil.copytree(source, target, dirs_exist_ok=True,
                            ignore=lambda folder, names: [n for n in names if n in ("__pycache__",) or n.endswith(".pyc")
                                                          or (Path(folder) / n).is_symlink()])
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)


def staged_theme_digest():
    with tempfile.TemporaryDirectory(prefix="bloom-theme-") as temporary:
        build_theme(Path(temporary) / "bloom")
        return tree_digest(Path(temporary) / "bloom")


def read_manifest(root):
    try:
        return json.loads((root / MANIFEST).read_text())
    except (OSError, ValueError):
        return None


def save_manifest(root, doc):
    path = root / MANIFEST
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(json.dumps(doc, indent=2) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def unit_enabled(root, unit):
    units = root / "etc/systemd/system"
    if unit == "sddm":
        return display_manager(root) == "sddm"
    return any(units.glob(f"*.wants/{unit}.service"))


def group_members(root, group):
    try:
        for line in (root / "etc/group").read_text().splitlines():
            fields = line.split(":")
            if fields[0] == group and len(fields) >= 4:
                return [name for name in fields[3].split(",") if name]
    except OSError:
        pass
    return None


def pkgbuild_hash():
    return _digest_bytes((SOURCE / "packaging/bloom-shell-deps/PKGBUILD").read_bytes())


def plan(root, user, deps=True):
    """Plain-language steps; empty (notes aside) when the system already matches."""
    doc = read_manifest(root) or {}
    current = doc if doc.get("status") == "complete" else {}
    steps = []
    if deps and current.get("pkgbuild_hash") != pkgbuild_hash():
        steps.append({"kind": "packages", "label": "Install Bloom's packages (Quickshell, Hyprland and the rest)"})
    manager = display_manager(root)
    if manager is None:
        steps.append({"kind": "install-sddm", "label": "Install the SDDM login screen"})
        steps.append({"kind": "enable", "unit": "sddm", "label": "Start the login screen at boot"})
    if manager in (None, "sddm"):
        if tree_digest(root / THEME) != staged_theme_digest():
            steps.append({"kind": "theme", "label": "Install the Bloom login screen theme"})
        try:
            dropin = (root / DROPIN).read_text()
        except OSError:
            dropin = None
        if dropin != DROPIN_TEXT:
            steps.append({"kind": "dropin", "label": "Use the Bloom theme and Hyprland on the login screen"})
    else:
        steps.append({"kind": "note", "label": f"Login screen: {manager} stays as it is (the Bloom login screen needs SDDM)"})
    network = enabled_network(root)
    if not network:
        steps.append({"kind": "enable", "unit": "NetworkManager", "label": "Turn on NetworkManager (Wi-Fi and network controls)"})
    elif "NetworkManager" not in network:
        steps.append({"kind": "note", "label": f"Network: {', '.join(network)} stays in charge; Bloom's Wi-Fi controls need NetworkManager"})
    for unit, label in zip(SERVICES, ("Turn on Bluetooth", "Turn on power profiles")):
        if not unit_enabled(root, unit):
            steps.append({"kind": "enable", "unit": unit, "label": label})
    members = group_members(root, "bloom")
    if members is None or user["name"] not in members:
        steps.append({"kind": "group", "label": f"Let {user['name']} update the login wallpaper"})
    if not (root / LOGIN).is_dir():
        steps.append({"kind": "login-folder", "label": "Create the login wallpaper folder"})
    return steps


def _replace_tree(root, temporary_parent, destination):
    staged = Path(temporary_parent) / "bloom"
    build_theme(staged)
    for path in [staged, *staged.rglob("*")]:
        os.chmod(path, 0o755 if path.is_dir() else 0o644)
    destination.parent.mkdir(parents=True, exist_ok=True)
    old = destination.with_name(destination.name + ".old")
    if old.exists():
        shutil.rmtree(old)
    if destination.exists():
        os.replace(destination, old)
    shutil.move(str(staged), destination)
    if old.exists():
        shutil.rmtree(old)


def apply(root, user, steps, booted, run, report=None):
    """Apply `steps` in order, recording each. A failure undoes this run's file
    changes and the services it enabled, then raises. Installed packages stay."""
    previous = read_manifest(root)
    doc = dict(previous) if previous and previous.get("status") != "uninstalled" else {
        "version": 1, "enabled": [], "files": {}, "sddm_installed": False, "group_created": False}
    doc.update(user=user["name"], status="applying")
    save_manifest(root, doc)
    undo = []
    try:
        for step in steps:
            kind = step["kind"]
            if kind == "packages":
                _packages(user, run)
                doc["pkgbuild_hash"] = pkgbuild_hash()
            elif kind == "install-sddm":
                run("pacman", "-S", "--noconfirm", "--needed", "sddm")
                doc["sddm_installed"] = True
            elif kind == "enable":
                unit = step["unit"]
                now = booted and unit != "sddm"
                run("systemctl", "enable", *(["--now"] if now else []), f"{unit}.service")
                undo.append(("disable", unit))
                if unit not in doc["enabled"]:
                    doc["enabled"].append(unit)
            elif kind == "theme":
                with tempfile.TemporaryDirectory(prefix="bloom-theme-", dir=_parent(root / THEME)) as temporary:
                    existed = (root / THEME).exists()
                    _replace_tree(root, temporary, root / THEME)
                if not existed:
                    undo.append(("rmtree", root / THEME))
                doc["files"][THEME] = tree_digest(root / THEME)
            elif kind == "dropin":
                path = root / DROPIN
                before = path.read_text() if path.exists() else None
                path.parent.mkdir(parents=True, exist_ok=True)
                _write(path, DROPIN_TEXT, 0o644)
                undo.append(("restore", path, before))
                doc["files"][DROPIN] = _digest_bytes(DROPIN_TEXT.encode())
            elif kind == "group":
                if group_members(root, "bloom") is None:
                    run("groupadd", "-r", "bloom")
                    doc["group_created"] = True
                run("usermod", "-aG", "bloom", user["name"])
            elif kind == "login-folder":
                folder = root / LOGIN
                folder.mkdir(parents=True, exist_ok=True)
                run("chown", "root:bloom", str(folder))
                os.chmod(folder, 0o2775)
                undo.append(("rmtree", folder))
            save_manifest(root, doc)
            if report and kind != "note":
                report(step, True)
    except BaseException as error:
        if report and step["kind"] != "note":
            report(step, False, str(error))
        for action in reversed(undo):
            try:
                if action[0] == "disable":
                    run("systemctl", "disable", f"{action[1]}.service")
                    doc["enabled"] = [u for u in doc["enabled"] if u != action[1]]
                elif action[0] == "rmtree":
                    shutil.rmtree(action[1], ignore_errors=True)
                elif action[0] == "restore":
                    if action[2] is None:
                        action[1].unlink(missing_ok=True)
                    else:
                        _write(action[1], action[2], 0o644)
            except (Failure, OSError):
                pass
        doc["files"] = {path: digest for path, digest in doc["files"].items() if (root / path).exists()}
        doc["status"] = previous.get("status", "failed") if previous else "failed"
        save_manifest(root, doc)
        raise
    doc["status"] = "complete"
    save_manifest(root, doc)


def _parent(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    return path.parent


def _write(path, text, mode):
    temporary = path.with_name(path.name + ".bloom-tmp")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    with os.fdopen(fd, "w") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def _packages(user, run):
    """makepkg refuses root: build the metapackage as the user, install as root."""
    with tempfile.TemporaryDirectory(prefix="bloom-deps-") as temporary:
        shutil.copy2(SOURCE / "packaging/bloom-shell-deps/PKGBUILD", temporary)
        run("chown", "-R", f"{user['name']}:", temporary)
        previous = os.getcwd()
        os.chdir(temporary)
        try:
            run("runuser", "-u", user["name"], "--", "makepkg", "-d", "--noconfirm")
        finally:
            os.chdir(previous)
        packages = sorted(Path(temporary).glob("bloom-shell-deps-*.pkg.tar.*"))
        if not packages:
            raise Failure("building the dependency package produced nothing")
        run("pacman", "-U", "--noconfirm", "--needed", str(packages[-1]))


def uninstall(root, remove_deps, run):
    """Undo what the manifest records. Returns plain-language lines to show."""
    doc = read_manifest(root)
    if not doc or doc.get("status") == "uninstalled":
        return []
    messages = []
    path = root / DROPIN
    if path.exists():
        if _digest_bytes(path.read_bytes()) == doc["files"].get(DROPIN):
            path.unlink()
            messages.append("Login screen theme setting removed")
        else:
            messages.append(f"Kept {path}: it was edited after Bloom wrote it")
    theme = root / THEME
    if theme.exists():
        if tree_digest(theme) == doc["files"].get(THEME):
            shutil.rmtree(theme)
        else:
            messages.append(f"Kept {theme}: it was changed after Bloom installed it")
    shutil.rmtree(root / LOGIN, ignore_errors=True)
    if "sddm" in doc.get("enabled", []):
        run("systemctl", "disable", "sddm.service")
        messages.append("SDDM disabled again (Bloom had enabled it)")
    kept = [unit for unit in doc.get("enabled", []) if unit != "sddm"]
    if kept:
        messages.append("Left enabled: " + ", ".join(kept))
    if doc.get("group_created"):
        run("groupdel", "bloom")
    if remove_deps:
        run("pacman", "-Rns", "--noconfirm", "bloom-shell-deps")
    doc["status"] = "uninstalled"
    doc["files"] = {}
    doc["enabled"] = []
    save_manifest(root, doc)
    return messages
