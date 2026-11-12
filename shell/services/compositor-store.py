#!/usr/bin/env python3
"""Owned compositor preferences: one atomic Lua + embedded state document.

The old JSON file is a read-only migration input. Read never creates a file or
repairs anything; commit is the explicit mutation. All paths are fixed to XDG
Bloom resources. No shell/compositor command is executed by this module.
"""
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import sys
import tempfile
import time

import importlib.util as _importlib_util
_retention_spec = _importlib_util.spec_from_file_location("bloom_retention", Path(__file__).resolve().with_name("bloom_retention.py"))
retention = _importlib_util.module_from_spec(_retention_spec)
_retention_spec.loader.exec_module(retention)

LIMIT = 1024 * 1024
INSTALLER_TEMPLATE = b"-- Written by Bloom Settings. Personal overrides belong in bloom.lua.\n"
HEADER = "-- Written by Bloom Settings. Delete this file to undo everything in it."
MARKER = "-- bloom-state-v1 "
RULE = 'hl.layer_rule({ match = { namespace = "^bloom:(notch|dock|osd-left|osd-right|launcher|session|cheatsheet|overview|polkit|wallpaper-picker|osk)$" }, blur = true, ignore_alpha = 0.2 })'
MONITOR = re.compile(r'hl\.monitor\(\{ output = "[A-Za-z0-9._-]+", mode = "(?:[0-9]+x[0-9]+@[0-9]+(?:\.[0-9]+)?|preferred)", position = "-?[0-9]+x-?[0-9]+", scale = ([0-9]+(?:\.[0-9]+)?)(?:, transform = [0-7])? \}\)')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def decode(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate preference key")
            result[key] = value
        return result
    def finite(_):
        raise ValueError("non-finite preference")
    value = json.loads(data, object_pairs_hook=unique, parse_constant=finite)
    if not isinstance(value, dict):
        raise ValueError("preferences must be an object")
    return value


def read_file(path, maximum=LIMIT):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        return None
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if info.st_uid != os.getuid() or not stat.S_ISREG(info.st_mode):
            raise ValueError("preference target is not an owned regular file")
        data = stream.read(maximum + 1)
    if len(data) > maximum:
        raise ValueError("preferences exceed size limit")
    return data


def lua(value, depth=0):
    if depth > 8:
        raise ValueError("preference nesting too deep")
    if isinstance(value, dict):
        if any(not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key) for key in value):
            raise ValueError("invalid compositor option name")
        return "{ " + ", ".join(key + " = " + lua(item, depth + 1) for key, item in value.items()) + " }"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int) and abs(value) > 9007199254740991:
        raise ValueError("compositor number exceeds exact range")
    if isinstance(value, (int, float)) and math.isfinite(value):
        return str(int(value)) if int(value) == value else repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    raise ValueError("unsupported compositor option value")


def validate(state):
    if not isinstance(state, dict):
        raise ValueError("invalid compositor state")
    state = {"hypr": {}, "monitors": [], "rules": [RULE], **state}
    if not isinstance(state["hypr"], dict):
        raise ValueError("invalid compositor overrides")
    lua(state["hypr"])
    if not isinstance(state["monitors"], list) or not isinstance(state["rules"], list):
        raise ValueError("invalid compositor rules")
    for line in state["monitors"]:
        match = MONITOR.fullmatch(line) if isinstance(line, str) else None
        if match is None or not 0.25 <= float(match[1]) <= 4:
            raise ValueError("unsupported monitor preference; original retained")
    if any(line != RULE for line in state["rules"]):
        raise ValueError("unrecognized layer rule; original retained")
    return state


def legacy_source(state):
    lines = [HEADER]
    if state["hypr"]:
        lines.append("hl.config(" + lua(state["hypr"]) + ")")
    return ("\n".join(lines + state["monitors"] + state["rules"]) + "\n").encode()


def encode(state, previous):
    record = json.dumps({"version": 1, "state": state, "previous": previous}, ensure_ascii=False, allow_nan=False, separators=(",", ":"))
    original = legacy_source(state).decode().split("\n", 1)[1]
    data = (HEADER + "\n" + MARKER + record + "\n" + original).encode()
    if len(data) > LIMIT:
        raise ValueError("preferences exceed size limit")
    return data


def snapshot(config, legacy):
    data = read_file(config)
    previous = ""
    if data is not None and data.startswith((HEADER + "\n" + MARKER).encode()):
        record = decode(data.decode().split("\n", 2)[1][len(MARKER):])
        if type(record.get("version")) is not int or record["version"] != 1 or not isinstance(record.get("previous"), str) or not re.fullmatch(r"(?:[a-f0-9]{64})?", record["previous"]):
            raise ValueError("unsupported compositor document")
        state = validate(record.get("state"))
        previous = record["previous"]
        if encode(state, previous) != data:
            raise ValueError("generated compositor file was edited; preserving changes")
        revision = digest(data)
    else:
        old_json = read_file(legacy)
        # The installer's template is Bloom's own: a JSON left by an earlier
        # install describes a file that no longer exists, so start clean.
        pristine = data == INSTALLER_TEMPLATE
        state = validate(decode(old_json) if old_json is not None and not pristine else {})
        if data is not None and not pristine and data != legacy_source(state):
            raise ValueError("legacy compositor file differs from its state; preserving changes")
        revision = digest(b"legacy\0" + (data or b"missing") + b"\0" + (old_json or b"missing"))
    return {"state": state, "revision": revision, "previous": previous, "source": data}


def atomic_write(path, data):
    fd, temporary = tempfile.mkstemp(prefix=".bloom-compositor-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        temporary = None
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if temporary is not None:
            os.unlink(temporary)


@contextmanager
def exclusive(config):
    config.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(config.parent / ".bloom-compositor.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(fd)
        if info.st_uid != os.getuid() or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
            raise ValueError("unsafe compositor lock")
        deadline = time.monotonic() + 1.5
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise ValueError("compositor preference writer busy; retry")
                time.sleep(0.01)
        yield
    finally:
        os.close(fd)


def commit(config, legacy, expected, changes):
    with exclusive(config):
        old = snapshot(config, legacy)
        if old["revision"] != expected:
            raise ValueError("compositor preferences changed elsewhere; reload and retry")
        state = validate({**old["state"], **changes})
        if state == old["state"] and old["source"] is not None and old["previous"]:
            return old
        history = config.parent / ".bloom-settings-history"
        history.mkdir(mode=0o700, exist_ok=True)
        info = history.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError("unsafe compositor history directory")
        backup = history / (old["revision"] + ".json")
        saved = (json.dumps({"revision": old["revision"], "state": old["state"], "source": old["source"].decode() if old["source"] is not None else None}, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
        if len(saved) > 4 * LIMIT:
            raise ValueError("previous compositor snapshot exceeds size limit")
        existing = read_file(backup, 4 * LIMIT)
        if existing is not None and existing != saved:
            raise ValueError("previous compositor snapshot was changed; preserving it")
        if existing is None:
            atomic_write(backup, saved)
        if snapshot(config, legacy)["revision"] != expected:
            raise ValueError("compositor preferences changed during save; retry")
        atomic_write(config, encode(state, old["revision"]))
        # The newest snapshot is the new document's previous revision.
        retention.prune_history(history)
        retention.prune_stale(config.parent, (".bloom-compositor-*",))
        return snapshot(config, legacy)


def paths():
    config = Path(os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")) / "hypr/custom/bloom-settings.lua"
    legacy = Path(os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local/state")) / "bloom/hypr-settings.json"
    if not config.is_absolute() or not legacy.is_absolute():
        raise ValueError("XDG preference paths must be absolute")
    # Canonical parents give all cooperating instances the same lock identity.
    return config.parent.resolve() / config.name, legacy.parent.resolve() / legacy.name


def main():
    try:
        config, legacy = paths()
        if len(sys.argv) != 2:
            raise ValueError("expected a compositor store action")
        if sys.argv[1] == "read":
            result = snapshot(config, legacy)
        elif sys.argv[1] == "commit":
            request = sys.stdin.buffer.readline(LIMIT + 1)
            if len(request) > LIMIT:
                raise ValueError("preference request exceeds size limit")
            request = decode(request)
            result = commit(config, legacy, request["expected"], request["changes"])
        else:
            raise ValueError("unknown compositor store action")
        result = {"ok": True, **{k: v for k, v in result.items() if k != "source"}}
    except (ValueError, OSError, KeyError, TypeError) as error:
        result = {"ok": False, "error": str(error) if isinstance(error, ValueError) else "compositor storage unavailable; check permissions"}
    print(json.dumps(result, ensure_ascii=False, allow_nan=False))


if __name__ == "__main__":
    main()
