#!/usr/bin/env python3
"""Reduce Motion reaches Hyprland: hypr/bloom.lua reads Bloom's settings and,
when the setting is on, turns the compositor's animations off after the
user's own files load. Runs bloom.lua in plain Lua with a stand-in hl."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HARNESS = """local seen = {}
hl = {
 on = function(event, callback) end,
 exec_cmd = function(command) end,
 config = function(options) if options.animations then seen[#seen + 1] = options.animations.enabled end end
}
dofile(arg[1])
for _, enabled in ipairs(seen) do print(tostring(enabled)) end
"""


@unittest.skipUnless(shutil.which("lua"), "Lua is required to run bloom.lua")
class ReduceMotion(unittest.TestCase):
    def animations(self, settings=None, own=None, unreadable=False):
        """The animations.enabled values bloom.lua sets, in order."""
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            (base / "hypr/custom").mkdir(parents=True)
            (base / "bloom").mkdir()
            if settings is not None:
                path = base / "bloom/settings.json"
                path.write_text(settings if isinstance(settings, str) else json.dumps(settings))
                if unreadable:
                    path.chmod(0)
            if own is not None:
                (base / "hypr/custom/bloom.lua").write_text(own)
            env = dict(os.environ, XDG_CONFIG_HOME=str(base), BLOOM_CGROUP_FILE=str(base / "none"))
            run = subprocess.run(["lua", "-", str(ROOT / "hypr/bloom.lua")], input=HARNESS, text=True,
                                 env=env, capture_output=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            return run.stdout.split()

    def test_reduce_motion_turns_animations_off(self):
        self.assertEqual(self.animations({"bloom-reduce-motion": True})[-1:], ["false"])

    def test_string_true_counts(self):
        self.assertEqual(self.animations({"bloom-reduce-motion": "true"})[-1:], ["false"])

    def test_off_missing_or_broken_leaves_animations_alone(self):
        self.assertEqual(self.animations({"bloom-reduce-motion": False}), [])
        self.assertEqual(self.animations(), [])
        self.assertEqual(self.animations("{not json"), [])
        if os.geteuid() != 0:
            self.assertEqual(self.animations({"bloom-reduce-motion": True}, unreadable=True), [])

    def test_other_settings_mentioning_true_dont_count(self):
        self.assertEqual(self.animations({"bloom-reduce-motion": False, "bloom-dock-enabled": True}), [])

    def test_beats_the_users_own_file(self):
        own = "hl.config({ animations = { enabled = true } })\n"
        self.assertEqual(self.animations({"bloom-reduce-motion": True}, own=own), ["true", "false"])


if __name__ == "__main__":
    unittest.main()
