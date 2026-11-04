#!/usr/bin/env python3
"""Export an owner-selected settings copy without claiming a failed copy worked."""
import json
import os
from pathlib import Path
import stat
import sys
import tempfile


def reject_constant(_):
    raise ValueError("non-finite JSON")


def export(source, destination):
    with source.open("rb") as stream:
        data = stream.read(1024 * 1024 + 1)
    if len(data) > 1024 * 1024 or not isinstance(json.loads(data, parse_constant=reject_constant), dict):
        raise ValueError("invalid settings document")
    if destination.exists() or destination.is_symlink():
        info = destination.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError("destination is not an owned regular file")
    fd, temporary = tempfile.mkstemp(prefix=".bloom-export-", dir=destination.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, destination)
        temporary = None
        directory = os.open(destination.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if temporary is not None:
            os.unlink(temporary)


if __name__ == "__main__":
    try:
        export(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError, IndexError):
        print("Settings export failed; check the selected file and its permissions.", file=sys.stderr)
        sys.exit(1)
