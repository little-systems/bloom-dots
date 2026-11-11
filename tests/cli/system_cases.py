"""System-phase contracts against a fake root: no real packages, users or services."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("bloom_system", ROOT / "tools/bloom_system.py")
system = importlib.util.module_from_spec(spec)
spec.loader.exec_module(system)


class Facts(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bloom-system-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "etc/systemd/system").mkdir(parents=True)
        self.passwd([("root", 0, "/root", "/bin/bash"), ("nobody", 65534, "/", "/usr/bin/nologin"),
                     ("dhanush", 1000, "/home/dhanush", "/bin/bash")])

    def passwd(self, users):
        (self.root / "etc/passwd").write_text("".join(
            f"{name}:x:{uid}:{uid}::{home}:{shell}\n" for name, uid, home, shell in users))

    def enable(self, unit, target="multi-user.target"):
        wants = self.root / "etc/systemd/system" / f"{target}.wants"
        wants.mkdir(exist_ok=True)
        (wants / unit).symlink_to(f"/usr/lib/systemd/system/{unit}")

    def test_regular_users_skip_system_and_nologin_accounts(self):
        self.passwd([("root", 0, "/root", "/bin/bash"), ("svc", 1001, "/srv", "/usr/bin/nologin"),
                     ("off", 1002, "/home/off", "/bin/false"), ("dhanush", 1000, "/home/dhanush", "/bin/bash")])
        self.assertEqual([u["name"] for u in system.regular_users(self.root)], ["dhanush"])

    def test_one_user_is_chosen_without_asking(self):
        user = system.choose_user(self.root, None, ask=None)
        self.assertEqual((user["name"], user["home"]), ("dhanush", "/home/dhanush"))

    def test_several_users_without_a_terminal_name_the_flag(self):
        self.passwd([("a", 1000, "/home/a", "/bin/bash"), ("b", 1001, "/home/b", "/bin/zsh")])
        with self.assertRaises(system.Failure) as caught:
            system.choose_user(self.root, None, ask=None)
        self.assertIn("--user", str(caught.exception))
        self.assertEqual(system.choose_user(self.root, None, ask=lambda users: 1)["name"], "b")

    def test_requested_user_must_exist(self):
        self.assertEqual(system.choose_user(self.root, "dhanush", ask=None)["name"], "dhanush")
        with self.assertRaises(system.Failure):
            system.choose_user(self.root, "nobody", ask=None)

    def test_no_regular_user_is_explained(self):
        self.passwd([("root", 0, "/root", "/bin/bash")])
        with self.assertRaises(system.Failure) as caught:
            system.choose_user(self.root, None, ask=None)
        self.assertIn("create", str(caught.exception))

    def test_display_manager_is_read_from_the_link(self):
        self.assertIsNone(system.display_manager(self.root))
        (self.root / "etc/systemd/system/display-manager.service").symlink_to("/usr/lib/systemd/system/sddm.service")
        self.assertEqual(system.display_manager(self.root), "sddm")

    def test_network_services_are_detected(self):
        self.assertEqual(system.enabled_network(self.root), [])
        self.enable("systemd-networkd.service")
        self.enable("iwd.service")
        self.assertEqual(system.enabled_network(self.root), ["systemd-networkd", "iwd"])


if __name__ == "__main__":
    unittest.main()
