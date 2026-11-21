import importlib.util
import json
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("compositor_store", ROOT / "shell/services/compositor-store.py")
store = importlib.util.module_from_spec(spec)
spec.loader.exec_module(store)


class CompositorStoreCases(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / "bloom-settings.lua"
        self.legacy = self.root / "hypr-settings.json"
        self.state = {"hypr": {"general": {"gaps_in": 4}}, "monitors": [], "rules": list(store.RULES), "owner-extra": "preserve"}

    def old_files(self):
        self.legacy.write_text(json.dumps(self.state))
        self.config.write_bytes(store.legacy_source(self.state))
        return store.snapshot(self.config, self.legacy)

    def test_read_is_readonly_even_before_first_save(self):
        result = store.snapshot(self.config, self.legacy)
        self.assertEqual(result["state"]["hypr"], {})
        self.assertEqual(list(self.root.iterdir()), [])

    def test_pristine_installer_template_can_be_saved_but_owner_edits_are_refused(self):
        template = (ROOT / "hypr/custom/bloom-settings.lua").read_bytes()
        self.config.write_bytes(template)
        before = store.snapshot(self.config, self.legacy)
        self.assertEqual(self.config.read_bytes(), template)
        self.config.write_bytes(template + b"-- owner edit\n")
        with self.assertRaisesRegex(ValueError, "differs"):
            store.snapshot(self.config, self.legacy)
        self.config.write_bytes(template)
        saved = store.commit(self.config, self.legacy, before["revision"], {"hypr": {"general": {"gaps_in": 8}}})
        self.assertEqual(saved["state"]["hypr"]["general"]["gaps_in"], 8)

    # A reinstall writes a fresh template while the previous install's state
    # folder still holds the old JSON; the template is Bloom's own, so it starts clean.
    def test_fresh_template_beside_an_old_json_starts_clean(self):
        template = (ROOT / "hypr/custom/bloom-settings.lua").read_bytes()
        self.config.write_bytes(template)
        self.legacy.write_text(json.dumps(self.state))
        before = store.snapshot(self.config, self.legacy)
        self.assertEqual(before["state"]["hypr"], {})
        self.assertEqual(before["state"]["monitors"], [])
        saved = store.commit(self.config, self.legacy, before["revision"], {"hypr": {"general": {"gaps_in": 8}}})
        self.assertEqual(saved["state"]["hypr"], {"general": {"gaps_in": 8}})

    def test_legacy_migration_and_noop_save(self):
        before = self.old_files()
        old_json = self.legacy.read_bytes()
        result = store.commit(self.config, self.legacy, before["revision"], {"hypr": {"general": {"gaps_in": 8}}})
        self.assertEqual(self.legacy.read_bytes(), old_json)
        self.assertEqual(result["state"]["owner-extra"], "preserve")
        self.assertEqual(result["state"]["hypr"]["general"]["gaps_in"], 8)
        self.assertEqual(result["previous"], before["revision"])
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        backup = self.config.parent / ".bloom-settings-history" / (before["revision"] + ".json")
        self.assertEqual(json.loads(backup.read_text())["source"].encode(), before["source"])
        mtime = self.config.stat().st_mtime_ns
        again = store.commit(self.config, self.legacy, result["revision"], {})
        self.assertEqual(again["revision"], result["revision"])
        self.assertEqual(self.config.stat().st_mtime_ns, mtime)

    # Hyprland blurs behind every layer pixel more opaque than ignore_alpha.
    # Layers with card shadows (up to 50% opaque) need a threshold above them
    # and below the cards' 60% opacity floor, or the blur ends in a hard band
    # where a shadow fades; their windows fade through Hyprland with the card
    # solid, so the blur fades with it. The rest keep 0.2 so their own fades
    # stay blurred: the dock fades its pill, menus and previews separately.
    def test_layer_blur_skips_shadows_but_not_cards(self):
        def threshold(namespace):
            matches = [line for line in store.RULES if re.search(line.split('namespace = "')[1].split('"')[0], "bloom:" + namespace)]
            self.assertEqual(len(matches), 1, namespace)
            return float(matches[0].split("ignore_alpha = ")[1].split(" ")[0])
        for namespace in ("launcher", "session", "cheatsheet", "overview", "polkit", "wallpaper-picker", "switcher"):
            self.assertGreater(threshold(namespace), 0.5, namespace)
            self.assertLess(threshold(namespace), 0.6, namespace)
        for namespace in ("notch", "dock", "osd-left", "osd-right", "osk"):
            self.assertEqual(threshold(namespace), 0.2, namespace)

    # Files saved with an earlier rule still load; the next save writes the
    # current rules and keeps the old file in history.
    def test_old_blur_rules_are_read_and_upgraded_on_save(self):
        for old in store.LEGACY_RULES:
            with self.subTest(old=old):
                for path in self.root.iterdir():
                    if path.is_file():
                        path.unlink()
                source = store.encode(dict(self.state, rules=[old]), "")
                self.config.write_bytes(source)
                before = store.snapshot(self.config, self.legacy)
                self.assertEqual(before["state"]["rules"], list(store.RULES))
                self.assertEqual(self.config.read_bytes(), source)
                saved = store.commit(self.config, self.legacy, before["revision"], {})
                written = self.config.read_bytes().decode()
                self.assertEqual(saved["state"]["rules"], list(store.RULES))
                for line in store.RULES:
                    self.assertIn(line, written)
                self.assertNotIn(old, written)
                backup = self.config.parent / ".bloom-settings-history" / (before["revision"] + ".json")
                self.assertEqual(json.loads(backup.read_text())["source"].encode(), source)

    def test_canonical_document_has_one_source_of_truth(self):
        first = store.snapshot(self.config, self.legacy)
        result = store.commit(self.config, self.legacy, first["revision"], self.state)
        self.legacy.write_text('{broken retired file')
        loaded = store.snapshot(self.config, self.legacy)
        self.assertEqual(loaded["state"], result["state"])
        self.assertEqual(loaded["revision"], result["revision"])

    def test_owner_edit_and_stale_revision_are_refused(self):
        first = self.old_files()
        result = store.commit(self.config, self.legacy, first["revision"], {"hypr": {"general": {"gaps_in": 9}}})
        with self.assertRaisesRegex(ValueError, "elsewhere"):
            store.commit(self.config, self.legacy, first["revision"], self.state)
        self.config.write_bytes(result["source"] + b"-- owner edit\n")
        expected = self.config.read_bytes()
        with self.assertRaisesRegex(ValueError, "edited"):
            store.commit(self.config, self.legacy, result["revision"], self.state)
        self.assertEqual(self.config.read_bytes(), expected)

    def test_inconsistent_legacy_pair_is_not_overwritten(self):
        self.old_files()
        self.config.write_text("-- hand written configuration\n")
        with self.assertRaisesRegex(ValueError, "differs"):
            store.snapshot(self.config, self.legacy)
        self.assertEqual(self.config.read_text(), "-- hand written configuration\n")

    def test_failure_after_backup_keeps_old_config_and_retry_works(self):
        first = self.old_files()
        original = store.atomic_write
        def fail_config(path, data):
            if path == self.config:
                raise OSError("fixture disk full")
            return original(path, data)
        with patch.object(store, "atomic_write", side_effect=fail_config):
            with self.assertRaises(OSError):
                store.commit(self.config, self.legacy, first["revision"], {"hypr": {}})
        self.assertEqual(self.config.read_bytes(), first["source"])
        result = store.commit(self.config, self.legacy, first["revision"], {"hypr": {}})
        self.assertEqual(result["state"]["hypr"], {})

    def test_history_edit_and_redirect_are_refused(self):
        first = self.old_files()
        history = self.root / ".bloom-settings-history"
        history.mkdir(mode=0o700)
        backup = history / (first["revision"] + ".json")
        backup.write_text("owner-edited backup")
        with self.assertRaisesRegex(ValueError, "snapshot was changed"):
            store.commit(self.config, self.legacy, first["revision"], {})
        self.assertEqual(self.config.read_bytes(), first["source"])
        backup.unlink()
        history.rmdir()
        target = self.root / "foreign"
        target.mkdir()
        history.symlink_to(target, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "unsafe"):
            store.commit(self.config, self.legacy, first["revision"], {})
        self.assertEqual(list(target.iterdir()), [])

    def test_generation_matches_existing_qml_serializer(self):
        script = "const fs=require('fs'),vm=require('vm');const c=vm.createContext({});vm.runInContext(fs.readFileSync(process.argv[1],'utf8'),c);console.log(JSON.stringify(c.hyprFile({general:{gaps_in:4},input:{touchpad:{natural_scroll:false}}},c.layerRules())));"
        expected = json.loads(subprocess.check_output(["node", "-e", script, str(ROOT / "shell/settings/system.js")], text=True))
        state = {"hypr": {"general": {"gaps_in": 4}, "input": {"touchpad": {"natural_scroll": False}}}, "monitors": [], "rules": list(store.RULES)}
        self.assertEqual(store.legacy_source(state).decode(), expected)

    def test_invalid_typed_config_is_refused(self):
        first = self.old_files()
        for changes in [{"hypr": {"bad.key": 1}}, {"rules": ['os.execute("never")']}, {"monitors": ['hl.monitor({}); os.execute("never")']}, {"hypr": {"x": 10 ** 100}}]:
            with self.assertRaises(ValueError):
                store.commit(self.config, self.legacy, first["revision"], changes)
            self.assertEqual(self.config.read_bytes(), first["source"])


if __name__ == "__main__":
    unittest.main()
