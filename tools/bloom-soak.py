#!/usr/bin/env python3
"""Cycle visual surfaces without changing settings or invoking power/auth actions."""
import argparse
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

POPUPS = ("launcher", "overview", "session", "cheatsheet", "wallpaper", "osk", "overlay")


class Failure(RuntimeError):
    pass


def run(*args):
    try:
        result = subprocess.run(args, text=True, capture_output=True, timeout=3)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise Failure(str(error)) from error
    if result.returncode:
        raise Failure(f"{args[0]} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def ipc(target, method, *args):
    return run("qs", "-c", "bloom", "ipc", "call", target, method, *args)


def action(target, method, *args):
    answer = ipc(target, method, *args)
    if answer != "ok":
        raise Failure(f"{target}.{method}: {answer}")


def locked():
    state = json.loads(ipc("lock", "state"))
    return bool(state.get("locked") or state.get("preparing"))


def pid():
    value = int(run("systemctl", "--user", "show", "--property=MainPID", "--value", "bloom-shell.service"))
    if value <= 0:
        raise Failure("Bloom service is not running")
    return value


def process_sample(process):
    # PID plus Linux start time detects PID reuse as well as service restarts.
    stat = Path(f"/proc/{process}/stat").read_text().rsplit(")", 1)[1].split()
    status = Path(f"/proc/{process}/status").read_text()
    rss = re.search(r"^VmRSS:\s+(\d+) kB$", status, re.M)
    if not rss:
        raise Failure("could not read Bloom's resident memory")
    return stat[19], int(rss.group(1)) / 1024


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("surface", choices=("notch", "dock") + POPUPS)
    parser.add_argument("--duration", type=float, default=600, help="seconds, default 600")
    parser.add_argument("--interval", type=float, default=0.25, help="seconds, default 0.25")
    parser.add_argument("--warmup", type=float, default=60, help="seconds before memory measurement")
    parser.add_argument("--max-growth-mib", type=float, default=8)
    args = parser.parse_args()
    if (not all(math.isfinite(value) for value in (args.duration, args.interval, args.warmup, args.max_growth_mib))
            or args.duration <= 0 or args.interval <= 0 or args.warmup < 0 or args.max_growth_mib < 0):
        parser.error("duration/interval must be positive; warmup/growth must be nonnegative")
    if ipc("shell", "ping") != "pong":
        raise Failure("Bloom did not answer")
    if locked():
        raise Failure("unlock the session before a visual soak")
    process = pid()
    identity, _ = process_sample(process)
    cursor_text = run("journalctl", "--user", "-u", "bloom-shell.service", "-n", "0", "--show-cursor", "--no-pager")
    cursor = re.search(r"^-- cursor: (.+)$", cursor_text, re.M)
    if not cursor:
        raise Failure("could not establish a journal cursor")
    target = args.surface
    if target not in json.loads(ipc("settings", "get", "bloom-enabled-modules")):
        raise Failure(f"{target} is disabled")
    state = json.loads(ipc(target, "state"))
    if target in ("notch", "dock"):
        if not isinstance(state, list) or not state:
            raise Failure(f"{target} is disabled")
        if any(item.get("sessionLocked") or item.get("lockPreparing") for item in state):
            raise Failure("unlock the session before a visual soak")
        originals = {item["userVisible"] for item in state}
        if len(originals) != 1:
            raise Failure("per-screen visibility differs; this soak cannot restore mixed visibility")
        original = originals.pop()
        visible = original

        def cycle():
            nonlocal visible
            visible = not visible
            action(target, "setVisible", str(visible).lower())

        def restore():
            action(target, "setVisible", str(original).lower())
    else:
        if not isinstance(state, dict) or "opened" not in state:
            raise Failure(f"{target} does not expose its open state")
        original = state["opened"]

        def cycle():
            action(target, "toggle")

        def restore():
            current = json.loads(ipc(target, "state"))["opened"]
            wanted = False if locked() else original
            if current != wanted:
                action(target, "toggle")

    start = time.monotonic()
    samples = []
    cycles = 0
    try:
        while time.monotonic() - start < args.duration:
            tick = time.monotonic()
            if pid() != process:
                raise Failure("Bloom restarted during the soak")
            if locked():
                raise Failure("session locked during the visual soak")
            current_identity, rss = process_sample(process)
            if current_identity != identity:
                raise Failure("Bloom's process identity changed")
            cycle()
            cycles += 1
            if time.monotonic() - start >= args.warmup:
                samples.append(rss)
            time.sleep(max(0, args.interval - (time.monotonic() - tick)))
    finally:
        restore()
    time.sleep(0.5)
    if pid() != process or process_sample(process)[0] != identity:
        raise Failure("Bloom restarted at the end of the soak")
    logs = run("journalctl", "--user", "-u", "bloom-shell.service", "--after-cursor=" + cursor.group(1),
               "--no-pager", "-o", "cat")
    warnings = [line for line in logs.splitlines() if re.search(r"\b(WARN(?:ING)?|ERROR|FATAL)\b", line)]
    if warnings:
        raise Failure("new shell warnings/errors:\n" + "\n".join(warnings))
    growth = max(samples) - samples[0] if samples else None
    if growth is not None and growth > args.max_growth_mib:
        raise Failure(f"resident memory grew {growth:.1f} MiB after warmup")
    print(json.dumps({"surface": target, "cycles": cycles, "seconds": round(time.monotonic() - start, 2),
                      "restarts": 0, "warnings": 0, "rss_growth_mib": growth,
                      "memory_measured": bool(samples)}))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("bloom: soak interrupted; original visibility restored", file=sys.stderr)
        sys.exit(130)
    except (Failure, OSError, ValueError, KeyError) as error:
        print(f"bloom: {error}", file=sys.stderr)
        sys.exit(1)
