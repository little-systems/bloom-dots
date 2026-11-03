import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Soak(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="bloom-soak-test-")
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.env = dict(os.environ, PATH=str(self.path) + ":" + os.environ["PATH"],
                        SOAK_FIXTURE=str(self.path), SOAK_PID=str(os.getpid()))
        source = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root=Path(os.environ['SOAK_FIXTURE'])
args=sys.argv[1:]
with (root/'calls').open('a') as stream: stream.write(json.dumps([Path(sys.argv[0]).name]+args)+'\\n')
state=root/'visible'
visible=state.read_text()=='true' if state.exists() else True
name=Path(sys.argv[0]).name
if name=='systemctl':
    count=root/'pid-count'
    n=int(count.read_text()) if count.exists() else 0
    count.write_text(str(n+1))
    print(str(int(os.environ['SOAK_PID'])+1) if n and os.environ.get('SOAK_RESTART') else os.environ['SOAK_PID'])
elif name=='journalctl':
    if '--show-cursor' in args: print('-- cursor: fixture')
    elif os.environ.get('SOAK_WARNING'): print('WARN scene: fixture warning')
else:
    target,method=args[4:6]
    if target=='shell': print('pong')
    elif target=='lock': print('{"locked":false}')
    elif target=='settings': print('["notch","dock","launcher"]')
    elif method=='state': print(json.dumps({'opened':visible} if target=='launcher' else [{'userVisible':visible}]))
    else:
        state.write_text(args[-1] if method=='setVisible' else str(not visible).lower())
        print('ok')
'''
        for name in ("qs", "systemctl", "journalctl"):
            path = self.path / name
            path.write_text(source)
            path.chmod(0o755)

    def invoke(self, surface="dock", duration="0.1", **extra):
        return subprocess.run([str(ROOT / "bin/bloom"), "dev", "soak", surface,
                               "--duration", duration, "--interval", "0.01", "--warmup", "0"],
                              env=dict(self.env, **extra), capture_output=True, text=True)

    def test_cycles_and_restores_original_visibility(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertGreater(json.loads(result.stdout)["cycles"], 0)
        self.assertEqual((self.path / "visible").read_text(), "true")
        self.assertIn('["qs", "-c", "bloom", "ipc", "call", "dock", "setVisible", "false"]',
                      (self.path / "calls").read_text())

    def test_popup_returns_to_its_original_open_state(self):
        result = self.invoke("launcher")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.path / "visible").read_text(), "true")

    def test_new_warnings_fail_the_soak_and_restore_visibility(self):
        result = self.invoke(SOAK_WARNING="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture warning", result.stderr)
        self.assertEqual((self.path / "visible").read_text(), "true")

    def test_service_restart_fails_before_the_next_cycle(self):
        result = self.invoke(SOAK_RESTART="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("restarted", result.stderr)
        self.assertEqual((self.path / "visible").read_text(), "true")

    def test_real_resident_memory_growth_fails_the_soak(self):
        def grow():
            deadline = time.monotonic() + 5
            while not (self.path / "visible").exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.buffer = bytearray(32 * 1024 * 1024)

        thread = threading.Thread(target=grow)
        thread.start()
        try:
            result = self.invoke(duration="1.5")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("resident memory grew", result.stderr)
            self.assertEqual((self.path / "visible").read_text(), "true")
        finally:
            thread.join()
            self.buffer = None


if __name__ == '__main__':
    unittest.main(verbosity=2)
