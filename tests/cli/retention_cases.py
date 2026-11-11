"""Bounded leftovers: crash temporaries, compositor history and display trials."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / "shell/services" / file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


retention = load("bloom_retention", "bloom_retention.py")
compositor = load("compositor_store", "compositor-store.py")


def age(path, seconds):
    then = time.time() - seconds
    os.utime(path, (then, then), follow_symlinks=False)


class RetentionCases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.dir = Path(self.temp.name)

    def test_only_old_matching_temporaries_are_removed(self):
        old = self.dir / ".settings-abc.tmp"
        fresh = self.dir / ".settings-new.tmp"
        other = self.dir / "settings.json"
        for path in (old, fresh, other):
            path.write_text("x")
        age(old, 7200)
        age(other, 7200)
        retention.prune_stale(self.dir, (".settings-*.tmp",))
        self.assertFalse(old.exists())
        self.assertTrue(fresh.exists(), "a write in progress must survive")
        self.assertTrue(other.exists())

    def test_symlinks_are_never_followed_or_removed(self):
        target = self.dir / "precious"
        target.write_text("keep")
        link = self.dir / ".settings-link.tmp"
        link.symlink_to(target)
        age(link, 7200)
        retention.prune_stale(self.dir, (".settings-*.tmp",))
        self.assertTrue(link.is_symlink())
        self.assertEqual(target.read_text(), "keep")

    def test_stale_stage_directories_are_removed(self):
        stage = self.dir / ".stage-abc123"
        (stage / ".config").mkdir(parents=True)
        (stage / ".config/file").write_text("x")
        age(stage, 7200)
        retention.prune_stale(self.dir, (".stage-*",))
        self.assertFalse(stage.exists())

    def test_history_keeps_newest_snapshots(self):
        for n in range(14):
            path = self.dir / f"{n:02d}.json"
            path.write_text("{}")
            age(path, 1000 - n)
        retention.prune_history(self.dir, keep=10)
        self.assertEqual(sorted(p.name for p in self.dir.iterdir()), [f"{n:02d}.json" for n in range(4, 14)])

    def test_compositor_commit_bounds_its_history(self):
        config = self.dir / "custom/bloom-settings.lua"
        config.parent.mkdir()
        legacy = self.dir / "legacy.json"
        snap = compositor.snapshot(config, legacy)
        history = config.parent / ".bloom-settings-history"
        for n in range(15):
            snap = compositor.commit(config, legacy, snap["revision"], {"hypr": {"bloom_test": n}})
        self.assertLessEqual(len(list(history.glob("*.json"))), retention.HISTORY_KEEP)
        previous = compositor.snapshot(config, legacy)["previous"]
        self.assertTrue((history / f"{previous}.json").exists(), "the current document's previous snapshot is kept")


class TrialRetentionCases(unittest.TestCase):
    def test_finished_trial_records_are_bounded_and_pending_ones_kept(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for n in range(14):
                trial = root / f"{n:032x}"
                trial.mkdir(mode=0o700)
                phase = "pending" if n == 0 else "kept"
                (trial / "status.json").write_text(json.dumps({"phase": phase}))
                age(trial, 1000 - n)
            retention.prune_trials(root, keep=10)
            left = sorted(p.name for p in root.iterdir())
            self.assertIn(f"{0:032x}", left, "an unfinished trial is never pruned")
            self.assertEqual(len(left), 11)


if __name__ == "__main__":
    unittest.main(verbosity=1)
