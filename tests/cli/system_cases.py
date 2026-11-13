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
if name == 'pacman' and args[0] == '-T':
    sys.exit(0 if os.environ.get('STUB_PROVIDED') else 127)
if name == 'pacman' and args[0] == '-U':
    # Like pacman: the package is now in the local database.
    (root / 'var/lib/pacman/local' / Path(args[-1]).name.rsplit('-', 1)[0]).mkdir(parents=True, exist_ok=True)
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
    if os.environ.get('STUB_FAIL') == 'makepkg-aur' and 'bloom-shell-deps' not in Path('PKGBUILD').read_text():
        sys.exit(1)
    built = 'bloom-shell-deps' if 'bloom-shell-deps' in Path('PKGBUILD').read_text() else Path.cwd().name
    Path(built + '-1-1-any.pkg.tar.zst').write_text('package')
elif name == 'git' and args[0] == 'clone':
    target = Path(args[-1]); target.mkdir(parents=True)
    (target / 'PKGBUILD').write_text('pkgname=' + target.name + chr(10))
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
        for name in ("systemctl", "pacman", "runuser", "makepkg", "groupadd", "usermod", "groupdel", "chown", "git"):
            path = self.bin / name
            path.write_text(STUB)
            path.chmod(0o755)
        self.env = {"BLOOM_SYSTEM_ROOT": str(self.root), "PATH": f"{self.bin}:{os.environ['PATH']}"}
        # Tests never reach the AUR: it is unreachable unless a test says otherwise.
        original = system.aur_version
        self.addCleanup(setattr, system, "aur_version", original)
        system.aur_version = lambda name: None
        self.user = system.choose_user(self.root, None, ask=None)

    def run_stub(self, *args, check=True):
        result = subprocess.run([str(a) for a in args], env=dict(os.environ, **self.env), capture_output=True, text=True,
                                cwd=os.getcwd())
        if check and result.returncode:
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
        dropin = (self.root / system.DROPIN).read_text()
        self.assertIn("Current=bloom", dropin)
        self.assertIn("DefaultSession=hyprland.desktop", dropin)
        # The greeter reads the login state as data, so it may read files.
        self.assertIn("GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1", dropin)
        self.assertTrue((self.root / "usr/share/sddm/themes/bloom/metadata.desktop").is_file())

    def test_packages_are_built_as_the_user_and_installed_by_pacman(self):
        self.install()
        calls = self.calls()
        self.assertIn(["makepkg", "-d", "--noconfirm"], calls)
        tools = ["pacman", "-S", "--needed", "--noconfirm", "--asdeps", "fakeroot", "debugedit", "binutils"]
        self.assertLess(calls.index(tools), calls.index(["makepkg", "-d", "--noconfirm"]), "a bare system can't build")
        built = [c for c in calls if c[:2] == ["runuser", "-u"]]
        self.assertEqual(built[0][2], "dhanush")
        self.assertTrue(any(c[:3] == ["pacman", "-U", "--noconfirm"] for c in calls))

    def test_fresh_system_gets_the_right_providers_not_the_first_listed(self):
        self.install()
        calls = self.calls()
        providers = ["pacman", "-S", "--needed", "--noconfirm", "--asdeps", "pipewire-jack", "tesseract-data-eng", "noto-fonts"]
        self.assertIn(providers, calls)
        upgrade = next(c for c in calls if c[:2] == ["pacman", "-U"])
        self.assertLess(calls.index(providers), calls.index(upgrade))

    def test_existing_providers_are_kept(self):
        self.install(STUB_PROVIDED="1")
        self.assertFalse([c for c in self.calls() if "pipewire-jack" in c])

    def test_existing_sddm_gets_the_theme_without_reinstall(self):
        (self.root / "etc/systemd/system/display-manager.service").symlink_to("/usr/lib/systemd/system/sddm.service")
        steps = self.install()
        self.assertNotIn("install-sddm", self.kinds(steps))
        self.assertIn("theme", self.kinds(steps))
        self.assertIn("Current=bloom", (self.root / system.DROPIN).read_text())

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
        self.assertIn("bloom-login:x:960:dhanush", (self.root / "etc/group").read_text())
        folder = self.root / "var/lib/bloom/login"
        self.assertTrue(folder.is_dir())
        self.assertEqual(folder.stat().st_mode & 0o7777, 0o2775)
        self.assertIn(["chown", "root:bloom-login", str(folder)], self.calls())

    def test_without_ii_the_default_apps_are_installed_once(self):
        steps = self.install()
        self.assertIn("apps", self.kinds(steps))
        self.assertIn(["pacman", "-S", "--noconfirm", "--needed", *system.APPS], self.calls())
        # Removing an app later is the user's choice; an update never brings it back.
        self.assertNotIn("apps", self.kinds(system.plan(self.root, self.user, deps=True)))

    def test_installed_apps_are_not_installed_again(self):
        local = self.root / "var/lib/pacman/local"
        for name in system.APPS[:-1]:
            (local / f"{name}-1.0-1").mkdir(parents=True)
        steps = system.plan(self.root, self.user, deps=True)
        self.assertEqual([s["packages"] for s in steps if s["kind"] == "apps"], [list(system.APPS[-1:])])

    def dependency(self, name):
        entry = self.root / "var/lib/pacman/local" / f"{name}-1.0-1"
        entry.mkdir(parents=True)
        (entry / "desc").write_text(f"%NAME%\n{name}\n\n%REASON%\n1\n\n")

    # An app another package pulled in would go when that package goes
    # (pacman -Rns): Bloom keeps it as the user's own app instead.
    def test_default_apps_that_came_as_dependencies_are_kept(self):
        for name in system.APPS:
            self.dependency(name) if name == "kitty" else (self.root / "var/lib/pacman/local" / f"{name}-1.0-1").mkdir(parents=True)
        steps = self.install()
        apps = [s for s in steps if s["kind"] == "apps"]
        self.assertEqual([(s["packages"], s["adopt"]) for s in apps], [([], ["kitty"])])
        self.assertIn(["pacman", "-D", "--asexplicit", "kitty"], self.calls())
        self.assertFalse([c for c in self.calls() if c[:2] == ["pacman", "-S"] and "kitty" in c])

    def test_kept_apps_are_named_in_plain_words(self):
        self.install()
        self.dependency("kitty")
        label = next(s["label"] for s in system.plan(self.root, self.user, deps=True) if s["kind"] == "apps")
        self.assertEqual(label, "Keep kitty as your own app (it came with another package)")
        self.dependency("mpv")
        label = next(s["label"] for s in system.plan(self.root, self.user, deps=True) if s["kind"] == "apps")
        self.assertEqual(label, "Keep kitty and mpv as your own apps (they came with other packages)")

    def test_default_apps_are_kept_on_later_runs_too(self):
        self.install()
        self.dependency("kitty")
        steps = system.plan(self.root, self.user, deps=True)
        self.assertEqual([(s["packages"], s["adopt"]) for s in steps if s["kind"] == "apps"], [([], ["kitty"])])

    def test_shell_dependencies_include_fastfetch(self):
        pkgbuild = (ROOT / "packaging/bloom-shell-deps/PKGBUILD").read_text().split("optdepends")[0]
        self.assertIn("'fastfetch'", pkgbuild)

    # Oh My Posh (Bloom's prompt) is only in the AUR: built as the user, installed by pacman.
    def test_oh_my_posh_is_built_from_the_aur_as_the_user(self):
        system.aur_version = lambda name: "1-1"
        steps = self.install()
        self.assertIn("aur", self.kinds(steps))
        calls = self.calls()
        clone = next(c for c in calls if c[0] == "git")
        self.assertIn("https://aur.archlinux.org/oh-my-posh-bin.git", clone)
        self.assertTrue(any(c[:3] == ["runuser", "-u", "dhanush"] and "makepkg" in c for c in calls))
        self.assertTrue(any(c[:2] == ["pacman", "-U"] and "oh-my-posh-bin-1-1-any.pkg.tar.zst" in c[-1] for c in calls))

    def test_installed_oh_my_posh_is_rebuilt_only_when_the_aur_has_a_newer_one(self):
        (self.root / "var/lib/pacman/local/oh-my-posh-bin-1-1").mkdir(parents=True)
        system.aur_version = lambda name: "1-1"
        self.assertNotIn("aur", self.kinds(system.plan(self.root, self.user, deps=True)))
        system.aur_version = lambda name: "2-1"
        steps = [s for s in system.plan(self.root, self.user, deps=True) if s["kind"] == "aur"]
        self.assertEqual(len(steps), 1)
        self.assertIn("Update", steps[0]["label"])
        system.aur_version = lambda name: None
        self.assertNotIn("aur", self.kinds(system.plan(self.root, self.user, deps=True)))

    def test_an_aur_failure_doesnt_undo_the_rest(self):
        system.aur_version = lambda name: "1-1"
        steps = self.install(STUB_FAIL="makepkg-aur")
        self.assertTrue((self.root / system.DROPIN).exists())
        doc = json.loads((self.root / system.MANIFEST).read_text())
        self.assertEqual(doc["status"], "complete")
        self.assertIn("oh-my-posh-bin", doc.get("aur_failed", []))
        self.assertIn("aur", self.kinds(steps))

    def test_shell_dependencies_include_a_keyring(self):
        # The AI key is stored with secret-tool, which needs a Secret Service.
        pkgbuild = (ROOT / "packaging/bloom-shell-deps/PKGBUILD").read_text().split("optdepends")[0]
        self.assertIn("'gnome-keyring'", pkgbuild)
        self.assertIn("'libsecret'", pkgbuild)

    def test_shell_dependencies_include_the_pulse_server(self):
        # Bloom's audio events use pactl, which needs PipeWire's Pulse server.
        pkgbuild = (ROOT / "packaging/bloom-shell-deps/PKGBUILD").read_text()
        self.assertIn("'pipewire-pulse'", pkgbuild)

    # Stock Arch shells don't have ~/.local/bin on PATH.
    def test_bloom_command_is_on_every_path(self):
        self.install()
        launcher = self.root / system.LAUNCHER
        self.assertEqual(launcher.stat().st_mode & 0o777, 0o755)
        self.assertIn('"$HOME/.local/bin/bloom"', launcher.read_text())
        system.uninstall(self.root, remove_deps=False, run=self.run_stub)
        self.assertFalse(launcher.exists())

    def test_someone_elses_bloom_command_is_left_alone(self):
        launcher = self.root / system.LAUNCHER
        launcher.parent.mkdir(parents=True)
        launcher.write_text("#!/bin/sh\necho mine\n")
        steps = self.install()
        self.assertEqual(launcher.read_text(), "#!/bin/sh\necho mine\n")
        self.assertTrue(any(s["kind"] == "note" and system.LAUNCHER in s["label"] for s in steps), steps)
        system.uninstall(self.root, remove_deps=False, run=self.run_stub)
        self.assertEqual(launcher.read_text(), "#!/bin/sh\necho mine\n")

    # SDDM reads its drop-ins in name order and the last theme wins.
    def test_login_theme_wins_over_other_dropins(self):
        dropins = self.root / "etc/sddm.conf.d"
        dropins.mkdir(parents=True)
        (dropins / "theme.conf").write_text("[Theme]\nCurrent=ii-material-sddm\n")
        self.install()
        self.assertEqual(system.login_theme(self.root), "bloom")

    def test_a_theme_in_sddm_conf_is_named_in_the_plan(self):
        (self.root / "etc/sddm.conf").write_text("[Theme]\nCurrent=breeze\n")
        steps = self.install()
        self.assertTrue(any(s["kind"] == "note" and "breeze" in s["label"] for s in steps), steps)

    def test_the_old_dropin_name_is_replaced(self):
        old = self.root / "etc/sddm.conf.d/10-bloom.conf"
        old.parent.mkdir(parents=True)
        old.write_text(system.DROPIN_TEXT)
        self.install()
        doc = json.loads((self.root / system.MANIFEST).read_text())
        doc["files"]["etc/sddm.conf.d/10-bloom.conf"] = system._digest_bytes(system.DROPIN_TEXT.encode())
        doc["files"].pop(system.DROPIN)
        (self.root / system.DROPIN).unlink()
        (self.root / system.MANIFEST).write_text(json.dumps(doc))
        self.install()
        self.assertFalse(old.exists())
        self.assertTrue((self.root / system.DROPIN).exists())
        system.uninstall(self.root, remove_deps=False, run=self.run_stub)
        self.assertFalse((self.root / system.DROPIN).exists())

    def test_beside_ii_no_apps_are_added(self):
        (self.root / "home/dhanush/.config/quickshell/ii").mkdir(parents=True)
        self.assertNotIn("apps", self.kinds(system.plan(self.root, self.user, deps=True)))

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
        self.assertFalse((self.root / system.DROPIN).exists())
        self.assertFalse((self.root / "usr/share/sddm/themes/bloom").exists())

    def test_failure_after_enabling_disables_again(self):
        with self.assertRaises(system.Failure):
            self.install(STUB_FAIL="groupadd")
        self.assertIsNone(system.display_manager(self.root))
        self.assertFalse((self.root / system.DROPIN).exists())

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
        self.assertFalse((self.root / system.DROPIN).exists())
        self.assertFalse((self.root / "usr/share/sddm/themes/bloom").exists())
        self.assertFalse((self.root / "var/lib/bloom/login").exists())
        self.assertNotIn("bloom-login:", (self.root / "etc/group").read_text())
        self.assertTrue(any("NetworkManager" in m for m in messages), messages)
        self.assertIn("Kept the default apps: kitty, dolphin, firefox, gnome-text-editor, loupe, mpv", messages)
        self.assertFalse(any(call[:2] == ["pacman", "-R"] or call[:2] == ["pacman", "-Rns"] and "firefox" in call
                             for call in self.calls()))
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
