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
                           IMPORT_FAILS=str(int(import_fails)), WAYLAND_DISPLAY="wayland-new")
                harness = """hl = {
 on = function(event, callback)
   assert(event == 'hyprland.start'); callback()
 end,
 exec_cmd = function(command) os.execute(command) end
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

    def test_unit_skips_missing_display_and_accepts_live_socket(self):
        unit = (ROOT / 'systemd/bloom-shell.service').read_text()
        guards = [line.split('=', 1)[1] for line in unit.splitlines() if line.startswith('ExecCondition=')]
        self.assertEqual(len(guards), 1, 'missing Wayland sockets must not consume crash retries')
        with tempfile.TemporaryDirectory() as tmp:
            command = shlex.split(guards[0].replace('%t', tmp).replace('$$', '$'))
            with socket.socket(socket.AF_UNIX) as display:
                path = str(Path(tmp) / 'wayland-test')
                display.bind(path)
                for name, expected in [('', 1), ('wayland-gone', 1), ('wayland-test', 0), (path, 0)]:
                    with self.subTest(display=name):
                        env = dict(os.environ, WAYLAND_DISPLAY=name)
                        self.assertEqual(subprocess.run(command, env=env, check=False).returncode, expected)


if __name__ == '__main__':
    unittest.main()
