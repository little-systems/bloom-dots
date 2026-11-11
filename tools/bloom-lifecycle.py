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
import stat
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
UNIT = "bloom-shell.service"
MARKER = "-- bloom managed loader"
MANIFEST_VERSION = 2



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
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_directory(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def place(path, kind, payload):
    """Replace a file or link without first removing the previous destination."""
    fd, staging = tempfile.mkstemp(prefix=".bloom-", dir=path.parent)
    os.close(fd)
    staging = Path(staging)
    try:
        if kind == "link":
            staging.unlink()
            staging.symlink_to(payload)
        elif kind in ("copy", "template"):
            shutil.copy2(payload, staging)
            with staging.open("rb") as stream:
                os.fsync(stream.fileno())
        else:
            if path.is_file() and not path.is_symlink():
                staging.chmod(stat.S_IMODE(path.stat().st_mode))
            with staging.open("w") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
        os.replace(staging, path)
        sync_directory(path.parent)
    finally:
        staging.unlink(missing_ok=True)


def restore(path, backup):
    if backup is None:
        path.unlink(missing_ok=True)
        if path.parent.exists():
            sync_directory(path.parent)
    elif backup.is_symlink():
        path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        place(path, "link", os.readlink(backup))
    else:
        path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        place(path, "copy", backup)


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
        if self.manifest is not None and self.manifest.get("root") != str(ROOT):
            raise Failure(f"Bloom is managed from {self.manifest.get('root')}; use that checkout first")
        if self.manifest is not None:
            self.validate_manifest(self.manifest, managed=True)

    def validate_manifest(self, doc, managed=False):
        if type(doc.get("version")) is not int or doc["version"] not in (1, MANIFEST_VERSION) or not isinstance(doc.get("entries"), list):
            raise Failure("unrecognized install manifest; no files were changed")
        if doc.get("status") not in (None, "installing", "complete", "uninstalling", "uninstalled"):
            raise Failure("invalid lifecycle status")

        def fingerprint(value):
            return value is None or (isinstance(value, str) and re.fullmatch(r"(?:file:[0-9a-f]{64}|link:.+)", value))
        def within(path, roots):
            return (path.is_absolute() and ".." not in path.parts and any(
                path.is_relative_to(root) and path.parent.resolve().is_relative_to(root.resolve())
                for root in roots))

        allowed = {
            str(self.config / "quickshell/bloom"): {"link"},
            str(self.home / ".local/bin/bloom"): {"link"},
            str(self.data / "applications/bloom-settings.desktop"): {"file"},
            str(self.config / "hypr/hyprland.lua"): {"loader"},
            str(self.config / "bloom/settings.json"): {"config"},
        }
        for source in (ROOT / "systemd").glob("*.service"):
            allowed[str(self.config / "systemd/user" / source.name)] = {"link"}
        for source in (ROOT / "share/icons").rglob("*.png"):
            allowed[str(self.data / "icons" / source.relative_to(ROOT / "share/icons"))] = {"copy"}
        for source in (ROOT / "hypr/custom").glob("*.lua"):
            path = self.config / "hypr/custom" / source.name
            allowed[str(path)] = {"template"}
            allowed[str(path) + ".new"] = {"copy"}
        seen = set()
        for item in doc["entries"]:
            if not isinstance(item, dict) or not isinstance(item.get("path"), str):
                raise Failure("invalid manifest entry")
            path = Path(item["path"])
            roots = (self.config, self.data, self.state, self.home / ".local/bin")
            if not within(path, roots):
                raise Failure(f"manifest destination is outside Bloom's managed directories: {path}")
            if str(path) in seen:
                raise Failure(f"duplicate manifest destination: {path}")
            seen.add(str(path))
            if item.get("kind") not in {"link", "copy", "template", "loader", "config", "file"}:
                raise Failure("invalid manifest operation kind")
            if managed and item["kind"] not in allowed.get(str(path), set()):
                raise Failure(f"manifest destination is not an owned Bloom resource: {path}")
            installed = item.get("installed")
            if installed is None or not fingerprint(installed):
                raise Failure("invalid manifest fingerprint")
            if not fingerprint(item.get("original")):
                raise Failure("invalid original fingerprint")
            backup = item.get("backup")
            if backup is not None and (not isinstance(backup, str) or not within(Path(backup), (self.state / "backups",))):
                raise Failure("manifest backup is outside Bloom's backup directory")
            if "pending" in item and (not isinstance(item["pending"], dict) or "before" not in item["pending"]
                                      or not fingerprint(item["pending"]["before"]) or doc.get("status") != "installing"):
                raise Failure("invalid pending manifest step")
        if not isinstance(doc.get("service"), dict) or any(type(doc["service"].get(k)) is not bool for k in ("enabled", "active")):
            raise Failure("invalid original service state")
        dirs = doc.get("created_dirs")
        if not isinstance(dirs, list):
            raise Failure("invalid created-directory ledger")
        parents = {str(parent) for raw in seen for parent in Path(raw).parents if parent not in (self.home, Path('/'))}
        for item in doc["entries"]:
            if item.get("backup"):
                parents.update(str(p) for p in Path(item["backup"]).parents if p not in (self.home, Path('/')))
        parents.update(str(p) for p in self.manifest_path.parents if p not in (self.home, Path('/')))
        if any(not isinstance(p, str) or ".." in Path(p).parts or (
                p not in parents and not (not managed and within(Path(p), (self.state / "backups",)))) for p in dirs):
            raise Failure("invalid created-directory destination")
        removal = doc.get("removal")
        if (removal is not None) != (doc.get("status") in ("uninstalling", "uninstalled")):
            raise Failure("inconsistent removal journal status")
        if removal is not None:
            if not isinstance(removal, list) or len(removal) != len(doc["entries"]):
                raise Failure("invalid removal journal")
            if {s.get("path") for s in removal if isinstance(s, dict)} != seen:
                raise Failure("invalid removal destinations")
            for step in removal:
                if not isinstance(step, dict) or step.get("mode") not in ("keep", "restore", "loader"):
                    raise Failure("invalid removal step")
                for key in ("before", "after"):
                    value = step.get(key)
                    if not fingerprint(value):
                        raise Failure("invalid removal fingerprint")
                if step["mode"] == "loader" and not isinstance(step.get("text"), str):
                    raise Failure("invalid loader removal step")
                entry = next(e for e in doc["entries"] if e["path"] == step["path"])
                if step["mode"] == "loader":
                    if entry["kind"] != "loader" or step["after"] != "file:" + hashlib.sha256(step["text"].encode()).hexdigest():
                        raise Failure("invalid loader removal contents")
                if step["mode"] == "keep" and entry["kind"] not in ("template", "config"):
                    raise Failure("invalid retained resource")

    def verify_backups(self, doc):
        for item in doc["entries"]:
            if not item.get("backup"):
                continue
            backup = Path(item["backup"])
            actual = signature(backup)
            if actual is None or actual == "directory":
                raise Failure(f"original backup unavailable: {backup}; no files were changed")
            if item.get("original") and actual != item["original"]:
                raise Failure(f"original backup failed verification: {backup}; no files were changed")

    def service_state(self, unit=UNIT):
        return {"enabled": run("systemctl", "--user", "is-enabled", unit, check=False).stdout.strip() == "enabled",
                "active": run("systemctl", "--user", "is-active", unit, check=False).returncode == 0}

    def restore_service(self, state, unit=UNIT):
        run("systemctl", "--user", "daemon-reload")
        run("systemctl", "--user", "enable" if state["enabled"] else "disable", unit, check=False)
        run("systemctl", "--user", "restart" if state["active"] else "stop", unit, check=False)
        if self.service_state(unit) != state:
            raise Failure(f"could not restore {unit}; inspect the service state before continuing")

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
            "version": MANIFEST_VERSION, "root": str(ROOT), "entries": [], "created_dirs": [],
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
            sync_directory(directory.parent)
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
        pending = existing.get("pending") if existing else None
        recovering_original = (self.doc.get("status") == "installing" and existing and (
            (pending is not None and current == pending["before"]) or
            (existing.get("backup") and current == signature(Path(existing["backup"]))) or
            (pending is None and current is None)))
        if existing and current != existing["installed"] and kind != "loader" and not recovering_original:
            raise Failure(f"{path} changed since installation; kept it untouched")
        desired = "link:" + str(payload) if kind == "link" else (
            "file:" + digest(payload) if kind in ("copy", "template") else
            "file:" + hashlib.sha256(payload.encode()).hexdigest())
        if current == desired:
            if existing and "pending" in existing:
                existing.pop("pending")
                self.save()
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
                if not backup.is_symlink():
                    with backup.open("rb") as stream:
                        os.fsync(stream.fileno())
                sync_directory(backup.parent)
            existing = {"path": str(path), "backup": str(backup) if backup else None,
                        "original": current, "kind": kind}
            self.entries[str(path)] = existing
        # Write intent before changing the destination so a killed installer
        # still leaves ownership and its original backup on disk.
        existing["installed"] = desired
        existing["pending"] = {"before": current}
        self.doc["status"] = "installing"
        self.doc["version"] = MANIFEST_VERSION
        self.save()
        place(path, kind, payload)
        existing["installed"] = signature(path)
        existing.pop("pending", None)
        print(f"installed {path}")

    def save(self):
        self.doc["entries"] = list(self.entries.values())
        self.mkdir(self.filename.parent)
        atomic(self.filename, json.dumps(self.doc, indent=2) + "\n")

    def rollback(self):
        for path, backup in reversed(self.changed):
            restore(path, backup)
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
    if ctx.manifest and ctx.manifest.get("status") in ("uninstalling", "uninstalled"):
        raise Failure("removal is incomplete; run `bloom recover --resume` first")
    if ctx.manifest:
        ctx.verify_backups(ctx.manifest)
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
        # A resumed step can disappear from the fresh plan (for example the
        # first-run settings file now exists), or a template can already match.
        # Settle every persisted intent, not only paths visited by this plan.
        for item in transaction.entries.values():
            if "pending" in item:
                if signature(Path(item["path"])) != item["installed"]:
                    raise Failure(f"unfinished step for {item['path']}; inspect recovery state before proceeding")
                item.pop("pending")
        changed = bool(transaction.changed)
        if changed:
            run("systemctl", "--user", "daemon-reload")
        if not service["enabled"]:
            run("systemctl", "--user", "enable", UNIT)
        # Exclusive services remain opt-in until migration. Existing settings survive.
        if restart or (service["active"] and changed):
            run("systemctl", "--user", "restart", UNIT)
        elif not service["active"]:
            run("systemctl", "--user", "start", UNIT)
        for _ in range(50):
            if run("qs", "-c", "bloom", "ipc", "call", "shell", "ping", check=False).stdout.strip() == "pong":
                break
            time.sleep(0.1)
        else:
            raise Failure("Bloom did not answer after starting; restoring the previous installation")
        transaction.doc["pkgbuild_hash"] = pkg_hash if not no_deps else transaction.doc.get("pkgbuild_hash")
        transaction.doc["status"] = "complete"
        if transaction.doc != transaction.previous:
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
        print("No managed installation to remove; development links were left untouched.")
        return
    doc = ctx.manifest
    entries = {item["path"]: item for item in doc["entries"]}
    if doc.get("status") != "uninstalled":
        ctx.verify_backups(doc)
        if "removal" not in doc:
            steps = []
            for item in reversed(doc["entries"]):
                path = Path(item["path"])
                current = signature(path)
                mode, text = "restore", None
                after = signature(Path(item["backup"])) if item["backup"] else None
                if item["kind"] in ("template", "config") and current not in (None, item["installed"]):
                    mode, after = "keep", current
                elif item["kind"] == "loader" and current not in (None, item["installed"]):
                    if path.is_symlink():
                        raise Failure(f"{path} became a symlink; resolve it before removal")
                    mode = "loader"
                    text = "\n".join(line for line in path.read_text().splitlines() if not line.endswith(MARKER)) + "\n"
                    after = "file:" + hashlib.sha256(text.encode()).hexdigest()
                elif current and current != item["installed"]:
                    pending = item.get("pending")
                    if not (doc.get("status") == "installing" and pending and current == pending["before"]):
                        raise Failure(f"{path} was edited; resolve it before uninstalling")
                step = {"path": str(path), "before": current, "after": after, "mode": mode}
                if text is not None:
                    step["text"] = text
                steps.append(step)
            doc["removal"] = steps
        # Inspect every step before stopping anything. Both sides are accepted
        # so a killed removal can resume without confusing originals with edits.
        for step in doc["removal"]:
            if step["mode"] != "keep" and signature(Path(step["path"])) not in (step["before"], step["after"]):
                raise Failure(f"{step['path']} changed during removal; recovery data retained")
        doc["status"] = "uninstalling"
        doc["version"] = MANIFEST_VERSION
        for item in doc["entries"]:
            item.pop("pending", None)
        atomic(ctx.manifest_path, json.dumps(doc, indent=2) + "\n")
        run("systemctl", "--user", "disable", "--now", UNIT)
        themes = ctx.state / "app-themes"
        if (themes / "manifest").exists() or (themes / "ownership.json").exists():
            # 3: restored, but files edited after Bloom themed them were kept (listed).
            restored = run("bash", str(ROOT / "shell/scripts/adaptive-theme.sh"), "restore", check=False, capture=False)
            if restored.returncode not in (0, 3):
                raise Failure("application themes could not be restored; recovery data retained")
        for step in doc["removal"]:
            path = Path(step["path"])
            if step["mode"] == "keep":
                print(f"kept personal file {path}")
                continue
            current = signature(path)
            if current == step["after"]:
                continue
            if current != step["before"]:
                raise Failure(f"{path} changed during removal; recovery data retained")
            if step["mode"] == "loader":
                place(path, "file", step["text"])
            else:
                item = entries[str(path)]
                restore(path, Path(item["backup"]) if item["backup"] else None)
            if signature(path) != step["after"]:
                raise Failure(f"{path}: restoration verification failed")
        ctx.restore_service(doc["service"])
        doc["status"] = "uninstalled"
        atomic(ctx.manifest_path, json.dumps(doc, indent=2) + "\n")
    # Recovery data is retained until all destinations and service restoration
    # have completed, rather than consumed halfway through the operation.
    for item in doc["entries"]:
        if item.get("backup"):
            remove(Path(item["backup"]))
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


def recover(ctx, resume=False, restore_originals=False):
    doc = ctx.manifest
    status = doc.get("status", "complete") if doc else "absent"
    print(f"Installation state: {status}")
    if not resume and not restore_originals:
        print("Recovery is read-only unless --resume or --restore-originals is selected.")
        return
    if restore_originals or status in ("uninstalling", "uninstalled"):
        uninstall(ctx)
    elif status == "installing":
        # Recovery never performs a package transaction without a new explicit
        # install request. Existing prerequisites are still validated.
        install(ctx, no_deps=True, restart=True)
    else:
        print("No interrupted operation to resume.")


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
    installer.add_argument("--restart", action="store_true", help="restart even if managed files already match")
    updater = commands.add_parser("update")
    updater.add_argument("--rollback", action="store_true")
    updater.add_argument("--no-deps", action="store_true")
    remover = commands.add_parser("uninstall")
    remover.add_argument("--remove-deps", action="store_true")
    recovery = commands.add_parser("recover")
    selection = recovery.add_mutually_exclusive_group()
    selection.add_argument("--resume", action="store_true")
    selection.add_argument("--restore-originals", action="store_true")
    args = parser.parse_args()
    # One lifecycle transaction per user/configuration, with no lock file left
    # in the user's configuration or installation manifest.
    config = os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))
    key = hashlib.sha256(str(Path(config).resolve()).encode()).hexdigest()[:16]
    lock_dir = Path(tempfile.gettempdir()) / f"bloom-lifecycle-{os.getuid()}-{key}"
    lock_dir.mkdir(mode=0o700, exist_ok=True)
    info = lock_dir.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise Failure("unsafe lifecycle lock directory; no installation changes were made")
    fd = os.open(lock_dir / "lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    with os.fdopen(fd, "a") as lock:
        info = os.fstat(lock.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise Failure("unsafe lifecycle lock file")
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise Failure("another Bloom lifecycle operation is running; try again when it finishes") from exc
        ctx = Context()
        if args.command == "install":
            install(ctx, args.dry_run, args.no_deps, args.restart)
        elif args.command == "update":
            update(ctx, args.rollback, args.no_deps)
        elif args.command == "uninstall":
            uninstall(ctx, args.remove_deps)
        elif args.command == "recover":
            recover(ctx, args.resume, args.restore_originals)


if __name__ == "__main__":
    try:
        main()
    except (Failure, OSError, ValueError, KeyboardInterrupt) as error:
        print(f"bloom: {error}", file=sys.stderr)
        sys.exit(1)
