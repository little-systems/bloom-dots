#!/usr/bin/env python3
"""Owned application theme files: install, record and restore.

Renderers write into a staging tree laid out like a home directory; `commit`
installs each staged file only where Bloom still owns the target. A target is
owned when Bloom has not touched it yet (its original is backed up first) or its
content still matches what Bloom last wrote. Anything else - an owner edit, a
deletion or a symlink - is a conflict: the owner's file is left alone and
reported. `restore` puts originals back under the same rule. A fingerprint is
recorded before each write, so a crash between the write and the ledger update
is not mistaken for an owner edit.

Exit status: 0 done, 3 done with conflicts (listed on stdout), 2 refused.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

import importlib.util as _importlib_util
_retention_spec = _importlib_util.spec_from_file_location("bloom_retention", Path(__file__).resolve().parent.parent / "services/bloom_retention.py")
retention = _importlib_util.module_from_spec(_retention_spec)
_retention_spec.loader.exec_module(retention)

TARGETS = (
    ".config/gtk-3.0/gtk.css",
    ".config/gtk-4.0/gtk.css",
    ".config/gtk-3.0/settings.ini",
    ".config/gtk-4.0/settings.ini",
    ".config/fuzzel/fuzzel_theme.ini",
    ".config/hypr/hyprland/colors.lua",
    ".config/kdeglobals",
    ".local/state/quickshell/user/generated/terminal/kitty-theme.conf",
    ".local/share/color-schemes/BloomAdaptive.colors",
    ".local/share/color-schemes/BloomAdaptiveA.colors",
    ".local/share/color-schemes/BloomAdaptiveB.colors",
)
GSETTINGS_KEYS = ("color-scheme", "gtk-theme")
SCHEMA = "org.gnome.desktop.interface"


class Refused(Exception):
    pass


def env_path(name, fallback):
    value = os.environ.get(name)
    return Path(value) if value else fallback


def bloom_state():
    home = Path(os.environ.get("HOME") or Path.home())
    return env_path("XDG_STATE_HOME", home / ".local/state") / "bloom/app-themes"


def target_path(rel):
    # BLOOM_THEME_HOME is a whole virtual home; otherwise follow the XDG roots.
    override = os.environ.get("BLOOM_THEME_HOME")
    home = Path(override or os.environ.get("HOME") or Path.home())
    for prefix, var in ((".config/", "XDG_CONFIG_HOME"), (".local/share/", "XDG_DATA_HOME"),
                        (".local/state/", "XDG_STATE_HOME")):
        if rel.startswith(prefix):
            root = home / prefix.rstrip("/") if override else env_path(var, home / prefix.rstrip("/"))
            return root / rel[len(prefix):]
    raise Refused(f"{rel} is not a theme target")


def fingerprint(path):
    if path.is_symlink() or not path.exists():
        return None
    if not path.is_file():
        return "not-a-file"
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sync_dir(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_write(path, data, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    retention.prune_stale(path.parent, (f".{path.name}.bloom-*",))
    temporary = path.with_name(f".{path.name}.bloom-{os.getpid()}")
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    except BaseException:
        temporary.unlink(missing_ok=True)
        raise
    sync_dir(path.parent)


class Ledger:
    def __init__(self):
        self.dir = bloom_state()
        self.path = self.dir / "ownership.json"
        self.doc = {"version": 1, "targets": {}, "gsettings": {}}

    def load(self):
        if self.path.exists():
            doc = json.loads(self.path.read_text())
            if doc.get("version") != 1 or not isinstance(doc.get("targets"), dict):
                raise Refused(f"{self.path} has an unknown format; nothing was changed")
            doc.setdefault("gsettings", {})
            self.doc = doc
        elif (self.dir / "manifest").exists():
            self._adopt_legacy()
        return self

    def _adopt_legacy(self):
        # The earlier script kept bare backups and a list of files that existed.
        # It recorded no fingerprints, so Bloom's last writes cannot be verified.
        listed = set((self.dir / "manifest").read_text().split())
        for rel in TARGETS:
            backup = self.dir / rel
            if rel in listed and backup.is_file():
                original = self.dir / "originals" / rel
                original.parent.mkdir(parents=True, exist_ok=True)
                os.replace(backup, original)
                self.doc["targets"][rel] = {"original": True, "written": None, "pending": None, "legacy": True}
            else:
                self.doc["targets"][rel] = {"original": False, "written": None, "pending": None, "legacy": True}
        for key in GSETTINGS_KEYS:
            saved = self.dir / f"gnome-{key}"
            if saved.is_file() and saved.read_text().strip():
                self.doc["gsettings"][key] = {"original": saved.read_text().strip(), "written": None}
        self.save()
        (self.dir / "manifest").unlink()
        for key in GSETTINGS_KEYS:
            (self.dir / f"gnome-{key}").unlink(missing_ok=True)

    def save(self):
        self.dir.mkdir(parents=True, exist_ok=True)
        os.chmod(self.dir, 0o700)
        if not self.doc["targets"] and not self.doc["gsettings"]:
            self.path.unlink(missing_ok=True)
            return
        atomic_write(self.path, (json.dumps(self.doc, indent=2, sort_keys=True) + "\n").encode(), 0o600)

    def original(self, rel):
        return self.dir / "originals" / rel

    def keep(self, path, rel):
        # Anything Bloom cannot safely put back stays recoverable here.
        kept = self.dir / "kept" / time.strftime("%Y%m%d-%H%M%S") / rel
        kept.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), kept)
        return kept


def owned(entry, current):
    # No fingerprint yet: Bloom has not written it, or a legacy backup predates them.
    if entry["written"] is None:
        return True
    return current is not None and current in (entry["written"], entry.get("pending"))


def staged_files(stage):
    files = []
    for path in sorted(stage.rglob("*")):
        if path.is_symlink():
            raise Refused(f"staged {path} is a symlink")
        if path.is_file():
            rel = path.relative_to(stage).as_posix()
            if rel not in TARGETS:
                raise Refused(f"staged {rel} is not a theme target")
            files.append(rel)
    return files


def commit(stage):
    ledger = Ledger().load()
    targets = ledger.doc["targets"]
    conflicts = []
    for rel in staged_files(stage):
        path = target_path(rel)
        data = (stage / rel).read_bytes()
        new = hashlib.sha256(data).hexdigest()
        current = fingerprint(path)
        if path.is_symlink() or current == "not-a-file":
            conflicts.append(f"{rel}: not a regular file; left alone")
            continue
        entry = targets.get(rel)
        if entry is not None and entry.get("legacy") and not entry["original"] and current is not None:
            # Not in the old backup list: whoever created it, keep today's copy.
            entry = None
        if entry is None:
            entry = {"original": current is not None, "written": None, "pending": None}
            if current is not None:
                backup = ledger.original(rel)
                atomic_write(backup, path.read_bytes(), 0o600)
            targets[rel] = entry
        elif entry["written"] is not None and not owned(entry, current):
            conflicts.append(f"{rel}: {'deleted' if current is None else 'edited'} after Bloom themed it; left alone")
            continue
        if current == new:
            entry.update(written=new, pending=None)
            ledger.save()
            continue
        entry["pending"] = new
        ledger.save()
        mode = path.stat().st_mode & 0o777 if current is not None else 0o644
        atomic_write(path, data, mode)
        if os.environ.get("BLOOM_THEME_CUT") == f"written:{rel}":
            os._exit(137)
        entry.update(written=new, pending=None)
        entry.pop("legacy", None)
        ledger.save()
    return conflicts


def gsettings(*args):
    return subprocess.run(["gsettings", *args], text=True, capture_output=True, timeout=5)


def unquote(value):
    return value.strip().strip("'\"")


def set_desktop(key, value):
    if key not in GSETTINGS_KEYS:
        raise Refused(f"{key} is not a desktop theme key")
    if shutil.which("gsettings") is None:
        return []
    ledger = Ledger().load()
    entries = ledger.doc["gsettings"]
    current = gsettings("get", SCHEMA, key).stdout.strip()
    entry = entries.get(key)
    if entry is None:
        entries[key] = entry = {"original": current, "written": None}
    elif entry["written"] is not None and unquote(current) != unquote(entry["written"]):
        return [f"{key}: changed after Bloom set it; left alone"]
    entry["written"] = value
    ledger.save()
    gsettings("set", SCHEMA, key, value)
    return []


def restore():
    ledger = Ledger().load()
    targets = ledger.doc["targets"]
    conflicts = []
    for rel in sorted(targets):
        entry = targets[rel]
        path = target_path(rel)
        current = fingerprint(path)
        original = ledger.original(rel)
        if path.is_symlink() or current == "not-a-file":
            conflicts.append(f"{rel}: not a regular file; left alone")
        elif entry.get("legacy") and not entry["original"]:
            if current is not None:
                conflicts.append(f"{rel}: predates Bloom's ownership records; left in place")
        elif owned(entry, current):
            if entry["original"]:
                atomic_write(path, original.read_bytes(), original.stat().st_mode & 0o777 or 0o644)
            elif current is not None:
                path.unlink()
                sync_dir(path.parent)
        else:
            what = "deleted" if current is None else "edited"
            conflicts.append(f"{rel}: {what} after Bloom themed it; left alone")
            if entry["original"]:
                kept = ledger.keep(original, rel)
                conflicts[-1] += f" (pre-Bloom copy kept at {kept})"
        original.unlink(missing_ok=True)
        del targets[rel]
        ledger.save()
    if shutil.which("gsettings") is not None:
        for key in sorted(ledger.doc["gsettings"]):
            entry = ledger.doc["gsettings"][key]
            current = gsettings("get", SCHEMA, key).stdout.strip()
            if entry["written"] is None or unquote(current) == unquote(entry["written"]):
                gsettings("set", SCHEMA, key, entry["original"])
            else:
                conflicts.append(f"{key}: changed after Bloom set it; left alone")
            del ledger.doc["gsettings"][key]
            ledger.save()
    ledger.doc["gsettings"] = {}
    ledger.save()
    originals = ledger.dir / "originals"
    if originals.exists():
        for directory in sorted(originals.rglob("*"), reverse=True):
            if directory.is_dir() and not any(directory.iterdir()):
                directory.rmdir()
        if not any(originals.iterdir()):
            originals.rmdir()
    return conflicts


def seed(stage):
    for rel in TARGETS:
        path = target_path(rel)
        if path.is_file() and not path.is_symlink():
            (stage / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, stage / rel)
    return []


def main(argv):
    commands = {"commit": (1, lambda a: commit(Path(a[0]))), "seed": (1, lambda a: seed(Path(a[0]))),
                "restore": (0, lambda a: restore()), "gsettings": (2, lambda a: set_desktop(*a))}
    if not argv or argv[0] not in commands or len(argv) - 1 != commands[argv[0]][0]:
        print("usage: theme-owner.py commit STAGE | seed STAGE | restore | gsettings KEY VALUE", file=sys.stderr)
        return 2
    state = bloom_state()
    state.mkdir(parents=True, exist_ok=True)
    os.chmod(state, 0o700)
    with open(state / ".lock", "a") as lock:
        # adaptive-theme.sh already holds this lock for its whole run.
        if os.environ.get("BLOOM_THEME_LOCKED") != "1":
            fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            # Staging trees from a killed run; the lock holder's own is fresh.
            retention.prune_stale(state, (".stage-*",))
            conflicts = commands[argv[0]][1](argv[1:])
        except Refused as error:
            print(f"bloom theme: {error}", file=sys.stderr)
            return 2
    for line in conflicts:
        print(f"conflict {line}")
    return 3 if conflicts else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
