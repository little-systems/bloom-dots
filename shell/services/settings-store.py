#!/usr/bin/env python3
"""One atomic settings patch: serialized Bloom writers, per-key conflicts.

Payload and reply use pipes, never argv/logs. The JSON document stays compatible
with hand editing. Non-cooperating editors must not save during the final rename;
a content revision check detects intervening edits before that commit point.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import time

LIMIT = 1024 * 1024


def decode(data):
    def reject_constant(_):
        raise ValueError("non-finite JSON")
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    obj = json.loads(data, parse_constant=reject_constant, object_pairs_hook=unique)
    if not isinstance(obj, dict):
        raise ValueError("settings must be an object")
    return obj


def read(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except FileNotFoundError:
        return b"", {}
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError("settings is not an owned regular file")
        data = stream.read(LIMIT + 1)
    if len(data) > LIMIT:
        raise ValueError("settings exceeds size limit")
    try:
        return data, decode(data)
    except (ValueError, UnicodeDecodeError) as error:
        raise ValueError("settings.json is invalid; fix it before changing settings") from error


def patch(path, changes, base):
    if not isinstance(changes, dict) or not isinstance(base, dict):
        raise ValueError("invalid settings patch")
    if any(not isinstance(k, str) or not k.startswith("bloom-") for k in changes):
        raise ValueError("invalid setting key")
    parent = path.parent.resolve()
    parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = parent / path.name
    lock = os.open(parent / ".settings.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    temporary = None
    try:
        info = os.fstat(lock)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError("unsafe settings lock")
        deadline = time.monotonic() + 1.5
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise ValueError("settings writer busy; retry")
                time.sleep(0.01)
        original, current = read(path)
        # Unrelated changes merge; conflicting edits to a touched key reject
        # the entire batch. Repeating an already-committed value is a no-op.
        absent = object()
        for key, desired in changes.items():
            existing, previous = current.get(key, absent), base.get(key, absent)
            def same(a, b):
                if a is absent or b is absent:
                    return a is b
                return json.dumps(a, sort_keys=True, allow_nan=False) == json.dumps(b, sort_keys=True, allow_nan=False)
            if not same(existing, previous) and not same(existing, desired):
                raise ValueError("settings changed elsewhere; reload and retry (" + key + ")")
        merged = {**current, **changes}
        encoded = (json.dumps(merged, ensure_ascii=False, allow_nan=False, indent="\t") + "\n").encode()
        if len(encoded) > LIMIT:
            raise ValueError("settings exceeds size limit")
        if merged != current or not path.exists():
            fd, temporary = tempfile.mkstemp(prefix=".settings-", suffix=".tmp", dir=parent)
            with os.fdopen(fd, "wb") as stream:
                stream.write(encoded)
                stream.flush()
                os.fsync(stream.fileno())
            if read(path)[0] != original:
                raise ValueError("settings changed during save; reload and retry")
            os.replace(temporary, path)
            temporary = None
            directory = os.open(parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
            committed = encoded
        else:
            committed = original
        return {"ok": True, "value": merged, "revision": hashlib.sha256(committed).hexdigest()}
    finally:
        if temporary is not None:
            os.unlink(temporary)
        os.close(lock)


def main():
    try:
        data = sys.stdin.buffer.readline(LIMIT + 1)
        if len(data) > LIMIT:
            raise ValueError("settings patch exceeds size limit")
        request = decode(data)
        if len(sys.argv) != 2 or Path(sys.argv[1]).name != "settings.json":
            raise ValueError("invalid settings writer destination")
        result = patch(Path(sys.argv[1]), request["changes"], request["base"])
    except (OSError, ValueError, KeyError, TypeError) as error:
        # Do not echo request values, paths, raw JSON, or exception tracebacks.
        message = str(error) if isinstance(error, ValueError) else "settings storage unavailable; check permissions and free space"
        result = {"ok": False, "error": message}
    print(json.dumps(result, ensure_ascii=False, allow_nan=False))


if __name__ == "__main__":
    main()
