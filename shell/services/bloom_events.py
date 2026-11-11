"""Bloom's private event ledger (envelope version 1, stdlib only).

Lifecycle, stores and helpers record request, terminal and recovery
transitions here, so the CLI and `bloom doctor` work outside the desktop. The
ledger is `$XDG_STATE_HOME/bloom/log/events.jsonl`: mode 0600 in a 0700
directory, rotated at 5 MiB into four generations, and nothing older than 14
days is kept. Runtime messages still go to journald through the shell.

Only allowlisted detail fields are written. Strings are redacted (home path,
user name, keys and tokens) and capped, so callers can't leak values, prompts,
titles or command text by accident. Emitting never raises, because a full disk
must not stop locking or destroy an operation's recovery journal.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import time

VERSION = 1
MAX_BYTES = 5 * 1024 * 1024
GENERATIONS = 4
MAX_AGE_SECONDS = 14 * 86400
TEXT_LIMIT = 160
SAFE_DETAIL = frozenset({
    "action", "attempt", "backend", "bytes", "conflicts", "count", "durationMs", "exitCode", "generation",
    "kind", "path", "phase", "reason", "retry", "revision", "signal", "status", "step", "target", "truncated",
    "unit", "verified", "version",
})
LEVELS = ("debug", "info", "warning", "error")
_SECRETS = (
    re.compile(r"(?i)\b(api[_-]?key|key|token|password|passwd|secret|authorization|bearer)\b(\s*[=:]\s*|\s+)\S+"),
    re.compile(r"AIza[0-9A-Za-z_\-]{20,}"),
    re.compile(r"\bsk-[A-Za-z0-9_\-]{12,}"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"[A-Za-z0-9+/_\-]{40,}={0,2}"),
)


def state_dir():
    home = Path(os.environ.get("HOME") or Path.home())
    base = os.environ.get("XDG_STATE_HOME")
    return (Path(base) if base else home / ".local/state") / "bloom"


def redact(text, limit=TEXT_LIMIT):
    text = str(text)
    home = os.environ.get("HOME")
    if home and len(home) > 1:
        text = text.replace(home.rstrip("/"), "~")
    user = os.environ.get("USER") or os.environ.get("LOGNAME")
    if user and len(user) > 2:
        text = re.sub(rf"\b{re.escape(user)}\b", "<user>", text)
    for pattern in _SECRETS:
        text = pattern.sub(lambda m: (m.group(1) + "=<redacted>") if m.re is _SECRETS[0] else "<redacted>", text)
    return text[:limit]


def session_identity():
    # A stable token for this login session that names no user, seat or host.
    raw = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or os.environ.get("XDG_SESSION_ID") or ""
    return hashlib.sha256(raw.encode()).hexdigest()[:12] if raw else "none"


def clean_detail(detail):
    clean, omitted = {}, 0
    for key, value in detail.items():
        if key not in SAFE_DETAIL:
            omitted += 1
        elif value is None or isinstance(value, (bool, int, float)):
            clean[key] = value
        elif isinstance(value, str):
            clean[key] = redact(value)
        else:
            omitted += 1
    if omitted:
        clean["omitted"] = omitted
    return clean


class Events:
    def __init__(self, component, rate=60, window=60.0, max_bytes=MAX_BYTES, generations=GENERATIONS):
        self.component = component
        self.rate, self.window = rate, window
        self.max_bytes, self.generations = max_bytes, generations
        self.path = state_dir() / "log/events.jsonl"
        # Read-only queries (dry runs, inspection) set this False: no effects.
        self.enabled = True
        self._counts = {}
        self._pruned = False

    def _allowed(self, event):
        now = time.monotonic()
        start, count, dropped = self._counts.get(event, (now, 0, 0))
        if now - start >= self.window:
            if dropped:
                self._counts[event] = (now, 1, 0)
                self._write(self._record("events.dropped", "warning", None, None, None, None, None,
                                         {"count": dropped, "reason": event}))
            start, count, dropped = now, 0, 0
        if count >= self.rate:
            self._counts[event] = (start, count, dropped + 1)
            return False
        self._counts[event] = (start, count + 1, dropped)
        return True

    def _record(self, event, level, op, stage, outcome, error, attempt, detail):
        return {
            "v": VERSION, "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "mono": round(time.monotonic(), 3),
            "level": level if level in LEVELS else "info", "event": redact(event), "component": self.component,
            "op": op, "session": session_identity(), "stage": stage, "outcome": outcome,
            "error": redact(error) if error is not None else None, "attempt": attempt,
            "detail": clean_detail(detail),
        }

    def emit(self, event, level="info", op=None, stage=None, outcome=None, error=None, attempt=None, **detail):
        try:
            if not self.enabled or not self._allowed(event):
                return False
            return self._write(self._record(event, level, op, stage, outcome, error, attempt, detail))
        except Exception:  # noqa: BLE001 - logging must never break the caller
            return False

    def _write(self, record):
        try:
            directory = self.path.parent
            directory.mkdir(mode=0o700, parents=True, exist_ok=True)
            if directory.stat().st_mode & 0o077:
                os.chmod(directory, 0o700)
            line = (json.dumps(record, separators=(",", ":"), sort_keys=True) + "\n").encode()
            self._rotate(len(line))
            fd = os.open(self.path, os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
            try:
                os.write(fd, line)
            finally:
                os.close(fd)
            return True
        except OSError:
            return False

    def _rotate(self, incoming):
        if not self._pruned:
            self._pruned = True
            cutoff = time.time() - MAX_AGE_SECONDS
            for old in self.path.parent.glob(self.path.name + "*"):
                try:
                    if old.is_file() and not old.is_symlink() and old.stat().st_mtime < cutoff:
                        old.unlink()
                except OSError:
                    pass
        try:
            size = self.path.stat().st_size
        except FileNotFoundError:
            return
        if size + incoming <= self.max_bytes:
            return
        last = self.path.with_name(f"{self.path.name}.{self.generations - 1}")
        last.unlink(missing_ok=True)
        for n in range(self.generations - 2, 0, -1):
            older = self.path.with_name(f"{self.path.name}.{n}")
            if older.exists():
                os.replace(older, self.path.with_name(f"{self.path.name}.{n + 1}"))
        os.replace(self.path, self.path.with_name(f"{self.path.name}.1"))


def read_recent(levels=("warning", "error"), limit=10):
    """Newest-first records at the given levels, across generations."""
    path = state_dir() / "log/events.jsonl"
    found = []
    for n in range(GENERATIONS):
        current = path if n == 0 else path.with_name(f"{path.name}.{n}")
        try:
            lines = current.read_text(errors="replace").splitlines()
        except OSError:
            continue
        for line in reversed(lines):
            try:
                record = json.loads(line)
            except ValueError:
                continue
            if record.get("level") in levels and record.get("event") != "events.dropped":
                found.append(record)
                if len(found) >= limit:
                    return found
    return found
