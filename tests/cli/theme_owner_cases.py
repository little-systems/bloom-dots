"""Ownership rules for application theme files, in throwaway homes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "shell/scripts/theme-owner.py"
CSS = ".config/gtk-4.0/gtk.css"
FUZZEL = ".config/fuzzel/fuzzel_theme.ini"


class ThemeOwnerCases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.t = Path(self.temp.name)
        self.home = self.t / "home"
        self.home.mkdir()
        (self.t / "bin").mkdir()
        gsettings = self.t / "bin/gsettings"
        gsettings.write_text(
            "#!/bin/sh\nf=\"$GS_DIR/$3\"\n"
            "if [ \"$1\" = get ]; then cat \"$f\" 2>/dev/null || echo \"'default'\"; else printf '%s\\n' \"$4\" > \"$f\"; fi\n")
        gsettings.chmod(0o755)
        (self.t / "gs").mkdir()
        self.env = dict(os.environ, BLOOM_THEME_HOME=str(self.home), XDG_STATE_HOME=str(self.t / "state"),
                        PATH=f"{self.t / 'bin'}:{os.environ['PATH']}", GS_DIR=str(self.t / "gs"))
        for key in ("XDG_CONFIG_HOME", "XDG_DATA_HOME"):
            self.env.pop(key, None)
        self.ledger = self.t / "state/bloom/app-themes/ownership.json"

    def run_owner(self, *args, env=None, check=True):
        result = subprocess.run(["python3", str(HELPER), *args], env=env or self.env,
                                text=True, capture_output=True, timeout=10)
        if check and result.returncode not in (0, 3):
            self.fail(f"{args} exited {result.returncode}: {result.stderr}")
        return result

    def stage(self, files, env=None, check=True):
        stage = Path(tempfile.mkdtemp(dir=self.t))
        for rel, text in files.items():
            (stage / rel).parent.mkdir(parents=True, exist_ok=True)
            (stage / rel).write_text(text)
        return self.run_owner("commit", str(stage), env=env, check=check)

    def write(self, rel, text, root=None):
        path = (root or self.home) / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_restore_returns_originals_and_removes_files_bloom_created(self):
        self.write(FUZZEL, "owner fuzzel\n")
        self.stage({FUZZEL: "bloom fuzzel\n", CSS: "bloom css\n"})
        self.assertEqual((self.home / FUZZEL).read_text(), "bloom fuzzel\n")
        self.run_owner("restore")
        self.assertEqual((self.home / FUZZEL).read_text(), "owner fuzzel\n")
        self.assertFalse((self.home / CSS).exists())
        self.assertFalse(self.ledger.exists())

    def test_second_apply_keeps_the_first_original(self):
        self.write(FUZZEL, "owner fuzzel\n")
        self.stage({FUZZEL: "bloom one\n"})
        self.stage({FUZZEL: "bloom two\n"})
        self.assertEqual((self.home / FUZZEL).read_text(), "bloom two\n")
        self.run_owner("restore")
        self.assertEqual((self.home / FUZZEL).read_text(), "owner fuzzel\n")

    def test_owner_edit_after_apply_is_preserved_by_apply_and_restore(self):
        self.write(FUZZEL, "owner fuzzel\n")
        self.stage({FUZZEL: "bloom one\n", CSS: "bloom css\n"})
        self.write(FUZZEL, "edited by owner\n")
        result = self.stage({FUZZEL: "bloom two\n", CSS: "bloom css 2\n"})
        self.assertEqual(result.returncode, 3)
        self.assertIn(FUZZEL, result.stdout)
        self.assertEqual((self.home / FUZZEL).read_text(), "edited by owner\n")
        self.assertEqual((self.home / CSS).read_text(), "bloom css 2\n")
        result = self.run_owner("restore")
        self.assertEqual(result.returncode, 3)
        self.assertEqual((self.home / FUZZEL).read_text(), "edited by owner\n")
        self.assertFalse((self.home / CSS).exists())
        kept = list((self.t / "state/bloom/app-themes").rglob("fuzzel_theme.ini"))
        self.assertTrue(any(p.read_text() == "owner fuzzel\n" for p in kept), "the pre-Bloom original stays recoverable")

    def test_owner_deletion_after_apply_is_not_undone(self):
        self.stage({CSS: "bloom css\n"})
        (self.home / CSS).unlink()
        self.assertEqual(self.stage({CSS: "bloom css 2\n"}).returncode, 3)
        self.assertFalse((self.home / CSS).exists())
        self.run_owner("restore")
        self.assertFalse((self.home / CSS).exists())

    def test_symlinked_target_is_never_replaced(self):
        real = self.write("dotfiles/gtk.css", "managed elsewhere\n", self.t)
        (self.home / CSS).parent.mkdir(parents=True)
        (self.home / CSS).symlink_to(real)
        self.assertEqual(self.stage({CSS: "bloom css\n"}).returncode, 3)
        self.assertTrue((self.home / CSS).is_symlink())
        self.assertEqual(real.read_text(), "managed elsewhere\n")

    def test_crash_after_writing_a_file_is_not_mistaken_for_an_owner_edit(self):
        self.write(FUZZEL, "owner fuzzel\n")
        env = dict(self.env, BLOOM_THEME_CUT=f"written:{FUZZEL}")
        stage = Path(tempfile.mkdtemp(dir=self.t))
        self.write(FUZZEL, "bloom one\n", stage)
        cut = self.run_owner("commit", str(stage), env=env, check=False)
        self.assertEqual(cut.returncode, 137)
        self.assertEqual((self.home / FUZZEL).read_text(), "bloom one\n")
        self.assertEqual(self.stage({FUZZEL: "bloom two\n"}).returncode, 0)
        self.assertEqual((self.home / FUZZEL).read_text(), "bloom two\n")
        self.run_owner("restore")
        self.assertEqual((self.home / FUZZEL).read_text(), "owner fuzzel\n")

    def test_legacy_backup_manifest_restores_and_keeps_unknown_new_files(self):
        legacy = self.t / "state/bloom/app-themes"
        self.write(FUZZEL, "owner fuzzel\n", legacy)
        (legacy / "manifest").write_text(FUZZEL + "\n")
        self.write(FUZZEL, "bloom fuzzel\n")
        self.write(CSS, "maybe the owner's\n")
        self.assertEqual(self.run_owner("restore").returncode, 3)
        self.assertEqual((self.home / FUZZEL).read_text(), "owner fuzzel\n")
        self.assertEqual((self.home / CSS).read_text(), "maybe the owner's\n", "unverifiable legacy file left in place")
        self.assertFalse((legacy / "manifest").exists())

    def test_legacy_unlisted_file_is_backed_up_on_the_next_apply(self):
        legacy = self.t / "state/bloom/app-themes"
        legacy.mkdir(parents=True)
        (legacy / "manifest").write_text(FUZZEL + "\n")
        self.write(FUZZEL, "bloom fuzzel\n", legacy)
        settings = ".config/gtk-3.0/settings.ini"
        self.write(settings, "[Settings]\ngtk-font-name=Example 11\n")
        self.stage({settings: "[Settings]\ngtk-font-name=Example 11\ngtk-theme-name=Adwaita\n"})
        self.run_owner("restore")
        self.assertEqual((self.home / settings).read_text(), "[Settings]\ngtk-font-name=Example 11\n")

    def test_xdg_roots_are_used_without_a_theme_home_override(self):
        env = dict(self.env, HOME=str(self.home), XDG_CONFIG_HOME=str(self.t / "cfg"))
        env.pop("BLOOM_THEME_HOME")
        self.stage({CSS: "bloom css\n"}, env=env)
        self.assertEqual((self.t / "cfg/gtk-4.0/gtk.css").read_text(), "bloom css\n")
        self.assertFalse((self.home / CSS).exists())
        self.run_owner("restore", env=env)
        self.assertFalse((self.t / "cfg/gtk-4.0/gtk.css").exists())

    def test_seed_copies_current_targets_for_merging_renderers(self):
        self.write(".config/gtk-3.0/settings.ini", "[Settings]\ngtk-font-name=Example 11\n")
        stage = self.t / "seeded"
        self.run_owner("seed", str(stage))
        self.assertEqual((stage / ".config/gtk-3.0/settings.ini").read_text(), "[Settings]\ngtk-font-name=Example 11\n")
        self.assertFalse((stage / CSS).exists())

    def test_unknown_staged_paths_are_refused_before_any_change(self):
        result = self.stage({CSS: "bloom css\n", ".bashrc": "oops\n"}, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertFalse((self.home / CSS).exists())
        self.assertFalse((self.home / ".bashrc").exists())

    def test_desktop_setting_restored_only_when_bloom_value_is_still_current(self):
        key = "color-scheme"
        (self.t / "gs" / key).write_text("'prefer-light'\n")
        self.run_owner("gsettings", key, "prefer-dark")
        self.assertEqual((self.t / "gs" / key).read_text(), "prefer-dark\n")
        self.run_owner("restore")
        self.assertEqual((self.t / "gs" / key).read_text(), "'prefer-light'\n")
        self.run_owner("gsettings", key, "prefer-dark")
        (self.t / "gs" / key).write_text("'default'\n")
        self.assertEqual(self.run_owner("restore").returncode, 3)
        self.assertEqual((self.t / "gs" / key).read_text(), "'default'\n")

    def test_ledger_is_private_and_records_fingerprints(self):
        self.stage({CSS: "bloom css\n"})
        self.assertEqual(self.ledger.stat().st_mode & 0o777, 0o600)
        doc = json.loads(self.ledger.read_text())
        self.assertEqual(doc["version"], 1)
        self.assertEqual(doc["targets"][CSS]["written"], hashlib.sha256(b"bloom css\n").hexdigest())


if __name__ == "__main__":
    unittest.main(verbosity=1)
