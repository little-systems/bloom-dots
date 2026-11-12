"""Exercise the real Hyprland start hook and unit guard without live services."""
import json
import os
from pathlib import Path
import shlex
import shutil
import socket
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SessionStartup(unittest.TestCase):
    @unittest.skipUnless(shutil.which("lua"), "Lua is required to execute the start hook")
    def test_login_recovers_rate_limit_and_replaces_previous_session(self):
        for import_fails in (False, True):
            with self.subTest(import_fails=import_fails), tempfile.TemporaryDirectory() as tmp:
                base = Path(tmp)
                stub = base / "systemctl"
                stub.write_text("""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
p = Path(os.environ['START_TEST_STATE'])
s = json.loads(p.read_text())
args = sys.argv[1:]
s['calls'].append(args)
if args[1] == 'reset-failed': s['limited'] = False
if args[1] in ('restart', 'start'):
    s['started'] = not s['limited']
    s['replaced'] = args[1] == 'restart'
p.write_text(json.dumps(s))
sys.exit(1 if args[1] == 'import-environment' and os.environ['IMPORT_FAILS'] == '1' else 0)
""")
                stub.chmod(0o755)
                state = base / "state.json"
                state.write_text(json.dumps(dict(limited=True, started=False, calls=[])))
                env = dict(os.environ, PATH=str(base) + ":" + os.environ["PATH"],
                           XDG_CONFIG_HOME=str(base), START_TEST_STATE=str(state),
                           IMPORT_FAILS=str(int(import_fails)), WAYLAND_DISPLAY="wayland-new",
                           BLOOM_CGROUP_FILE=str(base / "no-cgroup"))
                harness = """hl = {
 on = function(event, callback)
   assert(event == 'hyprland.start'); callback()
 end,
 exec_cmd = function(command) os.execute(command) end,
 config = function(options) end
}
dofile(arg[1])
"""
                subprocess.run(["lua", "-", str(ROOT / "hypr/bloom.lua")],
                               input=harness, text=True, env=env, check=True)
                result = json.loads(state.read_text())
                self.assertEqual(result['calls'][0][1], 'import-environment')
                if import_fails:
                    self.assertEqual(len(result['calls']), 1, 'failed import must not launch with old environment')
                else:
                    self.assertTrue(result['started'], 'new login must clear the old restart limit')
                    self.assertTrue(result['replaced'], 'an old process must be replaced with the new display environment')
                    self.assertEqual(result['calls'][1:], [
                        ['--user', 'reset-failed', 'bloom-shell.service'],
                        ['--user', 'restart', 'bloom-shell.service']])

    def test_unit_requires_a_live_hyprland_session(self):
        unit = (ROOT / 'systemd/bloom-shell.service').read_text()
        guards = [line.split('=', 1)[1] for line in unit.splitlines() if line.startswith('ExecCondition=')]
        self.assertEqual(len(guards), 1, 'missing sessions must not consume crash retries')
        with tempfile.TemporaryDirectory() as tmp:
            command = shlex.split(guards[0].replace('%t', tmp).replace('$$', '$'))
            (Path(tmp) / 'hypr/live').mkdir(parents=True)
            with socket.socket(socket.AF_UNIX) as display, socket.socket(socket.AF_UNIX) as hypr:
                path = str(Path(tmp) / 'wayland-test')
                display.bind(path)
                hypr.bind(str(Path(tmp) / 'hypr/live/.socket.sock'))
                # Another desktop (GNOME, KDE) or a dead Hyprland's leftover
                # environment must not start Bloom; only a live instance does.
                for name, signature, expected in [('', 'live', 1), ('wayland-gone', 'live', 1),
                                                  ('wayland-test', '', 1), ('wayland-test', 'dead', 1),
                                                  ('wayland-test', '../live', 1),
                                                  ('wayland-test', 'live', 0), (path, 'live', 0)]:
                    with self.subTest(display=name, signature=signature):
                        env = dict(os.environ, WAYLAND_DISPLAY=name, HYPRLAND_INSTANCE_SIGNATURE=signature)
                        self.assertEqual(subprocess.run(command, env=env, check=False).returncode, expected)

    @unittest.skipUnless(shutil.which("lua"), "Lua is required to execute the start hook")
    def test_uwsm_session_is_left_to_uwsm(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            calls = base / "calls"
            stub = base / "systemctl"
            stub.write_text(f"#!/bin/sh\necho \"$*\" >> {calls}\n")
            stub.chmod(0o755)
            cgroup = base / "cgroup"
            cgroup.write_text("0::/user.slice/user-1000.slice/user@1000.service/session.slice/wayland-wm@hyprland.desktop.service\n")
            env = dict(os.environ, PATH=str(base) + ":" + os.environ["PATH"], XDG_CONFIG_HOME=str(base),
                       BLOOM_CGROUP_FILE=str(cgroup), WAYLAND_DISPLAY="wayland-new")
            harness = """hl = {
 on = function(event, callback) callback() end,
 exec_cmd = function(command) os.execute(command) end,
 config = function(options) end
}
dofile(arg[1])
"""
            subprocess.run(["lua", "-", str(ROOT / "hypr/bloom.lua")], input=harness, text=True, env=env, check=True)
            self.assertFalse(calls.exists(), "UWSM imports the environment and starts graphical-session.target itself")


    def first_login_run(self, uwsm, pending):
        """The hook from a copied checkout whose bin/bloom only records its arguments."""
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            checkout = base / "check out"
            (checkout / "hypr").mkdir(parents=True)
            (checkout / "bin").mkdir()
            shutil.copy2(ROOT / "hypr/bloom.lua", checkout / "hypr/bloom.lua")
            calls = base / "calls"
            for name in ("bin/bloom", "systemctl"):
                stub = (checkout / name) if name.startswith("bin") else base / name
                stub.write_text(f"#!/bin/sh\necho \"$(basename \"$0\") $*\" >> '{calls}'\n")
                stub.chmod(0o755)
            state = base / "state"
            if pending:
                (state / "bloom").mkdir(parents=True)
                (state / "bloom/first-login-pending").write_text("pending\n")
            cgroup = base / "cgroup"
            cgroup.write_text("0::/user.slice/wayland-wm@hyprland.desktop.service\n" if uwsm else "0::/user.slice\n")
            env = dict(os.environ, PATH=str(base) + ":" + os.environ["PATH"], XDG_CONFIG_HOME=str(base),
                       XDG_STATE_HOME=str(state), BLOOM_CGROUP_FILE=str(cgroup), WAYLAND_DISPLAY="wayland-new")
            harness = """hl = {
 on = function(event, callback) callback() end,
 exec_cmd = function(command) os.execute(command) end,
 config = function(options) end
}
dofile(arg[1])
"""
            subprocess.run(["lua", "-", str(checkout / "hypr/bloom.lua")], input=harness, text=True, env=env, check=True)
            return calls.read_text().splitlines() if calls.exists() else []

    @unittest.skipUnless(shutil.which("lua"), "Lua is required to execute the start hook")
    def test_native_login_runs_first_login_when_pending(self):
        calls = self.first_login_run(uwsm=False, pending=True)
        self.assertEqual(calls[0], "bloom first-login")
        self.assertIn("systemctl --user restart bloom-shell.service", calls)
        self.assertNotIn("bloom first-login", self.first_login_run(uwsm=False, pending=False))

    @unittest.skipUnless(shutil.which("lua"), "Lua is required to execute the start hook")
    def test_uwsm_login_starts_bloom_when_pending(self):
        self.assertEqual(self.first_login_run(uwsm=True, pending=True), ["bloom first-login --start"])
        self.assertEqual(self.first_login_run(uwsm=True, pending=False), [])


if __name__ == '__main__':
    unittest.main()
