#!/usr/bin/env python3
"""tools/sync-bloom-i18n.mjs: Bloom's catalogs are copied, and --check notices drift."""
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SYNC = ROOT / "tools/sync-bloom-i18n.mjs"


class Sync(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="bloom-i18n-test-")
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.bloom = base / "bloom"
        locales = self.bloom / "src/i18n/locales"
        locales.mkdir(parents=True)
        (locales / "en.json").write_text(json.dumps({"ui": {"hello": "Hello"}}))
        (locales / "ru.json").write_text(json.dumps({"ui": {"hello": "Привет"}}))
        subprocess.run(["git", "init", "-q", str(self.bloom)], check=True)
        subprocess.run(["git", "-C", str(self.bloom), "add", "-A"], check=True)
        subprocess.run(["git", "-C", str(self.bloom), "-c", "user.name=t", "-c", "user.email=t@t",
                        "commit", "-qm", "fixture"], check=True)
        self.commit = subprocess.run(["git", "-C", str(self.bloom), "rev-parse", "--short", "HEAD"],
                                     capture_output=True, text=True, check=True).stdout.strip()
        self.out = base / "out"

    def sync(self, *args):
        return subprocess.run(["node", str(SYNC), str(self.bloom), *args, "--out", str(self.out)],
                              capture_output=True, text=True)

    def test_sync_copies_every_catalog_and_records_the_commit(self):
        self.assertEqual(self.sync().returncode, 0)
        self.assertEqual(json.loads((self.out / "locales/ru.json").read_text()), {"ui": {"hello": "Привет"}})
        self.assertEqual(sorted(p.name for p in (self.out / "locales").iterdir()), ["en.json", "ru.json"])
        self.assertEqual((self.out / "SOURCE").read_text().split()[0], self.commit)

    def test_check_passes_in_sync_and_fails_on_drift(self):
        self.sync()
        self.assertEqual(self.sync("--check").returncode, 0)
        (self.bloom / "src/i18n/locales/ru.json").write_text(json.dumps({"ui": {"hello": "Здравствуйте"}}))
        result = self.sync("--check")
        self.assertEqual(result.returncode, 1)
        self.assertIn("ru.json", result.stderr)

    def test_shipped_catalogs_parse(self):
        for path in sorted((ROOT / "shell/i18n").rglob("*.json")):
            json.loads(path.read_text())
        self.assertTrue((ROOT / "shell/i18n/locales/en.json").exists())


if __name__ == "__main__":
    unittest.main()
