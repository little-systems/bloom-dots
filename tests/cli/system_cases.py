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


STUB = r"""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
root = Path(os.environ['BLOOM_SYSTEM_ROOT'])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (root.parent / 'calls').open('a') as f:
    f.write(json.dumps([name] + args) + '\n')
if os.environ.get('STUB_FAIL') == name:
    sys.exit(1)
units = root / 'etc/systemd/system'
if name == 'systemctl':
    unit = args[-1] if args[-1].endswith('.service') else args[-1] + '.service'
    link = units / 'display-manager.service' if unit == 'sddm.service' else units / 'multi-user.target.wants' / unit
    if 'enable' in args:
        link.parent.mkdir(parents=True, exist_ok=True)
        if not link.is_symlink(): link.symlink_to('/usr/lib/systemd/system/' + unit)
    elif 'disable' in args and link.is_symlink():
        link.unlink()
elif name == 'runuser':
    os.execvp(args[args.index('--') + 1], args[args.index('--') + 1:])
elif name == 'makepkg':
    Path('bloom-shell-deps-1-1-any.pkg.tar.zst').write_text('package')
elif name == 'groupadd':
    with (root / 'etc/group').open('a') as f: f.write(args[-1] + ':x:960:\n')
elif name == 'usermod':
    group = root / 'etc/group'
    lines = [l + (',' if l.split(':')[3] else '') + args[-1] if l.startswith(args[args.index('-aG') + 1] + ':') else l
             for l in group.read_text().splitlines()]
    group.write_text('\n'.join(lines) + '\n')
elif name == 'groupdel':
    group = root / 'etc/group'
    group.write_text(''.join(l + '\n' for l in group.read_text().splitlines() if not l.startswith(args[-1] + ':')))
"""


class Phase(Facts):
    def setUp(self):
        super().setUp()
        (self.root / "etc/group").write_text("root:x:0:\n")
        self.bin = self.root.parent / (self.root.name + "-stubs")
        self.bin.mkdir()
        self.addCleanup(shutil.rmtree, self.bin)
        self.addCleanup(lambda: (self.root.parent / "calls").unlink(missing_ok=True))
        for name in ("systemctl", "pacman", "runuser", "makepkg", "groupadd", "usermod", "groupdel", "chown"):
            path = self.bin / name
            path.write_text(STUB)
            path.chmod(0o755)
        self.env = {"BLOOM_SYSTEM_ROOT": str(self.root), "PATH": f"{self.bin}:{os.environ['PATH']}"}
        self.user = system.choose_user(self.root, None, ask=None)

    def run_stub(self, *args):
        result = subprocess.run([str(a) for a in args], env=dict(os.environ, **self.env), capture_output=True, text=True,
                                cwd=os.getcwd())
        if result.returncode:
            raise system.Failure(f"{args[0]} failed")
        return result

    def calls(self):
        path = self.root.parent / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def kinds(self, steps):
        return [step["kind"] for step in steps]

    def install(self, booted=False, deps=True, **env):
        old = dict(self.env)
        self.env.update(env)
        try:
            steps = system.plan(self.root, self.user, deps=deps)
            system.apply(self.root, self.user, steps, booted=booted, run=self.run_stub)
        finally:
            self.env = old
        return steps

    def test_no_display_manager_installs_and_enables_sddm(self):
        steps = self.install()
        self.assertIn("install-sddm", self.kinds(steps))
        self.assertIn(["pacman", "-S", "--noconfirm", "--needed", "sddm"], self.calls())
        self.assertEqual(system.display_manager(self.root), "sddm")
        dropin = (self.root / "etc/sddm.conf.d/10-bloom.conf").read_text()
        self.assertIn("Current=bloom", dropin)
        self.assertIn("DefaultSession=hyprland.desktop", dropin)
        self.assertTrue((self.root / "usr/share/sddm/themes/bloom/metadata.desktop").is_file())

    def test_packages_are_built_as_the_user_and_installed_by_pacman(self):
        self.install()
        calls = self.calls()
        self.assertIn(["makepkg", "-d", "--noconfirm"], calls)
        built = [c for c in calls if c[:2] == ["runuser", "-u"]]
        self.assertEqual(built[0][2], "dhanush")
        self.assertTrue(any(c[:3] == ["pacman", "-U", "--noconfirm"] for c in calls))

    def test_existing_sddm_gets_the_theme_without_reinstall(self):
        (self.root / "etc/systemd/system/display-manager.service").symlink_to("/usr/lib/systemd/system/sddm.service")
        steps = self.install()
        self.assertNotIn("install-sddm", self.kinds(steps))
        self.assertIn("theme", self.kinds(steps))
        self.assertIn("Current=bloom", (self.root / "etc/sddm.conf.d/10-bloom.conf").read_text())

    def test_other_display_manager_is_left_alone_with_a_note(self):
        (self.root / "etc/systemd/system/display-manager.service").symlink_to("/usr/lib/systemd/system/gdm.service")
        steps = self.install()
        self.assertNotIn("theme", self.kinds(steps))
        self.assertFalse((self.root / "etc/sddm.conf.d").exists())
        notes = [s["label"] for s in steps if s["kind"] == "note"]
        self.assertTrue(any("gdm" in note and "SDDM" in note for note in notes))

    def test_networkd_is_left_alone_and_noted(self):
        self.enable("systemd-networkd.service")
        steps = self.install()
        self.assertNotIn(["systemctl", "enable", "NetworkManager.service"], self.calls())
        notes = " ".join(s["label"] for s in steps if s["kind"] == "note")
        self.assertIn("systemd-networkd", notes)
        self.assertIn("NetworkManager", notes)

    def test_networkmanager_is_enabled_when_nothing_manages_the_network(self):
        self.install()
        self.assertIn(["systemctl", "enable", "NetworkManager.service"], self.calls())
        self.assertIn(["systemctl", "enable", "bluetooth.service"], self.calls())
        self.assertIn(["systemctl", "enable", "power-profiles-daemon.service"], self.calls())

    def test_chroot_enables_without_now(self):
        self.install(booted=False)
        self.assertFalse(any("--now" in call for call in self.calls()))

    def test_booted_never_starts_sddm(self):
        self.install(booted=True)
        calls = self.calls()
        self.assertIn(["systemctl", "enable", "--now", "bluetooth.service"], calls)
        self.assertIn(["systemctl", "enable", "sddm.service"], calls)

    def test_group_and_login_folder(self):
        self.install()
        self.assertIn("bloom:x:960:dhanush", (self.root / "etc/group").read_text())
        folder = self.root / "var/lib/bloom/login"
        self.assertTrue(folder.is_dir())
        self.assertEqual(folder.stat().st_mode & 0o7777, 0o2775)
        self.assertIn(["chown", "root:bloom", str(folder)], self.calls())

    def test_second_plan_is_empty(self):
        self.install()
        self.assertEqual([s for s in system.plan(self.root, self.user, deps=True) if s["kind"] != "note"], [])

    def test_manifest_is_private_and_complete(self):
        self.install()
        manifest = self.root / "var/lib/bloom/system-manifest.json"
        self.assertEqual(manifest.stat().st_mode & 0o777, 0o600)
        doc = json.loads(manifest.read_text())
        self.assertEqual(doc["status"], "complete")
        self.assertEqual(doc["user"], "dhanush")
        self.assertTrue(doc["sddm_installed"])

    def test_failed_package_step_rolls_back_files(self):
        with self.assertRaises(system.Failure):
            self.install(STUB_FAIL="pacman")
        self.assertFalse((self.root / "etc/sddm.conf.d/10-bloom.conf").exists())
        self.assertFalse((self.root / "usr/share/sddm/themes/bloom").exists())

    def test_failure_after_enabling_disables_again(self):
        with self.assertRaises(system.Failure):
            self.install(STUB_FAIL="groupadd")
        self.assertIsNone(system.display_manager(self.root))
        self.assertFalse((self.root / "etc/sddm.conf.d/10-bloom.conf").exists())

    def test_person_sddm_conf_is_never_touched(self):
        (self.root / "etc/sddm.conf").write_text("[Theme]\nCurrent=breeze\n")
        (self.root / "etc/systemd/system/display-manager.service").symlink_to("/usr/lib/systemd/system/sddm.service")
        self.install()
        system.uninstall(self.root, remove_deps=False, run=self.run_stub)
        self.assertEqual((self.root / "etc/sddm.conf").read_text(), "[Theme]\nCurrent=breeze\n")

    def test_uninstall_restores_previous_state(self):
        self.install()
        messages = system.uninstall(self.root, remove_deps=False, run=self.run_stub)
        self.assertIsNone(system.display_manager(self.root))
        self.assertFalse((self.root / "etc/sddm.conf.d/10-bloom.conf").exists())
        self.assertFalse((self.root / "usr/share/sddm/themes/bloom").exists())
        self.assertFalse((self.root / "var/lib/bloom/login").exists())
        self.assertNotIn("bloom:", (self.root / "etc/group").read_text())
        self.assertTrue(any("NetworkManager" in m for m in messages), messages)
        self.assertNotIn(["pacman", "-Rns", "--noconfirm", "bloom-shell-deps"], self.calls())
        doc = json.loads((self.root / "var/lib/bloom/system-manifest.json").read_text())
        self.assertEqual(doc["status"], "uninstalled")

    def test_uninstall_keeps_existing_sddm_enabled(self):
        (self.root / "etc/systemd/system/display-manager.service").symlink_to("/usr/lib/systemd/system/sddm.service")
        self.install()
        system.uninstall(self.root, remove_deps=True, run=self.run_stub)
        self.assertEqual(system.display_manager(self.root), "sddm")
        self.assertIn(["pacman", "-Rns", "--noconfirm", "bloom-shell-deps"], self.calls())


if __name__ == "__main__":
    unittest.main()
