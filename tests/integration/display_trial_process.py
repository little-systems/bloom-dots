"""Actual Settings -> detached watchdog process boundary, fake hardware only."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def wait_for(predicate, name, seconds=12):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(.05)
    raise AssertionError('timed out: ' + name)


def scenario(action):
    with tempfile.TemporaryDirectory(prefix='bloom-display-process-') as temporary:
        base = Path(temporary)
        harness = base / 'harness'
        harness.mkdir()
        for name in ('services', 'common', 'modules', 'settings', 'scripts'):
            shutil.copytree(ROOT / 'shell' / name, harness / name, ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copyfile(ROOT / 'tests/integration/display-trial-harness.qml', harness / 'shell.qml')
        for name in ('config', 'state', 'runtime', 'home', 'bin'):
            (base / name).mkdir(mode=0o700)
        (base / 'config/bloom').mkdir()
        (base / 'config/bloom/settings.json').write_text('{"bloom-weather-enabled":false}')
        original = {'name': 'eDP-1', 'width': 1920, 'height': 1080, 'refreshRate': 60.05, 'scale': 1, 'x': 0, 'y': 0, 'transform': 0}
        (base / 'monitor.json').write_text(json.dumps(original))
        fake_hypr = '''#!/usr/bin/env python3
import json, os, pathlib, re, sys
path = pathlib.Path(os.environ['BLOOM_DISPLAY_FAKE']) / 'monitor.json'
if sys.argv[1] in ('monitors', '-j'):
    print(json.dumps([json.loads(path.read_text())]))
elif sys.argv[1] == 'getoption':
    print('int: 4')
elif sys.argv[1] == 'eval':
    value = json.loads(path.read_text())
    line = sys.argv[2]
    mode = re.search(r'mode = "([0-9]+)x([0-9]+)@([0-9.]+)"', line)
    scale = re.search(r'scale = ([0-9.]+)', line)
    if mode and scale:
        value.update(width=int(mode[1]), height=int(mode[2]), refreshRate=float(mode[3]), scale=float(scale[1]))
        temp = path.with_suffix('.new')
        temp.write_text(json.dumps(value))
        temp.replace(path)
    print('ok')
else:
    print('[]')
'''
        # Exact production worker runs in an independent session. This fake
        # launcher replaces systemd only; it never reaches the user's manager.
        fake_systemd = '''#!/usr/bin/env python3
import os, pathlib, subprocess, sys
args = sys.argv[1:]
index = next(i for i, arg in enumerate(args) if not arg.startswith('--'))
worker = subprocess.Popen(args[index:], start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
(pathlib.Path(os.environ['BLOOM_DISPLAY_FAKE']) / 'worker.pid').write_text(str(worker.pid))
'''
        for name, source in [('hyprctl', fake_hypr), ('systemd-run', fake_systemd)]:
            path = base / 'bin' / name
            path.write_text(source)
            path.chmod(0o700)
        env = {**os.environ, 'HOME': str(base / 'home'), 'XDG_CONFIG_HOME': str(base / 'config'), 'XDG_STATE_HOME': str(base / 'state'), 'XDG_RUNTIME_DIR': str(base / 'runtime'), 'HYPRLAND_INSTANCE_SIGNATURE': 'display-fixture', 'QT_QPA_PLATFORM': 'offscreen', 'BLOOM_DISPLAY_FAKE': str(base), 'BLOOM_DISPLAY_TEST_ACTION': action, 'PATH': str(base / 'bin') + ':' + os.environ['PATH'], 'BLOOM_CHECKUPDATES': str(base / 'no-updates')}
        env.pop('WAYLAND_DISPLAY', None)
        with (base / 'qs.log').open('w') as log:
            process = subprocess.Popen(['qs', '--no-color', '-p', str(harness)], env=env, stdout=log, stderr=log)
            try:
                def status():
                    paths = list((base / 'runtime').glob('bloom-display-trials/*/*/status.json'))
                    return json.loads(paths[0].read_text()) if paths else {}
                wait_for(lambda: status().get('phase') in ('pending', 'kept'), 'verified mode trial')
                if action == 'keep':
                    wait_for(lambda: status().get('phase') == 'kept', 'acknowledged durable Keep')
                    source = (base / 'config/hypr/custom/bloom-settings.lua').read_text()
                    assert '1280x720@60' in source and 'scale = 1.25' in source
                else:
                    process.kill()
                    process.wait(timeout=3)
                    wait_for(lambda: status().get('phase') == 'reverted', 'watchdog rollback after Settings SIGKILL')
                    assert json.loads((base / 'monitor.json').read_text())['width'] == original['width']
                    assert not (base / 'config/hypr/custom/bloom-settings.lua').exists()
                print('ok - real Settings process ' + ('confirms durable Keep' if action == 'keep' else 'can die without losing independent rollback'))
            except Exception:
                print((base / 'qs.log').read_text(), file=sys.stderr)
                raise
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=5)
                pid = base / 'worker.pid'
                if pid.exists():
                    try:
                        os.kill(int(pid.read_text()), 15)
                    except ProcessLookupError:
                        pass
                time.sleep(.2)


scenario('crash')
scenario('keep')
