#!/usr/bin/env python3
"""Bloom's agent hook: `bloom agent-hook <claude|codex>`, run by the agent with
the event JSON on stdin (or `opencode-event`, run by Bloom's OpenCode plugin
with an event it already mapped). Maps it exactly as Bloom's integrations/agent-hook.ps1
(63a9bf5) and hands it to the running shell with `qs ipc call agents event`.

Advisory only: it never decides anything for the agent, always prints {} (Codex
Stop needs valid JSON) and exits 0, and gives up on the shell after 2 s, so a
closed or restarting Bloom never slows or stops an agent. Only allow-listed
values are sent: no prompts, responses, tool arguments or commands."""
import json
import os
import re
import subprocess
import sys
import time

AGENTS = ("claude", "codex")
KINDS = ("working", "ready", "attention", "error", "resolved", "stopped")
ACTIVITIES = ("thinking", "reading", "editing", "running", "working", "checking")
MAX_PAYLOAD = 4096
SEND_TIMEOUT = 2
# Processes that only relay a hook to us, never the agent itself (Bloom's
# RELAY_PROCESSES, for Linux).
RELAYS = {"sh", "bash", "zsh", "dash", "fish", "env", "python", "python3"}

EDITING = re.compile(r"^(Edit|Write|apply_patch|edit|write)$")
READING = re.compile(r"^(Read|Glob|Grep|read_file|list_dir|search|read)$")
RUNNING = re.compile(r"^(Bash|PowerShell|exec_command|bash)$")


def map_event(agent, event):
    """(kind, activity) for an event, or (None, None) when Bloom ignores it."""
    name = event.get("hook_event_name")
    if name == "Stop":
        return "ready", None
    if name == "PermissionRequest":
        # Fires before the approval decision, including automatic review.
        return ("working", "working") if agent == "codex" else ("attention", None)
    if name == "Notification":
        if event.get("notification_type") in ("permission_prompt", "elicitation_dialog"):
            return "attention", None
        return None, None
    if name == "StopFailure":
        return "error", None
    if name in ("UserPromptSubmit", "PostToolUse"):
        return "working", "thinking"
    if name == "PreToolUse":
        tool = str(event.get("tool_name") or "")
        if EDITING.match(tool):
            return "working", "editing"
        if READING.match(tool):
            return "working", "reading"
        if RUNNING.match(tool):
            return "working", "running"
        return "working", "thinking"
    if name == "PostToolUseFailure":
        return ("stopped", None) if event.get("is_interrupt") else ("working", "thinking")
    if name in ("Interrupt", "SessionEnd"):
        return "stopped", None
    return None, None


def build_payload(agent, event, at, owner):
    """The payload for the shell, or None when nothing should be sent."""
    kind, activity = map_event(agent, event)
    session = event.get("session_id") or event.get("thread_id")
    if not kind or not session:
        return None
    cwd = str(event.get("cwd") or "").rstrip("/\\")
    project = re.split(r"[\\/]", cwd)[-1] if cwd else ""
    project = "".join(c for c in project if c.isprintable())[:64]
    payload = {"agent": agent, "session": str(session), "project": project, "kind": kind}
    if activity:
        payload["activity"] = activity
    payload["at"] = at
    if isinstance(owner, dict):
        payload.update(owner)
    if len(json.dumps(payload, separators=(",", ":")).encode()) > MAX_PAYLOAD:
        return None
    return payload


def opencode_payload(event, at, owner):
    """An event the OpenCode plugin already mapped, if it is allow-listed
    exactly (Bloom's AgentAlert::validate, with no unknown fields)."""
    if not isinstance(event, dict) or not set(event) <= {"agent", "session", "project", "kind", "activity"}:
        return None
    session, kind, activity = event.get("session"), event.get("kind"), event.get("activity")
    if event.get("agent", "opencode") != "opencode" or kind not in KINDS or not isinstance(session, str) \
            or not 0 < len(session) <= 256 or (activity is not None and activity not in ACTIVITIES):
        return None
    project = "".join(c for c in str(event.get("project") or "") if c.isprintable())[:64]
    payload = {"agent": "opencode", "session": session, "project": project, "kind": kind}
    if activity:
        payload["activity"] = activity
    payload["at"] = at
    if isinstance(owner, dict):
        payload.update(owner)
    return payload


def _stat(pid, proc):
    """(comm, ppid, starttime) from /proc/<pid>/stat, or None."""
    try:
        with open(f"{proc}/{pid}/stat", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return None
    # comm is in parentheses and may itself contain spaces and parentheses.
    left, right = text.find("("), text.rfind(")")
    if left < 0 or right < left:
        return None
    fields = text[right + 2:].split()
    try:
        return text[left + 1:right], int(fields[1]), int(fields[19])
    except (IndexError, ValueError):
        return None


def find_owner(pid, proc="/proc"):
    """The agent process behind this hook: {"pid", "started"}; "ended" when
    the chain breaks (the agent already exited, or its pid was reused); None
    when it can't be told."""
    info = _stat(pid, proc)
    if info is None:
        return None
    name, parent, started = info
    for _ in range(8):
        if name not in RELAYS:
            return {"pid": pid, "started": started} if pid > 1 else None
        next_info = _stat(parent, proc)
        if next_info is None or next_info[2] > started:
            return "ended"
        pid, (name, parent, started) = parent, next_info
    return None


def send(payload):
    qs = os.environ.get("BLOOM_QS", "qs")
    subprocess.run([qs, "-c", "bloom", "ipc", "call", "agents", "event", json.dumps(payload, separators=(",", ":"))],
                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=SEND_TIMEOUT, check=False)


def main(argv):
    at = int(time.time() * 1000)
    try:
        agent = argv[1] if len(argv) > 1 else ""
        if agent in AGENTS or agent == "opencode-event":
            event = json.loads(sys.stdin.read(1 << 20) or "null")
            if isinstance(event, dict):
                owner = find_owner(os.getpid(), os.environ.get("BLOOM_PROC", "/proc"))
                payload = opencode_payload(event, at, owner) if agent == "opencode-event" \
                    else build_payload(agent, event, at, owner)
                if payload is not None:
                    if owner == "ended":
                        payload["kind"] = "stopped"
                        payload.pop("activity", None)
                    send(payload)
    except Exception:
        # Bloom closed or unavailable: the agent continues normally.
        pass
    sys.stdout.write("{}")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
