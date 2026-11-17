#!/usr/bin/env python3
"""tools/bloom_agents.py: `bloom agents status|connect|disconnect <agent>`.
Cases follow Bloom's agent_alerts.rs tests (63a9bf5), on Linux paths."""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TOOL = ROOT / "tools/bloom_agents.py"
spec = importlib.util.spec_from_file_location("bloom_agents", TOOL)
agents = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agents)
HOOK_SPEC = importlib.util.spec_from_file_location("bloom_agent_hook", ROOT / "tools/bloom_agent_hook.py")
hook = importlib.util.module_from_spec(HOOK_SPEC)
HOOK_SPEC.loader.exec_module(hook)


def handlers(config, event):
    return [h for g in config["hooks"].get(event, []) for h in g["hooks"]]


class Merge(unittest.TestCase):
    def test_install_is_idempotent_and_removal_preserves_user_hooks(self):
        config = {"permissions": {"allow": ["Read"]}, "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "my-hook"}]}]}}
        original = json.loads(json.dumps(config))
        agents.merge_hooks(config, "bloom-hook", "claude", True)
        installed = json.loads(json.dumps(config))
        agents.merge_hooks(config, "bloom-hook", "claude", True)
        self.assertEqual(config, installed)
        agents.merge_hooks(config, "bloom-hook", "claude", False)
        self.assertEqual(config, original)

    def test_claude_hooks_run_async_and_codex_hooks_keep_a_timeout(self):
        for agent, handler in [("claude", {"type": "command", "command": "bloom", "async": True}),
                               ("codex", {"type": "command", "command": "bloom", "timeout": 3})]:
            config = {}
            agents.merge_hooks(config, "bloom", agent, True)
            self.assertEqual(sorted(config["hooks"]), sorted(agents.HOOK_EVENTS[agent]))
            for event in agents.HOOK_EVENTS[agent]:
                self.assertEqual(config["hooks"][event][0]["hooks"], [handler], event)

    def test_events_and_notification_matcher(self):
        self.assertEqual(agents.HOOK_EVENTS["claude"], ["Stop", "PermissionRequest", "Notification", "UserPromptSubmit",
            "PreToolUse", "PostToolUse", "PostToolUseFailure", "StopFailure", "SessionEnd"])
        self.assertEqual(agents.HOOK_EVENTS["codex"], ["Stop", "PermissionRequest", "UserPromptSubmit", "PreToolUse",
            "PostToolUse", "Interrupt", "SessionEnd"])
        config = {}
        agents.merge_hooks(config, "bloom", "claude", True)
        self.assertEqual(config["hooks"]["Notification"][0]["matcher"], "permission_prompt|elicitation_dialog")
        self.assertNotIn("matcher", config["hooks"]["Stop"][0])

    def test_older_blocking_claude_hooks_need_an_update(self):
        config = {}
        agents.merge_hooks(config, "bloom", "claude", True)
        self.assertEqual(agents.hook_state(config, "bloom", "claude"), (True, False))
        config["hooks"]["PreToolUse"][0]["hooks"][0] = {"type": "command", "command": "bloom", "timeout": 3}
        self.assertEqual(agents.hook_state(config, "bloom", "claude"), (True, True))

    def test_live_hooks_preserve_handlers_sharing_a_group(self):
        for agent in ["claude", "codex"]:
            config = {"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "bloom"}, {"type": "command", "command": "my-hook"}]}]}}
            agents.merge_hooks(config, "bloom", agent, True)
            self.assertIn("my-hook", [h["command"] for h in handlers(config, "Stop")])
            agents.merge_hooks(config, "bloom", agent, False)
            self.assertEqual(handlers(config, "Stop"), [{"type": "command", "command": "my-hook"}])
            self.assertEqual(list(config["hooks"]), ["Stop"])

    def test_malformed_config_is_rejected(self):
        for bad in [{"hooks": []}, {"hooks": {"Stop": "bad"}}, {"hooks": {"Stop": [{"hooks": "x"}]}}, []]:
            with self.subTest(bad=bad), self.assertRaises(agents.AgentError):
                agents.merge_hooks(bad, "bloom", "codex", True)

    def test_hook_command_quotes_the_checkout_and_refuses_metacharacters(self):
        self.assertEqual(agents.hook_command("/home/u/My Dots", "claude"), "'/home/u/My Dots/bin/bloom' agent-hook claude")
        for bad in ["/home/u/it's", "/home/u/$x", "/home/u/a`b", '/home/u/a"b', "/home/u/a\\b", "/home/u/a\nb"]:
            with self.subTest(bad=bad), self.assertRaises(agents.AgentError):
                agents.hook_command(bad, "codex")


class Cli(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="bloom-agents-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = {k: v for k, v in os.environ.items() if k not in ("CLAUDE_CONFIG_DIR", "CODEX_HOME", "XDG_CONFIG_HOME", "XDG_STATE_HOME")}
        self.env["HOME"] = str(self.home)

    def bloom(self, *args, env=None):
        result = subprocess.run([str(ROOT / "bin/bloom"), "agents", *args], capture_output=True, text=True,
                                env=env or self.env, timeout=30)
        return result.returncode, json.loads(result.stdout or "null"), result.stderr

    def status(self, agent, env=None):
        code, out, _ = self.bloom("status", env=env)
        self.assertEqual(code, 0)
        return next(i for i in out["integrations"] if i["agent"] == agent)

    def test_connect_writes_a_backup_once_and_keeps_other_settings(self):
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir()
        original = '{\n  "model": "opus",\n  "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "my-hook"}]}]}\n}\n'
        settings.write_text(original)
        self.assertEqual(self.bloom("connect", "claude")[:2], (0, {"ok": True}))
        backup = self.home / ".claude/settings.json.bloom-backup"
        self.assertEqual(backup.read_text(), original)
        config = json.loads(settings.read_text())
        self.assertEqual(list(config), ["model", "hooks"], "key order is kept")
        self.assertEqual(config["model"], "opus")
        command = agents.hook_command(str(ROOT), "claude")
        self.assertEqual(handlers(config, "Stop"), [{"type": "command", "command": "my-hook"},
            {"type": "command", "command": command, "async": True}])
        settings.write_text(settings.read_text().replace("opus", "sonnet"))
        self.assertEqual(self.bloom("disconnect", "claude")[0], 0)
        self.assertEqual(backup.read_text(), original, "the first backup is never replaced")
        self.assertEqual(json.loads(settings.read_text()), {"model": "sonnet", "hooks": {"Stop": [{"hooks": [{"type": "command", "command": "my-hook"}]}]}})

    def test_unreadable_config_is_left_alone(self):
        hooks = self.home / ".codex/hooks.json"
        hooks.parent.mkdir()
        hooks.write_text('{ // a comment\n "hooks": {} }')
        code, out, _ = self.bloom("connect", "codex")
        self.assertEqual(code, 1)
        self.assertFalse(out["ok"])
        self.assertEqual(hooks.read_text(), '{ // a comment\n "hooks": {} }')
        self.assertFalse((self.home / ".codex/hooks.json.bloom-backup").exists())

    def test_disconnect_without_config_does_nothing(self):
        self.assertEqual(self.bloom("disconnect", "codex")[:2], (0, {"ok": True}))
        self.assertFalse((self.home / ".codex").exists())

    def test_paths_honour_the_agent_environment(self):
        env = dict(self.env, CLAUDE_CONFIG_DIR=str(self.home / "c"), CODEX_HOME=str(self.home / "x"), XDG_CONFIG_HOME=str(self.home / "cfg"))
        for agent in ["claude", "codex", "opencode"]:
            self.assertEqual(self.bloom("connect", agent, env=env)[:2], (0, {"ok": True}), agent)
        self.assertTrue((self.home / "c/settings.json").exists())
        self.assertTrue((self.home / "x/hooks.json").exists())
        self.assertTrue((self.home / "cfg/opencode/plugins/bloom-notifications.js").exists())
        self.assertTrue((self.home / "cfg/opencode/plugins/bloom-notifications/index.js").exists())
        self.assertEqual(self.status("codex", env)["path"], str(self.home / "x/hooks.json"))

    def test_status_follows_install_update_and_verification(self):
        self.assertEqual({k: self.status("codex")[k] for k in ("installed", "needsUpdate", "verifiedAt")},
                         {"installed": False, "needsUpdate": False, "verifiedAt": None})
        self.bloom("connect", "codex")
        self.assertEqual((self.status("codex")["installed"], self.status("codex")["needsUpdate"]), (True, False))
        hooks = self.home / ".codex/hooks.json"
        config = json.loads(hooks.read_text())
        del config["hooks"]["Interrupt"]
        hooks.write_text(json.dumps(config))
        self.assertEqual((self.status("codex")["installed"], self.status("codex")["needsUpdate"]), (True, True))
        state = self.home / ".local/state/bloom/agents.json"
        state.parent.mkdir(parents=True)
        state.write_text(json.dumps({"codex": 1700000000000}))
        self.assertEqual(self.status("codex")["verifiedAt"], 1700000000000)
        self.bloom("connect", "codex")
        self.assertIsNone(self.status("codex")["verifiedAt"], "a changed connection waits for a new event")
        self.assertEqual(self.status("codex")["needsUpdate"], False)

    def test_opencode_plugins_install_and_a_modified_one_is_never_touched(self):
        plugin = self.home / ".config/opencode/plugins/bloom-notifications.js"
        self.assertEqual(self.bloom("connect", "opencode")[0], 0)
        text = plugin.read_text()
        self.assertIn(json.dumps(str(ROOT / "bin/bloom")), text)
        self.assertNotIn("__BLOOM_HOOK__", text)
        self.assertEqual((self.status("opencode")["installed"], self.status("opencode")["needsUpdate"]), (True, False))
        plugin.write_text(text + "\n// mine\n")
        code, out, _ = self.bloom("disconnect", "opencode")
        self.assertEqual(code, 1)
        self.assertIn("was modified", out["error"])
        self.assertTrue(plugin.read_text().endswith("// mine\n"))
        plugin.write_text(text)
        self.assertEqual(self.bloom("disconnect", "opencode")[0], 0)
        self.assertFalse(plugin.exists())
        self.assertFalse(plugin.with_suffix("").exists(), "the empty v2 folder goes too")

    def test_status_reports_malformed_groups_as_json(self):
        settings = self.home / ".claude/settings.json"
        settings.parent.mkdir()
        settings.write_text(json.dumps({"hooks": {"Stop": None}}))
        code, out, stderr = self.bloom("status")
        self.assertEqual(code, 1)
        self.assertIn("hooks.Stop must be an array", out["error"])
        self.assertNotIn("Traceback", stderr)

    def test_opencode_update_recognizes_the_installed_adapter_version(self):
        checkout = self.home / "checkout"
        (checkout / "tools").mkdir(parents=True)
        (checkout / "integrations").mkdir()
        tool = checkout / "tools/bloom_agents.py"
        shutil.copyfile(TOOL, tool)
        templates = []
        for original in agents.PLUGINS:
            template = checkout / "integrations" / original.name
            shutil.copyfile(original, template)
            templates.append(template)

        def run(*args):
            result = subprocess.run([sys.executable, str(tool), *args], env=self.env,
                                    capture_output=True, text=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            return json.loads(result.stdout)

        run("connect", "opencode")
        plugin = self.home / ".config/opencode/plugins/bloom-notifications.js"
        original = plugin.read_text()
        for template in templates:
            template.write_text(template.read_text() + "\n// New Bloom adapter version\n")
        row = next(row for row in run("status")["integrations"] if row["agent"] == "opencode")
        self.assertTrue(row["installed"])
        self.assertTrue(row["needsUpdate"])
        run("connect", "opencode")
        self.assertIn("// New Bloom adapter version", plugin.read_text())
        self.assertEqual(plugin.with_name(plugin.name + ".bloom-backup").read_text(), original)
        row = next(row for row in run("status")["integrations"] if row["agent"] == "opencode")
        self.assertFalse(row["needsUpdate"])
        run("disconnect", "opencode")
        self.assertFalse(plugin.exists())
        self.assertFalse(agents.plugin_receipt(plugin).exists())

    def test_opencode_recovers_a_receipt_failure_across_another_upgrade(self):
        templates = []
        for original in agents.PLUGINS:
            target = self.home / original.name
            shutil.copyfile(original, target)
            templates.append(target)
        with patch.dict(os.environ, self.env, clear=True), patch.object(agents, "PLUGINS", templates):
            agents.configure_opencode(True)
            for template in templates:
                template.write_text(template.read_text() + "\n// version two\n")
            save = agents._save
            def fail_final_receipt(path, text):
                if path.name.endswith(".bloom-owned") and not text.startswith("["):
                    raise OSError("receipt write failed")
                save(path, text)
            with patch.object(agents, "_save", side_effect=fail_final_receipt):
                with self.assertRaises(OSError):
                    agents.configure_opencode(True)
            for template in templates:
                template.write_text(template.read_text() + "\n// version three\n")
            agents.configure_opencode(True)
            for path in agents.plugin_paths():
                self.assertIn("// version three", path.read_text())

    def test_unknown_agent(self):
        code, out, _ = self.bloom("connect", "gemini")
        self.assertEqual((code, out["ok"]), (1, False))


class OpenCodeEvents(unittest.TestCase):
    """The OpenCode plugins send already-mapped events through
    `bloom agent-hook opencode-event`; only allow-listed values pass."""

    def test_valid_event(self):
        payload = hook.opencode_payload({"agent": "opencode", "session": "ses_1", "project": "bloom", "kind": "working",
                                         "activity": "editing"}, at=5, owner={"pid": 9, "started": 1})
        self.assertEqual(payload, {"agent": "opencode", "session": "ses_1", "project": "bloom", "kind": "working",
                                   "activity": "editing", "at": 5, "pid": 9, "started": 1})

    def test_rejects_anything_off_the_allow_list(self):
        for bad in [{"session": "s", "kind": "deleted"}, {"session": "s", "kind": "working", "activity": "rm -rf"},
                    {"session": "", "kind": "ready"}, {"session": "s", "kind": "ready", "prompt": "secret"}, []]:
            with self.subTest(bad=bad):
                self.assertIsNone(hook.opencode_payload(bad, at=1, owner=None))


if __name__ == "__main__":
    unittest.main(verbosity=1)
