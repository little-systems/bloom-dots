"""Behavioral tests of the same writer invoked by QML, in throwaway homes."""
import concurrent.futures
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "shell/services/settings-store.py"
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("settings_store", HELPER)
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)


class SettingsStoreCases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / "settings.json"
        self.base = {"bloom-theme-mode": "dark", "owner-extra": {"keep": True}}
        self.path.write_text(json.dumps(self.base))

    def call(self, changes, base=None):
        result = subprocess.run(["python3", str(HELPER), str(self.path)],
                                input=json.dumps({"changes": changes, "base": self.base if base is None else base}),
                                text=True, capture_output=True, timeout=5, check=True)
        self.assertEqual(result.stderr, "")
        return json.loads(result.stdout)

    def disk(self):
        return json.loads(self.path.read_text())

    def test_concurrent_disjoint_writes_keep_every_change(self):
        def write(index):
            return self.call({"bloom-test-" + str(index): index})
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as workers:
            results = list(workers.map(write, range(24)))
        self.assertTrue(all(result["ok"] for result in results))
        self.assertEqual(self.disk(), {**self.base, **{"bloom-test-" + str(i): i for i in range(24)}})

    def test_conflict_refuses_entire_batch_and_unknown_keys_survive(self):
        self.assertTrue(self.call({"bloom-theme-mode": "light"})["ok"])
        result = self.call({"bloom-theme-mode": "custom", "bloom-weather-enabled": False})
        self.assertFalse(result["ok"])
        self.assertIn("changed elsewhere", result["error"])
        self.assertEqual(self.disk(), {**self.base, "bloom-theme-mode": "light"})

    def test_retry_after_reload_and_identical_write(self):
        self.call({"bloom-theme-mode": "light"})
        result = self.call({"bloom-theme-mode": "custom"}, self.disk())
        self.assertTrue(result["ok"])
        before = self.path.stat().st_mtime_ns
        again = self.call({"bloom-theme-mode": "custom"}, self.base)
        self.assertTrue(again["ok"])
        self.assertEqual(before, self.path.stat().st_mtime_ns)
        self.assertEqual(result["revision"], again["revision"])

    def test_corrupt_and_non_object_are_preserved(self):
        for raw in ["{broken", "[]", '{"bloom-scale":NaN}', '{"bloom-scale":1,"bloom-scale":2}']:
            self.path.write_text(raw)
            self.assertFalse(self.call({"bloom-theme-mode": "light"})["ok"])
            self.assertEqual(self.path.read_text(), raw)

    def test_destination_is_closed_to_settings_document(self):
        other = self.path.parent / "foreign.json"
        result = subprocess.run(["python3", str(HELPER), str(other)],
                                input=json.dumps({"changes": {}, "base": {}}),
                                text=True, capture_output=True, check=True, timeout=5)
        self.assertFalse(json.loads(result.stdout)["ok"])
        self.assertFalse(other.exists())
        self.assertEqual(result.stderr, "")

    def test_type_change_is_a_conflict(self):
        self.path.write_text('{"bloom-theme-mode":"dark","bloom-test-value":false}')
        result = self.call({"bloom-test-value": 1}, {**self.base, "bloom-test-value": 0})
        self.assertFalse(result["ok"])
        self.assertIs(self.disk()["bloom-test-value"], False)

    def test_permission_failure_and_retry(self):
        self.path.parent.chmod(0o500)
        try:
            self.assertFalse(self.call({"bloom-theme-mode": "light"})["ok"])
            self.assertEqual(self.disk(), self.base)
        finally:
            self.path.parent.chmod(0o700)
        self.assertTrue(self.call({"bloom-theme-mode": "light"})["ok"])
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_lock_timeout_and_release(self):
        lock = self.path.parent / ".settings.lock"
        fd = os.open(lock, os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            self.assertFalse(self.call({"bloom-theme-mode": "light"})["ok"])
        finally:
            os.close(fd)
        self.assertTrue(self.call({"bloom-theme-mode": "light"})["ok"])

    def test_symlink_targets_refused(self):
        target = self.path.parent / "foreign.json"
        self.path.rename(target)
        self.path.symlink_to(target)
        self.assertFalse(self.call({"bloom-theme-mode": "light"})["ok"])
        self.assertEqual(json.loads(target.read_text()), self.base)

    def test_noncooperating_edit_during_prepare_is_detected(self):
        original_read = store.read
        count = 0
        def edited(path):
            nonlocal count
            count += 1
            if count == 2:
                self.path.write_text('{"owner-extra":"new edit"}')
            return original_read(path)
        with patch.object(store, "read", side_effect=edited):
            with self.assertRaisesRegex(ValueError, "during save"):
                store.patch(self.path, {"bloom-theme-mode": "light"}, self.base)
        self.assertEqual(self.disk(), {"owner-extra": "new edit"})
        self.assertEqual(list(self.path.parent.glob(".settings-*.tmp")), [])

    def test_full_disk_does_not_replace_settings(self):
        with patch.object(store.os, "fsync", side_effect=OSError("fixture disk full")):
            with self.assertRaises(OSError):
                store.patch(self.path, {"bloom-theme-mode": "light"}, self.base)
        self.assertEqual(self.disk(), self.base)
        self.assertEqual(list(self.path.parent.glob(".settings-*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
