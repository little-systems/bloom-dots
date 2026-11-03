#!/usr/bin/env python3
"""Reversible Bloom installation. Tests use disposable homes and stub tools."""
from __future__ import annotations

import argparse
import copy
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
UNIT = "bloom-shell.service"
MARKER = "-- bloom managed loader"



class Failure(RuntimeError):
    pass


def run(*args, check=True, capture=True, cwd=None):
    try:
        result = subprocess.run(args, cwd=cwd, text=True,
                                stdout=subprocess.PIPE if capture else None,
                                stderr=subprocess.PIPE if capture else None, timeout=20 if capture else None)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise Failure(f"{args[0]}: {exc}") from exc
    if check and result.returncode:
        raise Failure(f"{' '.join(map(str, args))}: {(result.stderr or '').strip() or 'failed'}")
    return result


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def signature(path):
    if path.is_symlink():
        return "link:" + os.readlink(path)
    if path.is_file():
        return "file:" + digest(path)
    if path.exists():
        return "directory"
    return None


def remove(path):
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def duplicate(source, destination):
    if source.is_symlink():
        destination.symlink_to(os.readlink(source))
    elif source.is_dir():
        shutil.copytree(source, destination, symlinks=True)
    else:
        shutil.copy2(source, destination)


def atomic(path, text):
    fd, temporary = tempfile.mkstemp(prefix=".bloom-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_json(path, default=None):
    if not path.exists():
        return copy.deepcopy(default)
    try:
        value = json.loads(path.read_text())
    except (ValueError, OSError) as exc:
        raise Failure(f"refusing invalid JSON in {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise Failure(f"expected a JSON object in {path}")
    return value


class Context:
    def __init__(self):
        self.home = Path.home()
        self.config = Path(os.environ.get("XDG_CONFIG_HOME", self.home / ".config"))
        self.data = Path(os.environ.get("XDG_DATA_HOME", self.home / ".local/share"))
        self.state = Path(os.environ.get("XDG_STATE_HOME", self.home / ".local/state")) / "bloom"
        if not all(path.is_absolute() for path in (self.config, self.data, self.state)):
            raise Failure("XDG directory paths must be absolute")
        self.manifest_path = self.state / "install-manifest.json"
        self.manifest = read_json(self.manifest_path)
        if self.manifest and self.manifest.get("root") != str(ROOT):
            raise Failure(f"Bloom is managed from {self.manifest.get('root')}; use that checkout first")
        if self.manifest:
            self.validate_manifest(self.manifest)

    def validate_manifest(self, doc):
        if doc.get("version") != 1 or not isinstance(doc.get("entries"), list):
            raise Failure("unrecognized install manifest; no files were changed")
        for item in doc["entries"]:
            path = Path(item.get("path", ""))
            if not path.is_absolute() or not (path == self.home / ".local/bin/bloom" or any(
                    path.is_relative_to(directory) for directory in (self.config, self.data, self.state))):
                raise Failure(f"manifest destination is outside Bloom's managed directories: {path}")
            if item.get("backup") and not Path(item["backup"]).is_relative_to(self.state / "backups"):
                raise Failure("manifest backup is outside Bloom's backup directory")

    def service_state(self, unit=UNIT):
        return {"enabled": run("systemctl", "--user", "is-enabled", unit, check=False).stdout.strip() == "enabled",
                "active": run("systemctl", "--user", "is-active", unit, check=False).returncode == 0}

    def restore_service(self, state, unit=UNIT):
        run("systemctl", "--user", "daemon-reload")
        run("systemctl", "--user", "enable" if state["enabled"] else "disable", unit, check=False)
        run("systemctl", "--user", "restart" if state["active"] else "stop", unit, check=False)

    def preflight(self, no_deps=False):
        release = Path(os.environ.get("BLOOM_OS_RELEASE", "/etc/os-release")).read_text()
        if not re.search(r'^ID=["\']?arch["\']?$', release, re.M):
            raise Failure("installation currently supports Arch Linux; no files were changed")
        if os.geteuid() == 0:
            raise Failure("run Bloom as your desktop user, not root")
        for binary in ("qs", "hyprctl", "systemctl", "git") + (() if no_deps else ("makepkg",)):
            if not shutil.which(binary):
                raise Failure(f"missing {binary}; install it before running Bloom's installer")
        quickshell = run("qs", "--version").stdout
        match = re.search(r"\b(\d+)\.(\d+)", quickshell)
        if not match or tuple(map(int, match.groups())) < (0, 3):
            raise Failure("Quickshell 0.3 or newer is required")
        result = run("hyprctl", "version", "-j", check=False)
        text = result.stdout
        if result.returncode:
            text = run("Hyprland", "--version").stdout
        match = re.search(r"\b(?:v)?(\d+)\.(\d+)", text)
        if not match or tuple(map(int, match.groups())) < (0, 56):
            raise Failure("Hyprland 0.56 or newer with Lua configuration is required")
        if not (self.config / "hypr/hyprland.lua").is_file():
            raise Failure("create ~/.config/hypr/hyprland.lua before installation")
        run("systemctl", "--user", "show-environment")

    def dependencies(self):
        with tempfile.TemporaryDirectory(prefix="bloom-deps-") as temporary:
            shutil.copy2(ROOT / "packaging/bloom-shell-deps/PKGBUILD", temporary)
            run("makepkg", "-si", cwd=temporary, capture=False)

    def loader(self):
        return f"dofile({json.dumps(str(ROOT / 'hypr/bloom.lua'), ensure_ascii=False)}) {MARKER}"

    def plan(self):
        operations = [(self.config / "quickshell/bloom", "link", str(ROOT / "shell")),
                      (self.home / ".local/bin/bloom", "link", str(ROOT / "bin/bloom"))]
        operations += [(self.config / "systemd/user" / source.name, "link", str(source))
                       for source in sorted((ROOT / "systemd").glob("*.service"))]
        desktop = (ROOT / "share/applications/bloom-settings.desktop").read_text()
        desktop = re.sub(r"^Exec=.*$", f'Exec="{ROOT / "bin/bloom"}" settings', desktop, flags=re.M)
        operations.append((self.data / "applications/bloom-settings.desktop", "file", desktop))
        for source in sorted((ROOT / "share/icons").rglob("*.png")):
            operations.append((self.data / "icons" / source.relative_to(ROOT / "share/icons"), "copy", source))
        for source in sorted((ROOT / "hypr/custom").glob("*.lua")):
            operations.append((self.config / "hypr/custom" / source.name, "template", source))
        config = self.config / "hypr/hyprland.lua"
        original = config.read_text()
        lines = [line for line in original.splitlines() if not line.endswith(MARKER)]
        operations.append((config, "loader", "\n".join(lines) + "\n" + self.loader() + "\n"))
        if not (self.config / "bloom/settings.json").exists():
            operations.append((self.config / "bloom/settings.json", "config",
                               json.dumps({"bloom-enabled-modules": ["notch", "dock"]}, indent=2) + "\n"))
        return operations


class Transaction:
    def __init__(self, context, filename=None):
        self.ctx = context
        self.filename = filename or context.manifest_path
        self.previous = read_json(self.filename)
        self.doc = copy.deepcopy(self.previous) if self.previous else {
            "version": 1, "root": str(ROOT), "entries": [], "created_dirs": [],
            "service": context.service_state(), "started": time.time_ns()}
        self.entries = {item["path"]: item for item in self.doc["entries"]}
        self.changed = []
        self.temporary = tempfile.TemporaryDirectory(prefix="bloom-transaction-")

    def mkdir(self, path):
        missing = []
        while not path.exists():
            missing.append(path)
            path = path.parent
        for directory in reversed(missing):
            directory.mkdir(mode=0o700)
            self.doc["created_dirs"].append(str(directory))

    def change(self, path, kind, payload):
        path = Path(path)
        current = signature(path)
        existing = self.entries.get(str(path))
        if kind == "template" and current:
            incoming = "file:" + digest(payload)
            if current == incoming:
                return
            if not existing or current != existing["installed"]:
                # Adopt no foreign template. Offer the upstream revision beside it.
                self.change(path.with_name(path.name + ".new"), "copy", payload)
                print(f"kept customized {path}; upstream template: {path}.new")
                return
        recovering_original = (self.doc.get("status") == "installing" and existing and existing.get("backup")
                               and current == signature(Path(existing["backup"])))
        if existing and current != existing["installed"] and kind != "loader" and not recovering_original:
            raise Failure(f"{path} changed since installation; kept it untouched")
        desired = "link:" + str(payload) if kind == "link" else (
            "file:" + digest(payload) if kind in ("copy", "template") else
            "file:" + hashlib.sha256(payload.encode()).hexdigest())
        if current == desired:
            return
        if path.is_dir() and not path.is_symlink():
            raise Failure(f"refusing to replace directory {path}; move it aside first")
        self.mkdir(path.parent)
        rollback = Path(self.temporary.name) / str(len(self.changed))
        if current:
            duplicate(path, rollback)
        self.changed.append((path, rollback if current else None))
        if not existing:
            backup = None
            if current:
                backup = self.ctx.state / "backups" / str(self.doc["started"]) / str(len(self.entries))
                self.mkdir(backup.parent)
                duplicate(path, backup)
            existing = {"path": str(path), "backup": str(backup) if backup else None, "kind": kind}
            self.entries[str(path)] = existing
        # Write intent before changing the destination so a killed installer
        # still leaves ownership and its original backup on disk.
        existing["installed"] = desired
        self.doc["status"] = "installing"
        self.save()
        remove(path)
        if kind == "link":
            path.symlink_to(payload)
        elif kind in ("copy", "template"):
            shutil.copy2(payload, path)
        else:
            atomic(path, payload)
        existing["installed"] = signature(path)
        print(f"installed {path}")

    def save(self):
        self.doc["entries"] = list(self.entries.values())
        self.mkdir(self.filename.parent)
        atomic(self.filename, json.dumps(self.doc, indent=2) + "\n")

    def rollback(self):
        for path, backup in reversed(self.changed):
            remove(path)
            if backup:
                duplicate(backup, path)
        old_paths = {item["path"] for item in (self.previous or {}).get("entries", [])}
        for item in self.entries.values():
            if item.get("backup") and item["path"] not in old_paths:
                remove(Path(item["backup"]))
        if self.previous:
            atomic(self.filename, json.dumps(self.previous, indent=2) + "\n")
        else:
            self.filename.unlink(missing_ok=True)
        old_dirs = set((self.previous or {}).get("created_dirs", []))
        for directory in reversed(self.doc["created_dirs"]):
            if directory not in old_dirs:
                try:
                    Path(directory).rmdir()
                except OSError:
                    pass

    def close(self):
        self.temporary.cleanup()


def install(ctx, dry_run=False, no_deps=False, restart=False):
    ctx.preflight(no_deps)
    operations = ctx.plan()
    for path, kind, _ in operations:
        if path.is_dir() and not path.is_symlink():
            raise Failure(f"refusing to replace directory {path}; move it aside first")
        print(f"{'would install' if dry_run else 'plan'} {kind}: {path}")
    if dry_run:
        if not no_deps:
            print("would build bloom-shell-deps")
        print("would enable Bloom; existing settings and personal binds are kept")
        return
    transaction = Transaction(ctx)
    service = ctx.service_state()
    try:
        pkg_hash = digest(ROOT / "packaging/bloom-shell-deps/PKGBUILD")
        if not no_deps and transaction.doc.get("pkgbuild_hash") != pkg_hash:
            ctx.dependencies()
        for path, kind, payload in operations:
            transaction.change(path, kind, payload)
        run("systemctl", "--user", "daemon-reload")
        run("systemctl", "--user", "enable", UNIT)
        # Exclusive services remain opt-in until migration. Existing settings survive.
        run("systemctl", "--user", "restart" if restart or service["active"] else "start", UNIT)
        for _ in range(50):
            if run("qs", "-c", "bloom", "ipc", "call", "shell", "ping", check=False).stdout.strip() == "pong":
                break
            time.sleep(0.1)
        else:
            raise Failure("Bloom did not answer after starting; restoring the previous installation")
        transaction.doc["pkgbuild_hash"] = pkg_hash if not no_deps else transaction.doc.get("pkgbuild_hash")
        transaction.doc["status"] = "complete"
        transaction.save()
        print("Bloom installed. Configure enabled surfaces in Bloom Settings.")
    except BaseException:
        transaction.rollback()
        ctx.restore_service(service)
        raise
    finally:
        transaction.close()


def uninstall(ctx, remove_deps=False):
    if not ctx.manifest:
        raise Failure("no install manifest; for a development install use `bloom dev uninstall`")
    # Refuse all destructive work before stopping anything if a managed file was edited.
    for item in ctx.manifest["entries"]:
        path = Path(item["path"])
        current = signature(path)
        if current and current != item["installed"] and item["kind"] not in ("loader", "template", "config"):
            raise Failure(f"{path} was edited; back it up and remove it before uninstalling")
    run("systemctl", "--user", "disable", "--now", UNIT)
    if (ctx.state / "app-themes/manifest").exists():
        run("bash", str(ROOT / "shell/scripts/adaptive-theme.sh"), "restore", capture=False)
    for item in reversed(ctx.manifest["entries"]):
        path = Path(item["path"])
        if item["kind"] in ("template", "config") and signature(path) not in (None, item["installed"]):
            print(f"kept personal file {path}")
            continue
        if item["kind"] == "loader" and signature(path) != item["installed"]:
            atomic(path, "\n".join(line for line in path.read_text().splitlines() if not line.endswith(MARKER)) + "\n")
        else:
            remove(path)
            if item["backup"]:
                duplicate(Path(item["backup"]), path)
        if item["backup"]:
            remove(Path(item["backup"]))
    ctx.restore_service(ctx.manifest["service"])
    ctx.manifest_path.unlink()
    (ctx.state / "update.json").unlink(missing_ok=True)
    for directory in reversed(ctx.manifest["created_dirs"]):
        try:
            Path(directory).rmdir()
        except OSError:
            pass
    if remove_deps:
        run("sudo", "pacman", "-Rns", "bloom-shell-deps", capture=False)
    else:
        print("Dependencies kept. Optional removal: sudo pacman -Rns bloom-shell-deps")
    print("Bloom uninstalled; user settings and edited files are never silently deleted.")


def update(ctx, rollback=False, no_deps=False):
    if not ctx.manifest:
        raise Failure("install Bloom before updating")
    if run("git", "status", "--porcelain", cwd=ROOT).stdout.strip():
        raise Failure("checkout has local changes; keep personal overrides in ~/.config/hypr/custom")
    old = run("git", "rev-parse", "HEAD", cwd=ROOT).stdout.strip()
    branch = run("git", "symbolic-ref", "--quiet", "--short", "HEAD", cwd=ROOT, check=False).stdout.strip()
    record = ctx.state / "update.json"
    previous = read_json(record, {})
    branch = branch or previous.get("branch", "")
    if rollback and not previous:
        raise Failure("no previous update to roll back")
    atomic(record, json.dumps({"previous": old, "current": old, "branch": branch, "status": "updating"}) + "\n")
    try:
        if rollback:
            run("git", "checkout", "--detach", previous["previous"], cwd=ROOT)
        else:
            if run("git", "symbolic-ref", "--quiet", "HEAD", cwd=ROOT, check=False).returncode:
                if not branch:
                    raise Failure("detached checkout has no recorded update branch")
                run("git", "checkout", branch, cwd=ROOT)
            run("git", "pull", "--ff-only", cwd=ROOT, capture=False)
        new = run("git", "rev-parse", "HEAD", cwd=ROOT).stdout.strip()
        if new == old:
            if previous:
                atomic(record, json.dumps(previous) + "\n")
            else:
                record.unlink()
            print("Already up to date")
            return
        install(ctx, no_deps=no_deps, restart=True)
    except BaseException:
        run("git", "checkout", "--detach", old, cwd=ROOT)
        if previous:
            atomic(record, json.dumps(previous) + "\n")
        else:
            record.unlink(missing_ok=True)
        raise
    atomic(record, json.dumps({"previous": old, "current": new, "branch": branch, "status": "complete"}) + "\n")
    print(f"updated {old[:12]} -> {new[:12]}; rollback: bloom update --rollback")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    installer = commands.add_parser("install")
    installer.add_argument("--dry-run", action="store_true")
    installer.add_argument("--no-deps", action="store_true", help="dependencies are already installed")
    updater = commands.add_parser("update")
    updater.add_argument("--rollback", action="store_true")
    updater.add_argument("--no-deps", action="store_true")
    remover = commands.add_parser("uninstall")
    remover.add_argument("--remove-deps", action="store_true")
    args = parser.parse_args()
    # One lifecycle transaction per user/configuration, with no lock file left
    # in the user's configuration or installation manifest.
    config = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    key = hashlib.sha256(config.encode()).hexdigest()[:16]
    lock_dir = Path(tempfile.gettempdir()) / f"bloom-lifecycle-{os.getuid()}-{key}"
    lock_dir.mkdir(mode=0o700, exist_ok=True)
    with (lock_dir / "lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        ctx = Context()
        if args.command == "install":
            install(ctx, args.dry_run, args.no_deps)
        elif args.command == "update":
            update(ctx, args.rollback, args.no_deps)
        elif args.command == "uninstall":
            uninstall(ctx, args.remove_deps)


if __name__ == "__main__":
    try:
        main()
    except (Failure, OSError, ValueError, KeyboardInterrupt) as error:
        print(f"bloom: {error}", file=sys.stderr)
        sys.exit(1)
