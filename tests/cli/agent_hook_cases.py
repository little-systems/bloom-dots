#!/usr/bin/env python3
"""tools/bloom_agent_hook.py: agent events map exactly as Bloom's agent-hook.ps1
(63a9bf5), reach the shell through `qs ipc call agents event`, and never hold
up or change the agent."""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
HOOK = ROOT / "tools/bloom_agent_hook.py"
spec = importlib.util.spec_from_file_location("bloom_agent_hook", HOOK)
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)


class Mapping(unittest.TestCase):
    def kind(self, agent, event):
        return hook.map_event(agent, event)

    def test_claude_events(self):
        cases = [
            ({"hook_event_name": "Stop"}, ("ready", None)),
            ({"hook_event_name": "PermissionRequest"}, ("attention", None)),
            ({"hook_event_name": "Notification", "notification_type": "permission_prompt"}, ("attention", None)),
            ({"hook_event_name": "Notification", "notification_type": "elicitation_dialog"}, ("attention", None)),
            ({"hook_event_name": "Notification", "notification_type": "idle_prompt"}, (None, None)),
            ({"hook_event_name": "StopFailure"}, ("error", None)),
            ({"hook_event_name": "UserPromptSubmit"}, ("working", "thinking")),
            ({"hook_event_name": "PostToolUse"}, ("working", "thinking")),
            ({"hook_event_name": "PostToolUseFailure"}, ("working", "thinking")),
            ({"hook_event_name": "PostToolUseFailure", "is_interrupt": True}, ("stopped", None)),
            ({"hook_event_name": "SessionEnd"}, ("stopped", None)),
            ({"hook_event_name": "SubagentStop"}, (None, None)),
        ]
        for event, expected in cases:
            with self.subTest(event=event):
                self.assertEqual(self.kind("claude", event), expected)

    def test_codex_events(self):
        self.assertEqual(self.kind("codex", {"hook_event_name": "PermissionRequest"}), ("working", "working"))
        self.assertEqual(self.kind("codex", {"hook_event_name": "Interrupt"}), ("stopped", None))
        self.assertEqual(self.kind("codex", {"hook_event_name": "Stop"}), ("ready", None))

    def test_tool_names(self):
        cases = {
            "Edit": "editing", "Write": "editing", "apply_patch": "editing", "edit": "editing", "write": "editing",
            "Read": "reading", "Glob": "reading", "Grep": "reading", "read_file": "reading", "list_dir": "reading",
            "search": "reading", "read": "reading",
            "Bash": "running", "PowerShell": "running", "exec_command": "running", "bash": "running",
            "WebFetch": "thinking", "Editor": "thinking", "": "thinking",
        }
        for tool, activity in cases.items():
            with self.subTest(tool=tool):
                self.assertEqual(self.kind("claude", {"hook_event_name": "PreToolUse", "tool_name": tool}), ("working", activity))


class Payload(unittest.TestCase):
    def test_session_project_and_allow_list(self):
        event = {"hook_event_name": "UserPromptSubmit", "session_id": "s-1", "cwd": "/home/u/Projects/bloom/",
                 "prompt": "secret prompt text", "transcript_path": "/home/u/.claude/x.jsonl"}
        payload = hook.build_payload("claude", event, at=1700, owner={"pid": 42, "started": 7})
        self.assertEqual(payload, {"agent": "claude", "session": "s-1", "project": "bloom", "kind": "working",
                                   "activity": "thinking", "at": 1700, "pid": 42, "started": 7,
                                   "transcript": "/home/u/.claude/x.jsonl"})

    def test_transcript_is_claude_only_and_a_plain_jsonl_path(self):
        # The shell reads the end of a Claude transcript to notice turns that
        # end without a hook (an interrupt, a rewind); nothing else is sent.
        event = {"hook_event_name": "Stop", "session_id": "s", "cwd": "/x", "transcript_path": "/h/.codex/t.jsonl"}
        self.assertNotIn("transcript", hook.build_payload("codex", event, at=1, owner=None))
        for bad in ("relative/x.jsonl", "/h/x.json", "/h/../etc/x.jsonl", "/h/a\nb.jsonl", "/h/" + "a" * 1100 + ".jsonl", 5):
            with self.subTest(path=bad):
                event = {"hook_event_name": "Stop", "session_id": "s", "cwd": "/x", "transcript_path": bad}
                self.assertNotIn("transcript", hook.build_payload("claude", event, at=1, owner=None))

    def test_thread_id_when_no_session_id(self):
        payload = hook.build_payload("codex", {"hook_event_name": "Stop", "thread_id": "t-9", "cwd": "/tmp/x"}, at=1, owner=None)
        self.assertEqual(payload["session"], "t-9")
        self.assertNotIn("pid", payload)

    def test_no_session_or_event_sends_nothing(self):
        self.assertIsNone(hook.build_payload("claude", {"hook_event_name": "Stop", "cwd": "/x"}, at=1, owner=None))
        self.assertIsNone(hook.build_payload("claude", {"hook_event_name": "Nope", "session_id": "s"}, at=1, owner=None))

    def test_oversized_payload_is_never_sent(self):
        event = {"hook_event_name": "Stop", "session_id": "s" * 5000, "cwd": "/x"}
        self.assertIsNone(hook.build_payload("claude", event, at=1, owner=None))

    def test_project_is_trimmed_and_cleaned(self):
        event = {"hook_event_name": "Stop", "session_id": "s", "cwd": "/x/" + "a\x07b" + "c" * 100}
        self.assertEqual(hook.build_payload("claude", event, at=1, owner=None)["project"], "ab" + "c" * 62)


class Owner(unittest.TestCase):
    """The agent is the first ancestor that isn't a relay shell or interpreter,
    with its start time from /proc/<pid>/stat field 22."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="bloom-hook-proc-")
        self.addCleanup(self.tmp.cleanup)
        self.proc = Path(self.tmp.name)

    def add(self, pid, comm, ppid, started):
        d = self.proc / str(pid)
        d.mkdir()
        fields = ["S", str(ppid)] + ["0"] * 17 + [str(started)] + ["0"] * 10
        (d / "stat").write_text(f"{pid} ({comm}) " + " ".join(fields) + "\n")

    def test_skips_relays_to_the_agent(self):
        self.add(500, "claude", 1, 100)
        self.add(600, "bash", 500, 200)
        self.add(700, "python3", 600, 300)
        self.assertEqual(hook.find_owner(700, str(self.proc)), {"pid": 500, "started": 100})

    def test_a_comm_with_spaces_and_parens(self):
        self.add(500, "my agent (1)", 1, 100)
        self.add(700, "sh", 500, 300)
        self.assertEqual(hook.find_owner(700, str(self.proc)), {"pid": 500, "started": 100})

    def test_exited_or_reused_parent_means_ended(self):
        self.add(700, "sh", 500, 300)
        self.assertEqual(hook.find_owner(700, str(self.proc)), "ended")
        self.add(500, "claude", 1, 900)  # started after its child: a reused pid
        self.assertEqual(hook.find_owner(700, str(self.proc)), "ended")

    def test_unknown_when_proc_is_unreadable(self):
        self.assertIsNone(hook.find_owner(12345, str(self.proc)))


class Command(unittest.TestCase):
    """The installed command: stdout {} and exit 0, whatever happens."""

    def run_hook(self, agent, stdin, qs_script):
        with tempfile.TemporaryDirectory(prefix="bloom-hook-") as tmp:
            qs = Path(tmp) / "qs"
            log = Path(tmp) / "calls"
            qs.write_text("#!/bin/sh\n" + qs_script.replace("LOG", str(log)))
            qs.chmod(0o755)
            env = dict(os.environ, BLOOM_QS=str(qs))
            started = time.monotonic()
            result = subprocess.run([str(ROOT / "bin/bloom"), "agent-hook", agent], input=stdin,
                                    capture_output=True, text=True, env=env, timeout=10)
            elapsed = time.monotonic() - started
            calls = log.read_text().splitlines() if log.exists() else []
            return result, elapsed, calls

    def test_sends_one_ipc_call(self):
        event = json.dumps({"hook_event_name": "Stop", "session_id": "s-1", "cwd": "/home/u/bloom"})
        result, _, calls = self.run_hook("claude", event, 'printf "%s\\n" "$*" >> LOG\n')
        self.assertEqual((result.returncode, result.stdout), (0, "{}"))
        self.assertEqual(len(calls), 1)
        args = calls[0].split(" ", 6)
        self.assertEqual(args[:6], ["-c", "bloom", "ipc", "call", "agents", "event"])
        sent = json.loads(args[6])
        self.assertEqual((sent["agent"], sent["session"], sent["project"], sent["kind"]), ("claude", "s-1", "bloom", "ready"))
        self.assertIsInstance(sent["at"], int)

    def test_failing_or_hanging_shell_still_answers(self):
        event = json.dumps({"hook_event_name": "Stop", "session_id": "s-1", "cwd": "/x"})
        for script in ["exit 3\n", "sleep 30\n"]:
            with self.subTest(script=script):
                result, elapsed, _ = self.run_hook("codex", event, script)
                self.assertEqual((result.returncode, result.stdout), (0, "{}"))
                self.assertLess(elapsed, 3)

    def test_garbage_and_unknown_agents_answer(self):
        for agent, stdin in [("claude", "not json"), ("claude", ""), ("gemini", "{}")]:
            with self.subTest(agent=agent, stdin=stdin):
                result, _, calls = self.run_hook(agent, stdin, 'echo x >> LOG\n')
                self.assertEqual((result.returncode, result.stdout, calls), (0, "{}", []))


if __name__ == "__main__":
    unittest.main(verbosity=1)
