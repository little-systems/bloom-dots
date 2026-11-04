#!/usr/bin/env python3
"""An independently owned, bounded Hyprland display trial.

A transient user unit owns the watchdog, not the Settings window. The window
may request Keep/Revert, but only the worker applies, verifies and persists.
"""
import fcntl
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import signal
import selectors
import stat
import subprocess
import sys
import time
import uuid

sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("compositor_store", Path(__file__).with_name("compositor-store.py"))
store = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(store)
TERMINAL = {"kept", "reverted", "failed", "conflict", "disconnected"}


def identity(pid):
    try:
        directory = Path("/proc") / str(pid)
        if directory.stat().st_uid != os.getuid():
            return None
        text = (directory / "stat").read_text()
        return {"pid": int(pid), "start": text.rsplit(") ", 1)[1].split()[19]}
    except (OSError, ValueError, IndexError):
        return None


def root_path(create=False):
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", ""))
    if not runtime.is_absolute() or runtime.stat().st_uid != os.getuid() or runtime.stat().st_mode & 0o077:
        raise ValueError("a private runtime directory is required")
    session = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if not session:
        raise ValueError("Hyprland session unavailable")
    if runtime.is_symlink():
        raise ValueError("unsafe runtime directory")
    root = runtime / "bloom-display-trials" / store.digest(session.encode())[:16]
    for directory in (root.parent, root):
        if create:
            directory.mkdir(mode=0o700, exist_ok=True)
        info = directory.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError("unsafe display trial directory")
    return root


def trial_path(root, trial):
    if not re.fullmatch(r"[a-f0-9]{32}", trial):
        raise ValueError("invalid display trial identifier")
    directory = root / trial
    if directory.exists() or directory.is_symlink():
        info = directory.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError("unsafe trial record directory")
    return directory


def read_json(path):
    raw = store.read_file(path)
    if raw is None:
        return None
    return store.decode(raw)


def write_json(path, value):
    store.atomic_write(path, (json.dumps(value, allow_nan=False, separators=(",", ":")) + "\n").encode())


def target(mode, scale):
    match = re.fullmatch(r"([0-9]+)x([0-9]+)@([0-9]+(?:\.[0-9]+)?)(?:Hz)?", str(mode))
    scale = float(scale)
    if not match or not math.isfinite(scale) or not 0.25 <= scale <= 4 or not all(0 < float(match[i]) <= 100000 for i in (1, 2, 3)):
        raise ValueError("unsupported display mode or scale")
    return {"width": int(match[1]), "height": int(match[2]), "hz": float(match[3]), "scale": scale}


def command(argv, timeout=2):
    # Enforce limits while reading, rather than after an unbounded capture.
    process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
    output = bytearray()
    counts = {"out": 0, "err": 0}
    deadline = time.monotonic() + timeout
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ, "out")
            selector.register(process.stderr, selectors.EVENT_READ, "err")
            while selector.get_map():
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(argv, timeout)
                for key, _ in selector.select(min(remaining, .1)):
                    data = os.read(key.fd, 65536)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    counts[key.data] += len(data)
                    if counts[key.data] > (store.LIMIT if key.data == "out" else 65536):
                        raise ValueError("display backend output exceeds limit")
                    if key.data == "out":
                        output.extend(data)
        process.wait(timeout=max(.01, deadline - time.monotonic()))
        if process.returncode:
            raise ValueError("display backend rejected the operation")
        return bytes(output)
    finally:
        # A child retaining either pipe must not survive a deadline/flood.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        process.stdout.close()
        process.stderr.close()


def observed(monitor):
    result = {key: monitor.get(key, default) for key, default in {
        "name": "", "width": 0, "height": 0, "refreshRate": 0, "scale": 1,
        "x": 0, "y": 0, "transform": 0, "currentFormat": "XRGB8888",
        "colorManagementPreset": "srgb", "vrr": False, "mirrorOf": "none",
    }.items()}
    for key in ("width", "height", "x", "y", "transform"):
        if type(result[key]) is not int or abs(result[key]) > 100000:
            raise ValueError("invalid display backend geometry")
    target(str(result["width"]) + "x" + str(result["height"]) + "@" + str(result["refreshRate"]), result["scale"])
    if result["transform"] not in range(8):
        raise ValueError("invalid display transform")
    return result


def compatible_profile(monitor):
    mirror = monitor.get("mirrorOf", "none")
    if mirror not in (None, "none", "", -1) or monitor.get("vrr", False) or monitor.get("colorManagementPreset", "srgb") != "srgb":
        raise ValueError("This advanced display profile cannot be safely trialled yet")
    if monitor.get("currentFormat", "XRGB8888") not in ("XRGB8888", "ARGB8888", "XBGR8888", "ABGR8888"):
        raise ValueError("This display format cannot be safely trialled yet")


def line(monitor):
    if not re.fullmatch(r"[A-Za-z0-9._-]+", monitor["name"]):
        raise ValueError("unsupported display output name")
    hz = format(float(monitor["refreshRate"]), ".8g")
    text = 'hl.monitor({ output = "' + monitor["name"] + '", mode = "' + str(monitor["width"]) + 'x' + str(monitor["height"]) + '@' + hz
    text += '", position = "' + str(monitor["x"]) + 'x' + str(monitor["y"]) + '", scale = ' + format(float(monitor["scale"]), ".8g")
    if monitor.get("transform", 0):
        transform = int(monitor["transform"])
        if transform not in range(8):
            raise ValueError("unsupported display transform")
        text += ", transform = " + str(transform)
    return text + " })"


def same(actual, expected):
    return actual is not None and all(actual.get(key) == expected.get(key) for key in ("name", "width", "height", "x", "y", "transform", "currentFormat", "colorManagementPreset", "vrr", "mirrorOf")) \
        and abs(float(actual.get("scale", 0)) - float(expected["scale"])) < 0.01 \
        and abs(float(actual.get("refreshRate", 0)) - float(expected["refreshRate"])) < 0.15


class Backend:
    def get(self, output):
        monitors = json.loads(command(["hyprctl", "-j", "monitors"]))
        monitor = next((entry for entry in monitors if entry.get("name") == output), None)
        return observed(monitor) if monitor is not None else None

    def apply(self, monitor):
        command(["hyprctl", "eval", line(monitor)])

    def verify(self, monitor, seconds=1.2):
        deadline = time.monotonic() + seconds
        while True:
            if same(self.get(monitor["name"]), monitor):
                return True
            if time.monotonic() >= deadline:
                return False
            time.sleep(0.1)


def monitor_entry(state, output):
    return [value for value in state["monitors"] if 'output = "' + output + '"' in value]


class Trial:
    def __init__(self, directory, backend=None, owner_alive=None, duration=15):
        self.directory = directory
        self.plan = read_json(directory / "plan.json")
        self.status = read_json(directory / "status.json") or {"id": self.plan["id"], "phase": "starting"}
        self.backend = backend or Backend()
        self.owner_alive = owner_alive or (lambda owner: identity(owner["pid"]) == owner)
        self.duration = duration
        self.stopping = False

    def publish(self, phase, error="", **extra):
        self.status = {**self.status, **extra, "phase": phase, "error": error}
        write_json(self.directory / "status.json", self.status)

    def rollback(self, reason=""):
        previous, wanted = self.status.get("previous"), self.status.get("wanted")
        if not previous:
            self.publish("failed", reason or "Display trial could not start")
            return
        actual = self.backend.get(previous["name"])
        if actual is None:
            self.publish("disconnected", "Display disconnected; no new preference was saved")
            return
        if same(actual, previous):
            self.publish("reverted", reason)
            return
        # A partial apply is ours only if each changed field is previous/target.
        owned = all(actual.get(key) in (previous.get(key), wanted.get(key)) for key in ("width", "height")) \
            and any(abs(float(actual["scale"]) - float(candidate["scale"])) < 0.01 for candidate in (previous, wanted)) \
            and any(abs(float(actual["refreshRate"]) - float(candidate["refreshRate"])) < 0.15 for candidate in (previous, wanted)) \
            and all(actual.get(key) == previous.get(key) for key in ("x", "y", "transform", "currentFormat", "colorManagementPreset", "vrr", "mirrorOf"))
        if not owned:
            self.publish("conflict", "Display changed outside this trial; preserving that change")
            return
        self.publish("reverting", reason)
        self.backend.apply(previous)
        if not self.backend.verify(previous):
            self.publish("failed", "Display rollback could not be verified; recovery data was retained")
            return
        self.publish("reverted", reason)

    def prepare(self):
        output = self.plan["output"]
        previous = self.backend.get(output)
        if previous is None:
            raise ValueError("display is no longer connected")
        compatible_profile(previous)
        config, legacy = store.paths()
        preferences = store.snapshot(config, legacy)
        requested = self.plan["target"]
        wanted = {**previous, "width": requested["width"], "height": requested["height"], "refreshRate": requested["hz"], "scale": requested["scale"]}
        # Both snapshot and rollback information are durable before applying.
        self.publish("applying", previous=previous, wanted=wanted, originalEntry=monitor_entry(preferences["state"], output))
        self.backend.apply(wanted)
        if not self.backend.verify(wanted):
            raise ValueError("Display did not accept the requested settings")
        self.publish("pending", remaining=self.duration, deadline=time.monotonic() + self.duration)

    def keep(self):
        wanted = self.status["wanted"]
        if not self.backend.verify(wanted, 0):
            self.rollback("Display changed before confirmation")
            return
        config, legacy = store.paths()
        current = store.snapshot(config, legacy)
        if monitor_entry(current["state"], wanted["name"]) != self.status["originalEntry"]:
            self.rollback("Saved display preferences changed elsewhere; nothing was kept")
            return
        lines = [entry for entry in current["state"]["monitors"] if entry not in monitor_entry(current["state"], wanted["name"])] + [line(wanted)]
        state = store.validate({**current["state"], "monitors": lines})
        revision = current["revision"] if state == current["state"] and current["source"] is not None and current["previous"] else store.digest(store.encode(state, current["revision"]))
        # This durable intent precedes persistence, so restart can recognize a
        # committed Keep even if the final acknowledgement was interrupted.
        self.publish("confirming", confirmRevision=revision)
        try:
            store.commit(config, legacy, current["revision"], {"monitors": lines})
        except (ValueError, OSError):
            self.recover_confirmation()
            return
        self.publish("kept")

    def recover_confirmation(self):
        config, legacy = store.paths()
        current = store.snapshot(config, legacy)
        if current["revision"] == self.status.get("confirmRevision"):
            # Retry the durability barrier if replace succeeded but fsync or
            # acknowledgement was interrupted. Never claim a rollback here.
            with config.open("rb") as stream:
                os.fsync(stream.fileno())
            fd = os.open(config.parent, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
            self.publish("kept")
        elif monitor_entry(current["state"], self.plan["output"]) == self.status["originalEntry"]:
            self.rollback("Confirmation was interrupted before preferences committed")
        else:
            self.rollback("Saved display preferences changed during confirmation")


    def run(self):
        try:
            if self.status["phase"] in TERMINAL:
                return
            if self.status["phase"] == "confirming":
                self.recover_confirmation()
                return
            if self.status["phase"] != "starting":
                self.rollback("Display watchdog restarted; unconfirmed trial was reverted")
                return
            if not self.owner_alive(self.plan["owner"]):
                self.publish("failed", "Settings closed before the display trial started")
                return
            self.prepare()
            while self.status["phase"] == "pending":
                if self.stopping or not self.owner_alive(self.plan["owner"]) or time.monotonic() >= self.status["deadline"]:
                    self.rollback()
                    return
                actual = self.backend.get(self.plan["output"])
                if not same(actual, self.status["wanted"]):
                    self.rollback("Display changed during the trial")
                    return
                request = read_json(self.directory / "command.json")
                if request:
                    if request["action"] == "keep":
                        self.keep()
                    elif request["action"] == "revert":
                        self.rollback()
                    else:
                        self.rollback("Unsupported display trial action")
                    return
                remaining = max(0, math.ceil(self.status["deadline"] - time.monotonic()))
                if remaining != self.status.get("remaining"):
                    self.publish("pending", remaining=remaining)
                time.sleep(0.15)
        except (ValueError, OSError, subprocess.SubprocessError, KeyError, TypeError):
            if self.status["phase"] == "confirming":
                self.publish("failed", "Display confirmation needs recovery; saved preferences and trial record were retained")
                return
            try:
                self.rollback("Display operation was not confirmed; previous settings were requested")
            except (ValueError, OSError, subprocess.SubprocessError, KeyError, TypeError):
                self.publish("failed", "Display rollback was not confirmed; recovery data was retained")


def start(request):
    output = request["output"]
    if not isinstance(output, str) or not re.fullmatch(r"[A-Za-z0-9._-]+", output):
        raise ValueError("unsupported display output name")
    desired = target(request["mode"], request["scale"])
    owner = identity(os.getppid())
    if owner is None:
        raise ValueError("Settings process identity unavailable")
    root = root_path(True)
    trial = uuid.uuid4().hex
    directory = trial_path(root, trial)
    directory.mkdir(mode=0o700)
    write_json(directory / "plan.json", {"id": trial, "owner": owner, "output": output, "target": desired})
    argv = ["systemd-run", "--user", "--quiet", "--collect", "--unit=bloom-display-" + trial,
            "--property=Type=exec", "--property=Restart=on-failure", "--property=RestartSec=0.2s",
            "--property=RuntimeMaxSec=45s", "--property=TimeoutStopSec=8s", "--property=UMask=0077"]
    for key in ("HOME", "PATH", "XDG_RUNTIME_DIR", "XDG_CONFIG_HOME", "XDG_STATE_HOME", "HYPRLAND_INSTANCE_SIGNATURE", "WAYLAND_DISPLAY"):
        if key in os.environ:
            argv.append("--setenv=" + key + "=" + os.environ[key])
    argv += [sys.executable, str(Path(__file__).resolve()), "run", trial]
    try:
        command(argv, 5)
    except (ValueError, OSError, subprocess.SubprocessError):
        return {"ok": False, "id": trial, "path": str(directory / "status.json"), "error": "Independent display watchdog start was not confirmed; any started trial will revert automatically"}
    return {"ok": True, "id": trial, "path": str(directory / "status.json")}


def main():
    try:
        action = sys.argv[1]
        if action == "begin":
            result = start(store.decode(sys.stdin.buffer.readline(store.LIMIT + 1)))
        elif action == "run":
            root = root_path()
            fd = os.open(root / "active.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
            info = os.fstat(fd)
            if info.st_uid != os.getuid() or not stat.S_ISREG(info.st_mode) or info.st_mode & 0o077:
                os.close(fd)
                raise ValueError("unsafe display trial lock")
            directory = trial_path(root, sys.argv[2])
            trial = Trial(directory)
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                trial.publish("failed", "Another display trial is already running")
            else:
                signal.signal(signal.SIGTERM, lambda *_: setattr(trial, "stopping", True))
                trial.run()
            finally:
                os.close(fd)
            result = {"ok": True, "id": sys.argv[2], "phase": trial.status["phase"]}
        elif action in ("keep", "revert"):
            directory = trial_path(root_path(), sys.argv[2])
            plan, status = read_json(directory / "plan.json"), read_json(directory / "status.json")
            if identity(os.getppid()) != plan["owner"]:
                raise ValueError("Display trial belongs to another Settings process")
            if not status or status["phase"] != "pending":
                raise ValueError("Display trial is not awaiting confirmation")
            path = directory / "command.json"
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, "w") as stream:
                json.dump({"action": action}, stream)
                stream.flush()
                os.fsync(stream.fileno())
            result = {"ok": True, "id": sys.argv[2]}
        else:
            raise ValueError("unknown display trial action")
    except (ValueError, OSError, subprocess.SubprocessError, KeyError, TypeError, IndexError):
        result = {"ok": False, "error": "Display trial request failed; no confirmation was recorded"}
    print(json.dumps(result))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
