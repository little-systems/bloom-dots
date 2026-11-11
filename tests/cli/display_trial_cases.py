"""Display rollback and confirmation faults, with no host compositor access."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
# The worker records trial phases in Bloom's event log; keep this run's events
# out of the real user's state.
_STATE = tempfile.TemporaryDirectory(prefix='bloom-trial-state-')
os.environ['XDG_STATE_HOME'] = _STATE.name
spec = importlib.util.spec_from_file_location('display_trial', ROOT / 'shell/services/display-trial.py')
trial = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trial)


class Backend:
    def __init__(self):
        self.current = trial.observed({'name': 'eDP-1', 'width': 1920, 'height': 1080, 'refreshRate': 60.05, 'scale': 1, 'x': 0, 'y': 0})
        self.original = copy.deepcopy(self.current)
        self.applied = []
        self.reject = False

    def get(self, _):
        return copy.deepcopy(self.current)

    def apply(self, value):
        self.applied.append(copy.deepcopy(value))
        if not self.reject:
            self.current = copy.deepcopy(value)

    def verify(self, value, seconds=1.2):
        return trial.same(self.current, value)


class DisplayTrialCases(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.config = self.root / 'bloom-settings.lua'
        self.legacy = self.root / 'old.json'
        self.directory = self.root / 'trial'
        self.directory.mkdir(mode=0o700)
        self.plan = {'id': 'a' * 32, 'output': 'eDP-1', 'owner': trial.identity(os.getpid()), 'target': trial.target('1280x720@60', 1.25)}
        trial.write_json(self.directory / 'plan.json', self.plan)
        self.backend = Backend()
        self.paths = patch.object(trial.store, 'paths', return_value=(self.config, self.legacy))
        self.paths.start()
        self.addCleanup(self.paths.stop)

    def worker(self, **kwargs):
        return trial.Trial(self.directory, self.backend, owner_alive=lambda _: True, **kwargs)

    def status(self):
        return trial.read_json(self.directory / 'status.json')

    def test_timeout_restores_verified_previous_without_persisting(self):
        worker = self.worker(duration=0)
        worker.run()
        self.assertEqual(self.status()['phase'], 'reverted')
        self.assertEqual(self.backend.current, self.backend.original)
        self.assertFalse(self.config.exists())

    def test_owner_dead_before_apply_has_no_effect(self):
        worker = self.worker()
        worker.owner_alive = lambda _: False
        worker.run()
        self.assertEqual(self.status()['phase'], 'failed')
        self.assertEqual(self.backend.applied, [])

    def test_owner_death_after_apply_reverts(self):
        worker = self.worker()
        worker.prepare()
        worker.owner_alive = lambda _: False
        worker.run()
        self.assertEqual(self.status()['phase'], 'reverted')
        self.assertEqual(self.backend.current, self.backend.original)

    def test_rejected_mode_never_becomes_pending(self):
        self.backend.reject = True
        self.worker().run()
        self.assertEqual(self.status()['phase'], 'reverted')
        self.assertFalse(self.config.exists())

    def test_external_rotation_and_refresh_are_preserved(self):
        for field, value in [('transform', 2), ('refreshRate', 144)]:
            with self.subTest(field=field):
                self.backend.current = copy.deepcopy(self.backend.original)
                worker = self.worker()
                worker.prepare()
                self.backend.current[field] = value
                external = copy.deepcopy(self.backend.current)
                worker.rollback()
                self.assertEqual(self.status()['phase'], 'conflict')
                self.assertEqual(self.backend.current, external)

    def test_unplug_retains_recovery_without_saving(self):
        worker = self.worker()
        worker.prepare()
        self.backend.current = None
        worker.rollback()
        self.assertEqual(self.status()['phase'], 'disconnected')
        self.assertFalse(self.config.exists())

    def test_keep_commits_target_and_preserves_other_preferences(self):
        worker = self.worker()
        worker.prepare()
        current = trial.store.snapshot(self.config, self.legacy)
        trial.store.commit(self.config, self.legacy, current['revision'], {'hypr': {'general': {'gaps_in': 8}}, 'extra': 'owner'})
        worker.keep()
        self.assertEqual(self.status()['phase'], 'kept')
        current = trial.store.snapshot(self.config, self.legacy)
        self.assertEqual(current['state']['hypr']['general']['gaps_in'], 8)
        self.assertEqual(current['state']['extra'], 'owner')
        self.assertEqual(current['state']['monitors'], [trial.line(self.backend.current)])

    def test_conflicting_saved_monitor_preference_is_preserved(self):
        worker = self.worker()
        worker.prepare()
        current = trial.store.snapshot(self.config, self.legacy)
        external = 'hl.monitor({ output = "eDP-1", mode = "1920x1080@75", position = "0x0", scale = 1 })'
        trial.store.commit(self.config, self.legacy, current['revision'], {'monitors': [external]})
        worker.keep()
        self.assertEqual(self.status()['phase'], 'reverted')
        self.assertEqual(trial.store.snapshot(self.config, self.legacy)['state']['monitors'], [external])

    def test_failed_save_before_replace_reverts(self):
        worker = self.worker()
        worker.prepare()
        with patch.object(trial.store, 'commit', side_effect=OSError('disk full')):
            worker.keep()
        self.assertEqual(self.status()['phase'], 'reverted')
        self.assertEqual(self.backend.current, self.backend.original)
        self.assertFalse(self.config.exists())

    def test_save_committed_but_ack_lost_is_reconciled(self):
        worker = self.worker()
        worker.prepare()
        commit = trial.store.commit
        def interrupted(*args):
            commit(*args)
            raise OSError('directory acknowledgement interrupted')
        with patch.object(trial.store, 'commit', side_effect=interrupted):
            worker.keep()
        self.assertEqual(self.status()['phase'], 'kept')
        self.assertEqual(trial.store.snapshot(self.config, self.legacy)['revision'], self.status()['confirmRevision'])

    def test_restart_after_commit_recognizes_durable_keep(self):
        worker = self.worker()
        worker.prepare()
        publish = worker.publish
        def crash(phase, *args, **kwargs):
            if phase == 'kept':
                raise SystemExit('worker killed before acknowledgement')
            publish(phase, *args, **kwargs)
        with patch.object(worker, 'publish', side_effect=crash), self.assertRaises(SystemExit):
            worker.keep()
        self.assertEqual(self.status()['phase'], 'confirming')
        self.worker().run()
        self.assertEqual(self.status()['phase'], 'kept')

    def test_restart_before_commit_reverts(self):
        worker = self.worker()
        worker.prepare()
        worker.publish('confirming', confirmRevision='b' * 64)
        self.worker().run()
        self.assertEqual(self.status()['phase'], 'reverted')
        self.assertEqual(self.backend.current, self.backend.original)

    def test_advanced_profile_refuses_before_apply(self):
        self.backend.current['vrr'] = True
        self.worker().run()
        self.assertEqual(self.status()['phase'], 'failed')
        self.assertEqual(self.backend.applied, [])

    def test_rotated_profile_has_valid_roundtrip(self):
        self.backend.current['transform'] = 1
        worker = self.worker()
        worker.prepare()
        worker.keep()
        self.assertEqual(self.status()['phase'], 'kept')
        self.assertIn('transform = 1', trial.store.snapshot(self.config, self.legacy)['state']['monitors'][0])

    def test_backend_output_and_deadline_are_bounded(self):
        with self.assertRaisesRegex(ValueError, "exceeds limit"):
            trial.command([sys.executable, "-c", "import os; os.write(1, b'x' * 2000000)"])
        with self.assertRaises(trial.subprocess.TimeoutExpired):
            trial.command([sys.executable, "-c", "import time; time.sleep(10)"], .1)
        self.assertEqual(trial.command([sys.executable, "-c", "print('ok')"]), b'ok\n')

    def test_private_runtime_and_pid_identity(self):
        self.assertEqual(trial.identity(os.getpid()), self.plan['owner'])
        with patch.dict(os.environ, {'XDG_RUNTIME_DIR': str(self.root), 'HYPRLAND_INSTANCE_SIGNATURE': 'test'}):
            runtime = trial.root_path(True)
            self.assertEqual(runtime.stat().st_mode & 0o777, 0o700)
            runtime.rmdir()
            runtime.symlink_to(self.directory, target_is_directory=True)
            with self.assertRaises(ValueError):
                trial.root_path(True)


if __name__ == '__main__':
    unittest.main()
