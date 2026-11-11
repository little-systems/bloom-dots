#!/usr/bin/env python3
"""`bloom doctor`: a read-only health report, even when Bloom won't start.

Every probe is time-bounded and changes nothing: no restarts, no settings
writes, no uploads. Output is human-readable, or versioned JSON with --json.
Exit status: 0 healthy, 1 degraded, 2 failed. `--support` builds a private,
allowlisted support bundle (see --preview) that is never uploaded.
"""
import argparse
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True


def _load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / "shell/services" / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


events = _load("bloom_events", "bloom_events.py")
operations = _load("bloom_operations", "bloom_operations.py")

VERSION = 1
UNIT = "bloom-shell.service"
# Commands Bloom actually runs (shell, scripts, CLI), mapped to Arch packages.
REQUIRED = {
    "qs": "quickshell", "hyprctl": "hyprland", "python3": "python", "jq": "jq", "matugen": "matugen",
    "cava": "cava", "cliphist": "cliphist", "wl-copy": "wl-clipboard", "grim": "grim", "slurp": "slurp",
    "wf-recorder": "wf-recorder", "tesseract": "tesseract", "hyprsunset": "hyprsunset", "hyprlock": "hyprlock",
    "brightnessctl": "brightnessctl", "qalc": "libqalculate", "pactl": "libpulse", "nmcli": "networkmanager",
    "notify-send": "libnotify", "xdg-open": "xdg-utils", "gsettings": "glib2", "gio": "glib2",
    "dbus-monitor": "dbus", "busctl": "systemd", "udevadm": "systemd", "systemd-run": "systemd",
    "lsblk": "util-linux",
}
OPTIONAL = {"mpvpaper": "video wallpapers", "satty": "screenshot annotation", "swappy": "screenshot annotation",
            "songrec": "music recognition", "trans": "translation", "checkupdates": "package updates",
            "secret-tool": "AI key storage", "udisksctl": "dock drives"}
EXCLUSIVE = {"org.freedesktop.Notifications": "notifications", "org.kde.StatusNotifierWatcher": "tray"}
LIFECYCLE_OK = {"complete", "uninstalled"}
LIFECYCLE_INTERRUPTED = {"installing", "uninstalling", "updating"}


def count(n, word, plural=None):
    return f"{n} {word if n == 1 else plural or word + 's'}"


def home():
    return Path(os.environ.get("HOME") or Path.home())


def config_dir():
    base = os.environ.get("XDG_CONFIG_HOME")
    return (Path(base) if base else home() / ".config") / "bloom"


def state_dir():
    return events.state_dir()


def probe(action, argv, timeout=3):
    if shutil.which(argv[0]) is None:
        return None
    return operations.run_operation("doctor", action, argv, timeout=timeout, output_limit=16384)


def check(id, status, summary, recovery=""):
    return {"id": id, "status": status, "summary": events.redact(summary, 2000), "recovery": recovery}


def session():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    display = os.environ.get("WAYLAND_DISPLAY", "")
    socket = Path(runtime) / display if runtime and display else None
    if socket is None or not socket.exists():
        return check("session", "degraded", "no Wayland session in this environment (console or SSH?)",
                     "Run doctor from inside the Hyprland session for live checks.")
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return check("session", "degraded", "Wayland is running but this is not a Hyprland session")
    result = probe("hyprland-version", ["hyprctl", "version", "-j"])
    if result is None or result["state"] != "success":
        return check("session", "failed", "Hyprland is not answering", "Log out and back in if the compositor is stuck.")
    try:
        tag = json.loads(result["stdout"]).get("tag", "unknown")
    except ValueError:
        tag = "unknown"
    return check("session", "ok", f"Hyprland {tag} is answering ({profile()} session)")


def profile():
    # Where Hyprland itself runs decides the profile, never what is installed.
    result = probe("hyprland-pid", ["pgrep", "-x", "Hyprland"])
    pid = result["stdout"].split()[0] if result and result["state"] == "success" and result["stdout"].split() else None
    try:
        text = Path(f"/proc/{pid}/cgroup").read_text() if pid else ""
    except OSError:
        text = ""
    return "UWSM" if "wayland-wm@" in text else "native" if pid else "unknown"


def service():
    result = probe("service-state", ["systemctl", "--user", "show", UNIT, "-p",
                                     "LoadState,ActiveState,SubState,Result,NRestarts,UnitFileState"])
    if result is None or result["state"] != "success":
        return check("service", "skipped", "the user service manager is not reachable")
    props = dict(line.split("=", 1) for line in result["stdout"].splitlines() if "=" in line)
    active, outcome = props.get("ActiveState", "unknown"), props.get("Result", "")
    if props.get("LoadState") == "not-found":
        return check("service", "degraded", f"{UNIT} is not installed", "Run: bloom install")
    if outcome == "start-limit-hit":
        return check("service", "failed", f"{UNIT} hit its restart limit ({props.get('NRestarts', '?')} restarts)",
                     f"Check the log below, then run: systemctl --user reset-failed {UNIT} && systemctl --user start {UNIT}")
    if active == "failed":
        return check("service", "failed", f"{UNIT} failed ({outcome or 'unknown reason'})",
                     f"Check the log below, then run: systemctl --user restart {UNIT}")
    if active != "active":
        return check("service", "degraded", f"{UNIT} is {active}", f"Start it with: systemctl --user start {UNIT}")
    return check("service", "ok", f"{UNIT} is active ({props.get('SubState', '')})")


def shell_ipc():
    result = probe("shell-ping", ["qs", "-c", "bloom", "ipc", "call", "shell", "ping"])
    if result is None:
        return check("shell", "failed", "Quickshell (qs) is not installed", "Install the dependencies: bloom install")
    if result["state"] == "success" and "pong" in result["stdout"]:
        return check("shell", "ok", "the shell answers IPC")
    return check("shell", "degraded", "the shell is not answering IPC", f"Restart it: systemctl --user restart {UNIT}")


def settings():
    path = config_dir() / "settings.json"
    if not path.exists():
        return check("settings", "ok", "no settings file yet; defaults are in use")
    try:
        info = path.lstat()
        if path.is_symlink() or not path.is_file():
            return check("settings", "failed", "settings.json is not a regular file", "Replace it with a regular file.")
        doc = json.loads(path.read_text())
    except (OSError, ValueError):
        return check("settings", "failed", "settings.json is unreadable or not valid JSON",
                     "Fix or move ~/.config/bloom/settings.json; Bloom keeps it and uses defaults meanwhile.")
    if not isinstance(doc, dict):
        return check("settings", "failed", "settings.json is not a JSON object", "Fix or move the file.")
    leftovers = len(list(path.parent.glob(".settings-*.tmp")))
    if info.st_mode & 0o022:
        return check("settings", "degraded", "settings.json is writable by other users", "Run: chmod 600 ~/.config/bloom/settings.json")
    note = f"; {count(leftovers, 'interrupted save leftover')}, cleaned on the next save" if leftovers else ""
    return check("settings", "ok", f"{count(len(doc), 'key')}, valid{note}")


def state():
    directory = state_dir()
    damaged, quarantined = [], []
    for path in sorted(directory.glob("*.json")):
        if path.name in ("install-manifest.json", "migration-manifest.json"):
            continue
        try:
            json.loads(path.read_text())
        except (OSError, ValueError):
            damaged.append(path.stem)
    for path in sorted(directory.glob("*.json.bak*")):
        quarantined.append(path.name.split(".json")[0])
    if damaged or quarantined:
        parts = []
        if damaged:
            parts.append("unreadable: " + ", ".join(damaged))
        if quarantined:
            parts.append("set-aside copies: " + ", ".join(sorted(set(quarantined))))
        return check("state", "degraded", "; ".join(parts),
                     "Bloom sets damaged state aside as <name>.json.bak and uses defaults; delete the .bak files once reviewed.")
    return check("state", "ok", "UI state documents are readable")


def lifecycle():
    path = state_dir() / "install-manifest.json"
    if not path.exists():
        return check("lifecycle", "ok", "no managed installation (development or not installed)")
    try:
        status = json.loads(path.read_text()).get("status", "unknown")
    except (OSError, ValueError, AttributeError):
        return check("lifecycle", "failed", "the installation manifest is unreadable", "Run: bloom recover")
    if status in LIFECYCLE_OK:
        return check("lifecycle", "ok", f"installation {status}")
    if status not in LIFECYCLE_INTERRUPTED:
        return check("lifecycle", "degraded", f"unknown installation status ({status})", "Run: bloom recover")
    return check("lifecycle", "failed", f"an installation operation was interrupted ({status})",
                 "Run: bloom recover   (read-only), then bloom recover --resume or --restore-originals")


def themes():
    directory = state_dir() / "app-themes"
    if (directory / "manifest").exists():
        return check("themes", "ok", "app themes use the earlier backup format; converted on the next change")
    ledger = directory / "ownership.json"
    if not ledger.exists():
        return check("themes", "ok", "no app theme files are owned by Bloom")
    try:
        doc = json.loads(ledger.read_text())
        owned = len(doc.get("targets", {}))
    except (OSError, ValueError, AttributeError):
        return check("themes", "failed", "the app theme ownership ledger is unreadable",
                     "Move ~/.local/state/bloom/app-themes/ownership.json aside; originals stay in originals/.")
    kept = directory / "kept"
    note = "; pre-Bloom copies of edited files are in app-themes/kept" if kept.exists() else ""
    return check("themes", "ok", f"Bloom owns {count(owned, 'app theme file')}{note}")


def dependencies():
    missing = sorted({package for command, package in REQUIRED.items() if shutil.which(command) is None})
    absent = sorted(f"{command} ({use})" for command, use in OPTIONAL.items() if shutil.which(command) is None)
    note = f"; optional not installed: {', '.join(absent)}" if absent else ""
    if missing:
        return check("dependencies", "degraded", "missing: " + ", ".join(missing) + note,
                     "Install them with: sudo pacman -S --needed " + " ".join(missing))
    return check("dependencies", "ok", "all required commands are installed" + note)


def bus():
    if shutil.which("busctl") is None:
        return check("bus", "skipped", "busctl is not installed")
    conflicts, owners = [], []
    for name, feature in EXCLUSIVE.items():
        result = probe("bus-owner", ["busctl", "--user", "status", name])
        if result is None or result["state"] != "success":
            continue
        props = dict(line.split("=", 1) for line in result["stdout"].splitlines() if "=" in line)
        comm = props.get("Comm", "unknown")
        if comm in ("qs", "quickshell", ".quickshell-wra"):
            owners.append(feature)
        else:
            conflicts.append(f"{feature} is owned by {comm}")
    if conflicts:
        return check("bus", "degraded", "; ".join(conflicts),
                     "Another program holds a service Bloom provides. Stop or disable it, then restart Bloom.")
    return check("bus", "ok", "Bloom owns: " + ", ".join(owners) if owners else "no exclusive desktop services are claimed")


def display():
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    unfinished = 0
    if runtime:
        for status in Path(runtime, "bloom-display-trials").glob("*/*/status.json"):
            try:
                phase = json.loads(status.read_text()).get("phase")
            except (OSError, ValueError, AttributeError):
                continue
            if phase not in ("kept", "reverted", "failed", "conflict", "disconnected") and time.time() - status.stat().st_mtime > 60:
                unfinished += 1
    history = list((home() / ".config/hypr/custom/.bloom-settings-history").glob("*.json"))
    if unfinished:
        return check("display", "degraded", f"{count(unfinished, 'display trial')} did not finish",
                     "Open Settings → Display to review the current mode; unconfirmed trials revert automatically.")
    return check("display", "ok", f"no unfinished display trials; {count(len(history), 'compositor snapshot')} kept")


def capabilities():
    result = probe("capabilities", ["qs", "-c", "bloom", "ipc", "call", "capabilities", "snapshot"])
    if result is None or result["state"] != "success":
        return check("capabilities", "skipped", "the shell is not answering; backend states unknown")
    try:
        backends = json.loads(result["stdout"]).get("backends", {})
    except (ValueError, AttributeError):
        return check("capabilities", "skipped", "the shell returned no capability report")
    bad = sorted(f"{name} {entry.get('state')}" + (f" ({entry['reason']})" if entry.get("reason") else "")
                 for name, entry in backends.items() if entry.get("state") in ("degraded", "missing"))
    if bad:
        return check("capabilities", "degraded", "; ".join(bad),
                     "Missing programs: install them (see dependencies). Backends retry on their own with backoff; "
                     "to retry now: bloom ipc capabilities retry <backend>")
    return check("capabilities", "ok", f"{count(len(backends), 'backend')} reporting, none degraded")


CHECKS = (session, service, shell_ipc, capabilities, settings, state, lifecycle, themes, dependencies, bus, display)


def report():
    checks = []
    for run in CHECKS:
        try:
            checks.append(run())
        except Exception as error:  # noqa: BLE001 - one broken probe must not hide the rest
            checks.append(check(run.__name__, "failed", f"probe crashed: {type(error).__name__}"))
    statuses = {c["status"] for c in checks}
    verdict = "failed" if "failed" in statuses else "degraded" if "degraded" in statuses else "healthy"
    recent = [{k: r.get(k) for k in ("ts", "event", "component", "level", "error", "outcome")}
              for r in events.read_recent(limit=5)]
    return {"version": VERSION, "verdict": verdict, "checks": checks, "recentFailures": recent}


def versions():
    lines = []
    version = ROOT / "VERSION"
    lines.append("bloom: " + (version.read_text().strip() if version.exists() else "unknown"))
    for label, argv in (("quickshell", ["qs", "--version"]), ("hyprland", ["hyprctl", "version", "-j"])):
        result = probe(label, argv)
        text = "not found" if result is None else result["stdout"].strip().splitlines()[0] if result["stdout"].strip() else "unknown"
        if label == "hyprland" and result is not None:
            try:
                text = json.loads(result["stdout"]).get("tag", "unknown")
            except ValueError:
                text = "not running"
        lines.append(f"{label}: {events.redact(text)}")
    return "\n".join(lines) + "\n"


def human(doc):
    marks = {"ok": "ok", "degraded": "!!", "failed": "XX", "skipped": "--"}
    out = [f"Bloom doctor: {doc['verdict']}", "", versions().rstrip(), ""]
    for c in doc["checks"]:
        out.append(f"[{marks[c['status']]}] {c['id']}: {c['summary']}")
        if c["recovery"] and c["status"] in ("degraded", "failed"):
            out.append(f"     -> {c['recovery']}")
    if doc["recentFailures"]:
        out += ["", "Recent problems:"]
        out += [f"  {r['ts']} {r['component']} {r['event']} {r.get('error') or ''}".rstrip() for r in doc["recentFailures"]]
    out += ["", "If the lock screen crashes the session stays locked. To recover:",
            "  1. Press Ctrl+Alt+F3 and log in on the text console.",
            "  2. Run: hyprctl --instance 0 eval 'hl.config({ misc = { allow_session_lock_restore = true } })'",
            f"  3. Run: systemctl --user restart {UNIT}",
            "     (or: hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd(\"hyprlock\")')",
            "  4. Press Ctrl+Alt+F1 (or F2) to return and unlock."]
    return "\n".join(out) + "\n"


def settings_keys():
    # Names and value types only: values can be keys, locations or personal text.
    try:
        doc = json.loads((config_dir() / "settings.json").read_text())
    except (OSError, ValueError):
        return {"readable": False}
    if not isinstance(doc, dict):
        return {"readable": False}
    return {"readable": True, "keys": {events.redact(k): type(v).__name__ for k, v in sorted(doc.items())}}


def bundle_files(doc):
    log = ""
    path = state_dir() / "log/events.jsonl"
    try:
        lines = path.read_text(errors="replace").splitlines()[-2000:]
        log = "".join(json.dumps(_reclean(line), separators=(",", ":")) + "\n" for line in lines)
    except OSError:
        pass
    return {"doctor.json": json.dumps(doc, indent=2) + "\n", "events.jsonl": log,
            "settings-keys.json": json.dumps(settings_keys(), indent=2) + "\n", "versions.txt": versions()}


def _reclean(line):
    # Records are already redacted when written; redact again for older entries.
    try:
        record = json.loads(line)
    except ValueError:
        return {"unparseable": True}
    return {k: events.redact(v) if isinstance(v, str) else events.clean_detail(v) if isinstance(v, dict) else v
            for k, v in record.items()}


def support(preview, output):
    files = bundle_files(report())
    if preview:
        print("A support bundle would contain (nothing is uploaded):")
        for name, text in files.items():
            print(f"  {name}  {len(text.encode())} bytes")
        print("Settings values, notification text, prompts, clipboard and paths under your home are not included.")
        return 0
    target = Path(output) if output else state_dir() / "support" / time.strftime("bloom-support-%Y%m%d-%H%M%S.tar.gz")
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as stream, tarfile.open(fileobj=stream, mode="w:gz") as archive:
        for name, text in sorted(files.items()):
            data = text.encode()
            info = tarfile.TarInfo(name)
            info.size, info.mode, info.mtime = len(data), 0o600, int(time.time())
            archive.addfile(info, io.BytesIO(data))
    print(f"Support bundle written to {events.redact(str(target))} (private, not uploaded).")
    return 0


def main(argv):
    parser = argparse.ArgumentParser(prog="bloom doctor", description=__doc__.splitlines()[0])
    parser.add_argument("--json", action="store_true", help="versioned JSON output")
    parser.add_argument("--support", action="store_true", help="write a private support bundle")
    parser.add_argument("--preview", action="store_true", help="with --support: list contents, write nothing")
    parser.add_argument("--output", help="with --support: bundle path")
    args = parser.parse_args(argv)
    if args.support:
        return support(args.preview, args.output)
    doc = report()
    sys.stdout.write(json.dumps(doc, indent=2) + "\n" if args.json else human(doc))
    return {"healthy": 0, "degraded": 1, "failed": 2}[doc["verdict"]]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
