"""Bounded leftovers for Bloom's Python writers (stdlib only).

Writers replace files atomically through temporary names; a crash or SIGKILL
can leave those behind. Anything matching a writer's own temporary pattern and
older than an hour can't belong to a write in progress. Compositor history and
finished display trials are kept to the newest few.
"""
import json
import os
from pathlib import Path
import shutil
import stat
import time

STALE_SECONDS = 3600
HISTORY_KEEP = 10
TRIALS_KEEP = 10
FINISHED_TRIALS = {"kept", "reverted", "failed", "conflict", "disconnected"}


def _owned(info):
    return info.st_uid == os.getuid() and not stat.S_ISLNK(info.st_mode)


def prune_stale(directory, patterns, max_age=STALE_SECONDS):
    """Remove old files/directories matching patterns. Never follows symlinks."""
    directory = Path(directory)
    cutoff = time.time() - max_age
    removed = 0
    for pattern in patterns:
        for path in directory.glob(pattern):
            try:
                info = path.lstat()
                if not _owned(info) or info.st_mtime > cutoff:
                    continue
                if stat.S_ISDIR(info.st_mode):
                    shutil.rmtree(path)
                elif stat.S_ISREG(info.st_mode):
                    path.unlink()
                else:
                    continue
                removed += 1
            except OSError:
                continue
    return removed


def _newest_first(paths):
    dated = []
    for path in paths:
        try:
            info = path.lstat()
        except OSError:
            continue
        if _owned(info):
            dated.append((info.st_mtime, path.name, path))
    return [path for _, _, path in sorted(dated, reverse=True)]


def prune_history(directory, keep=HISTORY_KEEP):
    """Keep the newest `keep` *.json snapshots."""
    for path in _newest_first(Path(directory).glob("*.json"))[keep:]:
        try:
            if path.is_file():
                path.unlink()
        except OSError:
            continue


def prune_trials(root, keep=TRIALS_KEEP):
    """Keep the newest `keep` finished trial records; unfinished ones stay."""
    finished = []
    for directory in Path(root).iterdir():
        if not directory.is_dir() or directory.is_symlink():
            continue
        try:
            phase = json.loads((directory / "status.json").read_text()).get("phase")
        except (OSError, ValueError, AttributeError):
            continue
        if phase in FINISHED_TRIALS:
            finished.append(directory)
    for directory in _newest_first(finished)[keep:]:
        shutil.rmtree(directory, ignore_errors=True)
