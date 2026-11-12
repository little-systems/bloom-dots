#!/usr/bin/env python3
"""Reversible Bloom installation. Tests use disposable homes and stub tools."""
from __future__ import annotations

import argparse
import copy
import fcntl
import hashlib
import importlib.util
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


def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / "shell/services" / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _tool(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


events = _load("bloom_events", "bloom_events.py")
bsys = _tool("bloom_system")
UI = _tool("bloom_ui").UI
FIRST_LOGIN = "first-login-pending"
operations = _load("bloom_operations", "bloom_operations.py")
EVENTS = events.Events("lifecycle")


def run(*args, check=True, capture=True, cwd=None):
    action = Path(str(args[0])).name
    if not capture:
        # Interactive (package builds, sudo prompts): the terminal is inherited
        # and there is no deadline, but the outcome is still recorded.
        started = time.monotonic()
        try:
            result = subprocess.run(args, cwd=cwd, text=True)
        except OSError as exc:
            EVENTS.emit("operation.finished", level="warning", stage=action, outcome="failure", error="start-failed", action=action)
            raise Failure(f"{args[0]}: {exc}") from exc
        EVENTS.emit("operation.finished", level="info" if result.returncode == 0 or not check else "warning", stage=action,
                    outcome="success" if result.returncode == 0 else "failure", action=action,
                    exitCode=result.returncode, durationMs=round((time.monotonic() - started) * 1000))
    else:
        # check=False means a non-zero exit is an answer the caller handles.
        outcome = operations.run_operation("lifecycle", action, [str(a) for a in args], timeout=20, cwd=cwd,
                                           events=EVENTS, expected_failure=not check)
        if outcome["errorCode"] in ("start-failed", "timeout"):
            raise Failure(f"{args[0]}: {outcome['errorCode'].replace('-', ' ')}")
        result = subprocess.CompletedProcess(args, outcome["exitCode"] if outcome["exitCode"] is not None else -(outcome["signal"] or 1),
                                             outcome["stdout"], outcome["stderr"])
    if check and result.returncode:
        raise Failure(f"{' '.join(map(str, args))}: {(result.stderr or '').strip() or 'failed'}")
    return result


def as_root():
    return os.geteuid() == 0 or os.environ.get("BLOOM_AS_ROOT") == "1"


def require_arch():
    release = Path(os.environ.get("BLOOM_OS_RELEASE", "/etc/os-release")).read_text()
    if not re.search(r'^ID=["\']?arch["\']?$', release, re.M):
        raise Failure("installation currently supports Arch Linux; no files were changed")


def live_session():
    """The unit's own condition: a live Wayland socket and Hyprland instance."""
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    display = os.environ.get("WAYLAND_DISPLAY", "")
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not runtime or not display or not signature or "/" in signature or signature.startswith("."):
        return False
    socket_path = Path(display) if display.startswith("/") else Path(runtime) / display
    try:
        return stat.S_ISSOCK(socket_path.stat().st_mode) and \
            stat.S_ISSOCK((Path(runtime) / "hypr" / signature / ".socket.sock").stat().st_mode)
    except OSError:
        return False


def hyprland_default():
    # Hyprland writes this to ~/.config/hypr/hyprland.lua on its first start.
    return Path(os.environ.get("BLOOM_HYPR_DEFAULT_CONFIG", "/usr/share/hypr/hyprland.lua"))


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
        if getattr(self, "offline", False):
            return {"enabled": False, "active": False}
        return {"enabled": run("systemctl", "--user", "is-enabled", unit, check=False).stdout.strip() == "enabled",
                "active": run("systemctl", "--user", "is-active", unit, check=False).returncode == 0}

    def restore_service(self, state, unit=UNIT):
        if getattr(self, "offline", False):
            return
        run("systemctl", "--user", "daemon-reload")
        run("systemctl", "--user", "enable" if state["enabled"] else "disable", unit, check=False)
        run("systemctl", "--user", "restart" if state["active"] else "stop", unit, check=False)
        if self.service_state(unit) != state:
            raise Failure(f"could not restore {unit}; inspect the service state before continuing")

    def preflight(self):
        """What must hold before anything, including the system phase."""
        require_arch()
        if as_root():
            raise Failure("run Bloom as your desktop user, not root")
        for binary in ("systemctl", "git"):
            if not shutil.which(binary):
                raise Failure(f"missing {binary}; install it with pacman, then run bloom install again")

    def preflight_desktop(self):
        """After the system phase: Bloom's packages provide qs and Hyprland."""
        for binary in ("qs", "hyprctl"):
            if not shutil.which(binary):
                raise Failure(f"missing {binary}; Bloom's packages provide it, so run bloom install again "
                              "(without --no-deps) or install bloom-shell-deps")
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
        config = self.config / "hypr/hyprland.lua"
        if not config.is_file() and not hyprland_default().is_file():
            raise Failure(f"{config} does not exist and Hyprland's default configuration was not found; "
                          "start Hyprland once (it writes its default) or create that file, then install again")
        # Inside arch-chroot (or before any login) there is no user manager:
        # files are placed now and the rest finishes at the first login.
        # A chroot's systemctl "ignores" commands and still exits 0.
        self.offline = bsys.in_chroot() or run("systemctl", "--user", "show-environment", check=False).returncode != 0

    def hyprland_config(self):
        """The user's Hyprland config, or Hyprland's own default for a fresh install."""
        config = self.config / "hypr/hyprland.lua"
        return (config.read_text(), False) if config.is_file() else (hyprland_default().read_text(), True)

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
        original, self.created_hyprland_config = self.hyprland_config()
        lines = [line for line in original.splitlines() if not line.endswith(MARKER)]
        operations.append((config, "loader", "\n".join(lines) + "\n" + self.loader() + "\n"))
        if not (self.config / "bloom/settings.json").exists():
            # Beside ii, ii keeps drawing the wallpaper; otherwise Bloom draws its own.
            ii = (self.config / "quickshell/ii").exists() or (self.config / "illogical-impulse").exists()
            modules = ["notch", "dock"] if ii else ["notch", "dock", "wallpaper"]
            operations.append((self.config / "bloom/settings.json", "config",
                               json.dumps({"bloom-enabled-modules": modules}, indent=2) + "\n"))
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
        print(f"      {path}")

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


def current_user(ctx):
    import pwd
    entry = pwd.getpwuid(os.getuid())
    return {"name": entry.pw_name, "uid": entry.pw_uid, "gid": entry.pw_gid, "home": str(ctx.home)}


def show_system_plan(ui, steps, needs_password):
    ui.say("System" + ("  (asks for your password once)" if needs_password else ""))
    work = [step for step in steps if step["kind"] != "note"]
    for step in work:
        ui.item(step["label"])
    if not work:
        ui.item("Already set up")
    for step in steps:
        if step["kind"] == "note":
            ui.note(step["label"])


def show_desktop_plan(ui, session):
    ui.say("Your desktop")
    ui.item("Link Bloom into your Quickshell, Hyprland and systemd user configuration")
    ui.item("Keep your settings, personal binds and edited files")
    ui.item("Start Bloom now" if session else "Start Bloom at your first Hyprland login")


def system_runner(*args, check=True, capture=True, cwd=None):
    # Package builds and installs show their own progress.
    loud = Path(str(args[0])).name in ("pacman", "runuser")
    return run(*args, check=check, capture=capture and not loud, cwd=cwd)


def apply_system(ui, root, user, steps):
    booted = not bsys.in_chroot()

    def report(step, ok, detail=""):
        ui.step(step["label"], ok, detail)
    try:
        bsys.apply(root, user, steps, booted=booted, run=system_runner, report=report)
    except (Failure, bsys.Failure, OSError) as error:
        raise Failure(f"system setup failed ({error}); its changes were undone. "
                      "Fix the problem above, then run bloom install again") from error
    for step in steps:
        if step["kind"] == "note":
            ui.note(step["label"])
    return booted


def install(ctx, dry_run=False, no_deps=False, restart=False, yes=False, skip_system=False, ui=None):
    ui = ui or UI(yes=yes)
    if ctx.manifest and ctx.manifest.get("status") in ("uninstalling", "uninstalled"):
        raise Failure("removal is incomplete; run `bloom recover --resume` first")
    if ctx.manifest:
        ctx.verify_backups(ctx.manifest)
    ctx.preflight()
    root = bsys.system_root()
    steps = [] if skip_system else bsys.plan(root, current_user(ctx), deps=not no_deps)
    work = [step for step in steps if step["kind"] != "note"]
    total = 2
    if not skip_system:
        ui.title("Bloom will set up this machine")
        show_system_plan(ui, steps, bool(work))
        show_desktop_plan(ui, live_session())
    if dry_run:
        if shutil.which("qs") and shutil.which("hyprctl") and (
                (ctx.config / "hypr/hyprland.lua").is_file() or hyprland_default().is_file()):
            ctx.preflight_desktop()
            for path, kind, _ in ctx.plan():
                print(f"would install {kind}: {path}")
            if getattr(ctx, "created_hyprland_config", False):
                print(f"would create {ctx.config / 'hypr/hyprland.lua'} from Hyprland's default configuration "
                      "(removed again by uninstall unless you edit it)")
        else:
            print("file details are listed once Bloom's packages are installed")
        print("dry run: nothing was changed")
        return
    if not skip_system and not ui.confirm():
        raise Failure("cancelled; nothing was changed")
    if not skip_system:
        ui.stage(1, total, "System")
        if work:
            if run("sudo", "-v", check=False, capture=False).returncode:
                raise Failure("Bloom needs sudo for the system part (packages, login screen, services); "
                              "nothing was changed. Ask an administrator, or run the installer as root")
            command = ["sudo", sys.executable, str(ROOT / "tools/bloom-lifecycle.py"), "system-apply",
                       "--user", current_user(ctx)["name"]] + (["--no-deps"] if no_deps else [])
            if run(*command, check=False, capture=False).returncode:
                raise Failure("system setup failed and was undone; fix the problem above, then run bloom install again")
        else:
            ui.step("Already set up")
    ui.stage(total, total, "Your desktop")
    ctx.preflight_desktop()
    operations = ctx.plan()
    for path, kind, _ in operations:
        if path.is_dir() and not path.is_symlink():
            raise Failure(f"refusing to replace directory {path}; move it aside first")
    if getattr(ctx, "created_hyprland_config", False):
        ui.step(f"Created {ctx.config / 'hypr/hyprland.lua'} from Hyprland's default configuration",
                detail="removed again by uninstall unless you edit it")
    offline = ctx.offline
    transaction = Transaction(ctx)
    service = ctx.service_state()
    try:
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
        ui.step(f"Linked Bloom into your configuration ({len(transaction.changed)} changed)" if changed
                else "Your configuration already matches")
        marker = ctx.state / FIRST_LOGIN
        if offline:
            atomic(marker, "Bloom finishes setting up at the first Hyprland login.\n")
            ui.step("Bloom will finish at your first login")
        else:
            if changed:
                run("systemctl", "--user", "daemon-reload")
            if not service["enabled"]:
                run("systemctl", "--user", "enable", UNIT)
            marker.unlink(missing_ok=True)
        # Exclusive services remain opt-in until migration. Existing settings survive.
        # Without a Hyprland session (a console, SSH, before the first login) the
        # unit's condition skips the start: Bloom starts at the next login instead.
        session = live_session() and not offline
        ctx.verified = False
        if session:
            if restart or (service["active"] and changed):
                run("systemctl", "--user", "restart", UNIT)
            elif not service["active"]:
                run("systemctl", "--user", "start", UNIT)
            for _ in range(50):
                if run("qs", "-c", "bloom", "ipc", "call", "shell", "ping", check=False).stdout.split()[-1:] == ["pong"]:
                    break
                time.sleep(0.1)
            else:
                raise Failure("Bloom did not answer after starting; restoring the previous installation")
            ctx.verified = True
            ui.step("Bloom is running and answering")
        transaction.doc["status"] = "complete"
        if transaction.doc != transaction.previous:
            transaction.save()
        ui.say()
        if session:
            ui.say("Bloom installed. Configure enabled surfaces in Bloom Settings.")
        elif offline:
            ui.say("Bloom installed; it finishes at your first login.")
        else:
            ui.say("Bloom installed and enabled; it starts at your next Hyprland login. Run bloom doctor there to check it.")
        ui.say("Undo any time with: bloom uninstall")
    except BaseException:
        transaction.rollback()
        ctx.restore_service(service)
        raise
    finally:
        transaction.close()


def hand_over(user):
    """A checkout cloned as root inside the user's home becomes the user's,
    with any folders git created on the way."""
    home = Path(user["home"])
    if not ROOT.is_relative_to(home) or ROOT == home:
        return
    path = ROOT
    while path != home:
        if path.stat().st_uid != user["uid"]:
            if path == ROOT:
                run("chown", "-R", f"{user['uid']}:{user['gid']}", str(path))
            else:
                run("chown", f"{user['uid']}:{user['gid']}", str(path))
        path = path.parent


def root_install(args):
    """`bloom install` as root, typically inside arch-chroot after archinstall."""
    ui = UI(yes=args.yes)
    require_arch()
    root = bsys.system_root()

    def ask(users):
        return ui.menu("Install Bloom for which account?", [user["name"] for user in users])
    try:
        user = bsys.choose_user(root, args.user, ask if ui.interactive else None)
    except bsys.Failure as error:
        raise Failure(str(error)) from error
    steps = bsys.plan(root, user, deps=not args.no_deps)
    chroot = bsys.in_chroot()
    ui.title(f"Bloom will set up this machine for {user['name']}")
    show_system_plan(ui, steps, False)
    show_desktop_plan(ui, False)
    phase = ["runuser", "-u", user["name"], "--", "env", "-u", "BLOOM_AS_ROOT", "-u", "XDG_CONFIG_HOME",
             "-u", "XDG_DATA_HOME", "-u", "XDG_STATE_HOME", "-u", "XDG_RUNTIME_DIR",
             f"HOME={user['home']}", f"USER={user['name']}", f"LOGNAME={user['name']}",
             str(ROOT / "bin/bloom"), "install", "--yes", "--skip-system", "--no-deps"]
    if args.dry_run:
        print("dry run: nothing was changed")
        return
    if not ui.confirm():
        raise Failure("cancelled; nothing was changed")
    ui.stage(1, 2, "System")
    apply_system(ui, root, user, steps)
    if not [step for step in steps if step["kind"] != "note"]:
        ui.step("Already set up")
    hand_over(user)
    if run(*phase, check=False, capture=False).returncode:
        raise Failure(f"the desktop part failed for {user['name']}; the system part stays installed. "
                      f"Run bloom install again (as {user['name']} after rebooting, or here as root)")
    ui.say()
    if chroot or "install-sddm" in [step["kind"] for step in steps]:
        ui.say("Reboot next (type exit, then reboot): you'll see the Bloom login screen. "
               "Log in and Bloom finishes setting up.")
    else:
        ui.say(f"Next: log in as {user['name']} (or log out and back in) to start Bloom.")


def system_apply(args):
    if not as_root():
        raise Failure("system-apply runs as root (bloom install asks for sudo itself)")
    ui = UI(yes=True)
    root = bsys.system_root()
    try:
        user = bsys.choose_user(root, args.user, None)
    except bsys.Failure as error:
        raise Failure(str(error)) from error
    apply_system(ui, root, user, bsys.plan(root, user, deps=not args.no_deps))


def system_uninstall(args):
    if not as_root():
        raise Failure("system-uninstall runs as root (bloom uninstall asks for sudo itself)")
    ui = UI(yes=True)
    for line in bsys.uninstall(bsys.system_root(), args.remove_deps, run=system_runner):
        ui.step(line)


def first_login(ctx, start=False):
    """Finish a chroot or console install inside the first Hyprland session."""
    marker = ctx.state / FIRST_LOGIN
    if not marker.exists():
        return
    try:
        run("systemctl", "--user", "daemon-reload")
        run("systemctl", "--user", "enable", UNIT)
        if start:
            run("systemctl", "--user", "start", UNIT)
            for _ in range(50):
                if run("qs", "-c", "bloom", "ipc", "call", "shell", "ping", check=False).stdout.split()[-1:] == ["pong"]:
                    break
                time.sleep(0.1)
            else:
                raise Failure("Bloom did not answer after starting")
        marker.unlink()
    except Failure:
        run("notify-send", "-a", "Bloom", "Bloom couldn't finish setting up",
            "It tries again at your next login. To see why, open a terminal and run: bloom doctor", check=False)
        raise


def stop_and_disable():
    # Disabling a linked unit can remove its definition. Stop it while the
    # definition is still available and tolerate a missing unit on resume.
    for action in ("stop", "disable"):
        result = run("systemctl", "--user", action, UNIT, check=False)
        if result.returncode:
            state = run("systemctl", "--user", "show", UNIT, "-p", "LoadState", "--value", check=False)
            if state.stdout.strip() != "not-found":
                raise Failure(f"could not {action} {UNIT}: {result.stderr.strip() or 'systemctl failed'}")


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
        unit_path = str(ctx.config / "systemd/user" / UNIT)

        def expected_removal_state(step, current):
            if current in (step["before"], step["after"]):
                return True
            # systemctl disable can unlink our service definition before the
            # file restoration step. No other resource gets this allowance.
            return (doc["status"] == "uninstalling" and step["path"] == unit_path
                    and current is None and step["before"] == entries[unit_path]["installed"])

        # Inspect every step before stopping anything. Both sides are accepted
        # so a killed removal can resume without confusing originals with edits.
        for step in doc["removal"]:
            if step["mode"] != "keep" and not expected_removal_state(step, signature(Path(step["path"]))):
                raise Failure(f"{step['path']} changed during removal; recovery data retained")
        doc["status"] = "uninstalling"
        doc["version"] = MANIFEST_VERSION
        for item in doc["entries"]:
            item.pop("pending", None)
        atomic(ctx.manifest_path, json.dumps(doc, indent=2) + "\n")
        stop_and_disable()
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
            if not expected_removal_state(step, current):
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
    (ctx.state / FIRST_LOGIN).unlink(missing_ok=True)
    system = bsys.read_manifest(bsys.system_root())
    if system and system.get("status") != "uninstalled":
        command = ["sudo", sys.executable, str(ROOT / "tools/bloom-lifecycle.py"), "system-uninstall"]
        if run(*command, *(["--remove-deps"] if remove_deps else []), check=False, capture=False).returncode:
            raise Failure("your desktop files were restored, but the system part could not be undone; "
                          "run bloom uninstall again")
    elif remove_deps:
        run("sudo", "pacman", "-Rns", "bloom-shell-deps", capture=False)
    if not remove_deps:
        print("Packages kept. Optional removal: bloom uninstall --remove-deps")
    print("Bloom uninstalled; user settings and edited files are never silently deleted.")


def restore_interrupted_update(ctx, pending):
    """Restore the checkout recorded before the switch, then verify the shell."""
    previous, target = pending.get("previous"), pending.get("target")
    attached = pending.get("attached")
    prior = pending.get("prior")
    if (not all(isinstance(revision, str) and re.fullmatch(r"[a-f0-9]{40}|[a-f0-9]{64}", revision)
                for revision in (previous, target))
            or not isinstance(attached, str) or not isinstance(prior, dict)
            or prior.get("status") == "updating"):
        raise Failure("incomplete update record; inspect the checkout and restore the previous revision manually")
    if run("git", "status", "--porcelain", cwd=ROOT).stdout.strip():
        raise Failure("checkout has local changes; resolve them before recovering the update")
    head = run("git", "rev-parse", "HEAD", cwd=ROOT).stdout.strip()
    current_branch = run("git", "symbolic-ref", "--quiet", "HEAD", cwd=ROOT, check=False).stdout.strip()
    if head not in (previous, target) or (current_branch and current_branch != attached):
        raise Failure("checkout moved outside the interrupted update; inspect it before recovery")
    tip = None
    if attached:
        if not attached.startswith("refs/heads/"):
            raise Failure("invalid update branch")
        run("git", "check-ref-format", attached, cwd=ROOT)
        tip = run("git", "rev-parse", "--verify", attached, cwd=ROOT).stdout.strip()
        if tip not in (previous, target):
            raise Failure("update branch moved outside the interrupted update; preserving it")
    if head != previous:
        run("git", "checkout", "--detach", previous, cwd=ROOT)
    if attached and tip != previous:
        worktrees = run("git", "worktree", "list", "--porcelain", cwd=ROOT).stdout.splitlines()
        if f"branch {attached}" in worktrees:
            raise Failure("update branch is checked out in another worktree; preserving it")
        run("git", "update-ref", attached, previous, tip, cwd=ROOT)
    if attached and (head != previous or current_branch != attached):
        run("git", "checkout", attached.removeprefix("refs/heads/"), cwd=ROOT)
    install(ctx, no_deps=True, restart=True)
    restored = prior or {"previous": previous, "current": previous, "branch": pending.get("branch", ""),
                         "lastGood": pending.get("lastGood") or previous, "status": "complete"}
    atomic(ctx.state / "update.json", json.dumps(restored) + "\n")


def recover(ctx, resume=False, restore_originals=False):
    doc = ctx.manifest
    status = doc.get("status", "complete") if doc else "absent"
    print(f"Installation state: {status}")
    pending = read_json(ctx.state / "update.json", {})
    updating = pending.get("status") == "updating"
    if updating:
        print("Update state: updating")
    if not resume and not restore_originals:
        print("Recovery is read-only unless --resume or --restore-originals is selected.")
        return
    if restore_originals or status in ("uninstalling", "uninstalled"):
        uninstall(ctx)
    elif updating:
        restore_interrupted_update(ctx, pending)
        print("Interrupted update recovered.")
    elif status == "installing":
        # Recovery never performs a package transaction without a new explicit
        # install request. Existing prerequisites are still validated.
        install(ctx, no_deps=True, restart=True)
    else:
        print("No interrupted operation to resume.")


REQUIRED_FILES = ("VERSION", "bin/bloom", "shell/shell.qml", "shell/settings-app.qml", "tools/bloom-lifecycle.py",
                  "systemd/bloom-shell.service", "hypr/bloom.lua")


def validate_candidate(commit):
    """Static checks on an exported candidate before the live checkout moves."""
    with tempfile.TemporaryDirectory(prefix="bloom-candidate-") as temporary:
        archive = subprocess.run(["git", "archive", "--format=tar", commit], cwd=ROOT, capture_output=True, timeout=60)
        if archive.returncode:
            raise Failure(f"candidate {commit[:12]} could not be exported")
        subprocess.run(["tar", "-x", "-C", temporary], input=archive.stdout, check=True, timeout=60)
        tree = Path(temporary)
        problems = [f"missing {name}" for name in REQUIRED_FILES if not (tree / name).is_file()]
        if not problems and not (tree / "VERSION").read_text().strip():
            problems.append("empty VERSION")
        for script in sorted(tree.glob("tools/*.py")) + sorted(tree.glob("shell/**/*.py")):
            try:
                compile(script.read_text(), str(script.relative_to(tree)), "exec")
            except (SyntaxError, ValueError, UnicodeDecodeError) as error:
                problems.append(f"{script.relative_to(tree)}: {type(error).__name__}")
        if shutil.which("luac"):
            for lua in sorted(tree.glob("hypr/**/*.lua")):
                if subprocess.run(["luac", "-p", str(lua)], capture_output=True, timeout=10).returncode:
                    problems.append(f"{lua.relative_to(tree)}: Lua syntax")
        if problems:
            raise Failure(f"candidate {commit[:12]} failed validation ({'; '.join(problems[:5])}); nothing was changed")


def update(ctx, rollback=False, no_deps=False):
    """Validate, switch, verify health; roll back to the last good revision if needed."""
    if not ctx.manifest:
        raise Failure("install Bloom before updating")
    if run("git", "status", "--porcelain", cwd=ROOT).stdout.strip():
        raise Failure("checkout has local changes; keep personal overrides in ~/.config/hypr/custom")
    old = run("git", "rev-parse", "HEAD", cwd=ROOT).stdout.strip()
    attached = run("git", "symbolic-ref", "--quiet", "HEAD", cwd=ROOT, check=False).stdout.strip()
    branch = attached.removeprefix("refs/heads/")
    record = ctx.state / "update.json"
    previous = read_json(record, {})
    if previous.get("status") == "updating":
        raise Failure("update is incomplete; run `bloom recover --resume` first")
    branch = branch or previous.get("branch", "")
    last_good = previous.get("lastGood") or old
    if rollback and not previous:
        raise Failure("no previous update to roll back")
    if rollback:
        target = previous["previous"]
    else:
        if not branch:
            raise Failure("detached checkout has no recorded update branch")
        run("git", "fetch", cwd=ROOT, capture=False)
        upstream = "@{upstream}" if attached else f"{branch}@{{upstream}}"
        target = run("git", "rev-parse", "--verify", "--end-of-options", upstream, cwd=ROOT).stdout.strip()
        if run("git", "merge-base", "--is-ancestor", "HEAD", target, cwd=ROOT, check=False).returncode:
            raise Failure("the update is not a fast-forward of this checkout; nothing was changed")
    if target == old:
        print("Already up to date")
        return
    validate_candidate(target)
    EVENTS.emit("lifecycle.candidate", stage="validated", outcome="success", revision=target[:12])
    pending = {"previous": old, "current": old, "target": target, "attached": attached,
               "branch": branch, "lastGood": last_good, "prior": previous, "status": "updating"}
    atomic(record, json.dumps(pending) + "\n")
    try:
        if rollback:
            run("git", "checkout", "--detach", target, cwd=ROOT)
        else:
            run("git", "merge", "--ff-only", target, cwd=ROOT)
        install(ctx, no_deps=no_deps, restart=True, yes=True)
    except BaseException as error:
        EVENTS.emit("lifecycle.candidate", level="error", stage="health", outcome="rolled-back", revision=target[:12])
        try:
            restore_interrupted_update(ctx, pending)
            verdict = ("the previous version is running and answering again" if ctx.verified
                       else "the previous version was restored for the next login")
        except (Failure, OSError) as restore_error:
            verdict = f"recovery remains pending ({restore_error}); run: bloom recover --resume"
        raise Failure(f"update to {target[:12]} failed ({error}); {verdict}") from error
    verified = getattr(ctx, "verified", False)
    # Only a revision seen answering becomes last-good.
    atomic(record, json.dumps({"previous": old, "current": target, "branch": branch,
                               "lastGood": target if verified else last_good, "status": "complete"}) + "\n")
    note = "" if verified else " (not verified: no Hyprland session; it starts at your next login)"
    print(f"updated {old[:12]} -> {target[:12]}{note}; rollback: bloom update --rollback")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    installer = commands.add_parser("install")
    installer.add_argument("--dry-run", action="store_true")
    installer.add_argument("--no-deps", action="store_true", help="dependencies are already installed")
    installer.add_argument("--restart", action="store_true", help="restart even if managed files already match")
    installer.add_argument("--yes", action="store_true", help="don't ask before changing anything")
    installer.add_argument("--user", help="the account to install for (when run as root)")
    installer.add_argument("--skip-system", action="store_true", help=argparse.SUPPRESS)
    applier = commands.add_parser("system-apply")
    applier.add_argument("--user", required=True)
    applier.add_argument("--no-deps", action="store_true")
    system_remover = commands.add_parser("system-uninstall")
    system_remover.add_argument("--remove-deps", action="store_true")
    finisher = commands.add_parser("first-login")
    finisher.add_argument("--start", action="store_true")
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
    if args.command == "system-apply":
        return system_apply(args)
    if args.command == "system-uninstall":
        return system_uninstall(args)
    if as_root():
        if args.command != "install":
            raise Failure(f"run bloom {args.command} as your desktop user; it asks for sudo when it needs it")
        return root_install(args)
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
        # A dry run and a plain recovery inspection are queries: no effects, no log.
        EVENTS.enabled = not (getattr(args, "dry_run", False) or
                              (args.command == "recover" and not (args.resume or args.restore_originals)))
        EVENTS.emit("lifecycle.started", stage=args.command)
        if args.command == "install":
            install(ctx, args.dry_run, args.no_deps, args.restart, args.yes, args.skip_system)
        elif args.command == "first-login":
            first_login(ctx, args.start)
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
        EVENTS.emit("lifecycle.failed", level="error", outcome="failure", error=type(error).__name__,
                    reason=str(error))
        print(f"bloom: {error}", file=sys.stderr)
        sys.exit(1)
    EVENTS.emit("lifecycle.finished", outcome="success")
