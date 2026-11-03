"""Black-box lifecycle contracts: no real packages, services or session changes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="bloom-lifecycle-test-")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.root = self.base / "checkout with spaces"
        self.root.mkdir()
        for relative in ("bin", "systemd", "share", "hypr", "packaging"):
            shutil.copytree(ROOT / relative, self.root / relative)
        (self.root / "tools").mkdir()
        shutil.copy2(ROOT / "tools/bloom-lifecycle.py", self.root / "tools/bloom-lifecycle.py")
        (self.root / "shell").mkdir()
        (self.root / "shell/scripts").mkdir()
        shutil.copy2(ROOT / "shell/scripts/adaptive-theme.sh", self.root / "shell/scripts/adaptive-theme.sh")
        shutil.copytree(ROOT / "shell/theming", self.root / "shell/theming")
        (self.root / "shell/settings-app.qml").write_text("// fixture\n")
        (self.root / "VERSION").write_text("0.1.0\n")
        self.config = self.home / ".config"
        (self.config / "hypr").mkdir(parents=True)
        (self.config / "hypr/hyprland.lua").write_text("-- personal configuration\n")
        self.bin = self.base / "stubs"
        self.bin.mkdir()
        (self.base / "os-release").write_text("ID=arch\n")
        self.env = os.environ.copy()
        self.env.update(HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
                        XDG_STATE_HOME=str(self.home / ".local/state"),
                        XDG_DATA_HOME=str(self.home / ".local/share"),
                        BLOOM_THEME_HOME=str(self.home),
                        BLOOM_THEME_NO_RELOAD="1",
                        BLOOM_OS_RELEASE=str(self.base / "os-release"),
                        BLOOM_TEST_DIR=str(self.base), PATH=str(self.bin) + ":" + os.environ["PATH"])
        self.state = self.home / ".local/state/bloom"
        stub = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
base = Path(os.environ['BLOOM_TEST_DIR'])
name = Path(sys.argv[0]).name
args = sys.argv[1:]
with (base / 'calls').open('a') as f:
    f.write(json.dumps([name] + args) + '\\n')
if name == 'qs':
    if args == ['--version']: print('Quickshell 0.3.2')
    elif args[-2:] == ['shell', 'ping']: print(os.environ.get('STUB_PING', 'pong'))
    elif args[-2:] == ['polkit', 'state']: print(json.dumps({'registered': os.environ.get('STUB_POLKIT', 'yes') == 'yes'}))
    else: print(json.dumps({'ownership': os.environ.get('STUB_OWNERSHIP', 'owned')}))
elif name == 'busctl': print('u ' + os.environ.get('STUB_TRAY_PID', '4242'))
elif name == 'hyprctl': print(json.dumps({'tag': os.environ.get('STUB_HYPR_VERSION', 'v0.56.2')}))
elif name == 'systemctl':
    state_file = base / 'service'
    state = json.loads(state_file.read_text()) if state_file.exists() else {'enabled': False, 'active': False}
    command = args[1]
    if command == 'show': print('4242'); sys.exit(0)
    if command == 'is-enabled':
        print('enabled' if state['enabled'] else 'disabled'); sys.exit(0 if state['enabled'] else 1)
    if command == 'is-active':
        print('active' if state['active'] else 'inactive'); sys.exit(0 if state['active'] else 3)
    if os.environ.get('STUB_FAIL_START') and command in ('start', 'restart'): sys.exit(1)
    if command in ('enable', 'disable'): state['enabled'] = command == 'enable'
    if command in ('restart', 'start', 'stop'): state['active'] = command != 'stop'
    if '--now' in args: state['active'] = command == 'enable'
    state_file.write_text(json.dumps(state))
'''
        for name in ("qs", "hyprctl", "systemctl", "makepkg", "sudo", "busctl"):
            path = self.bin / name
            path.write_text(stub)
            path.chmod(0o755)

    def bloom(self, *args, success=True, **variables):
        env = dict(self.env, **variables)
        result = subprocess.run([str(self.root / "bin/bloom"), *args], env=env, text=True, capture_output=True)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def snapshot(self):
        result = {}
        for path in sorted(self.home.rglob("*")):
            key = str(path.relative_to(self.home))
            result[key] = ("link", os.readlink(path)) if path.is_symlink() else (
                ("file", path.read_bytes()) if path.is_file() else ("dir",))
        return result

    def test_dry_run_and_preflight_never_change_files(self):
        before = self.snapshot()
        self.bloom("install", "--dry-run")
        self.assertEqual(before, self.snapshot())
        calls = (self.base / "calls").read_text()
        self.assertNotIn('"makepkg"', calls)
        self.assertNotIn('"enable"', calls)
        self.bloom("install", success=False, STUB_HYPR_VERSION="v0.55.0")
        self.assertEqual(before, self.snapshot())

    def test_install_repeat_uninstall_roundtrip(self):
        # Existing user files must survive byte for byte.
        (self.config / "hypr/custom").mkdir()
        (self.config / "hypr/custom/bloom.lua").write_text("-- my personal overrides\n")
        before = self.snapshot()
        self.bloom("install")
        manifest = json.loads((self.state / "install-manifest.json").read_text())
        self.assertTrue(manifest["entries"])
        self.assertTrue((self.home / ".local/bin/bloom").is_symlink())
        self.assertTrue((self.home / ".local/share/icons/hicolor/128x128/apps/bloom-settings.png").exists())
        self.bloom("install")
        loader = (self.config / "hypr/hyprland.lua").read_text()
        self.assertEqual(loader.count("-- bloom managed loader"), 1)
        self.bloom("uninstall")
        self.assertEqual(before, self.snapshot())

    def test_failed_service_start_rolls_back_every_file(self):
        before = self.snapshot()
        self.bloom("install", success=False, STUB_FAIL_START="1")
        self.assertEqual(before, self.snapshot())
        service = json.loads((self.base / "service").read_text())
        self.assertEqual(service, {"enabled": False, "active": False})

    def test_foreign_directory_is_never_removed(self):
        foreign = self.config / "quickshell/bloom"
        foreign.mkdir(parents=True)
        (foreign / "shell.qml").write_text("// not Bloom\n")
        before = self.snapshot()
        self.bloom("install", success=False)
        self.assertEqual(before, self.snapshot())

    def test_changed_settings_and_templates_survive_uninstall(self):
        self.bloom("install")
        settings = self.config / "bloom/settings.json"
        settings.write_text('{"bloom-theme-mode":"light"}\n')
        custom = self.config / "hypr/custom/bloom.lua"
        custom.write_text("-- my own desktop\n")
        self.bloom("uninstall")
        self.assertEqual(settings.read_text(), '{"bloom-theme-mode":"light"}\n')
        self.assertEqual(custom.read_text(), "-- my own desktop\n")
        self.assertFalse((self.config / "quickshell/bloom").exists())

    def test_original_symlink_and_backup_survive_a_failed_reinstall(self):
        link = self.config / "quickshell/bloom"
        link.parent.mkdir()
        original = self.base / "old-shell"
        original.mkdir()
        link.symlink_to(original)
        before = self.snapshot()
        self.bloom("install")
        self.bloom("install", success=False, STUB_FAIL_START="1")
        self.bloom("uninstall")
        self.assertEqual(before, self.snapshot())

    def test_new_personal_hyprland_lines_survive_uninstall(self):
        self.bloom("install")
        path = self.config / "hypr/hyprland.lua"
        with path.open("a") as stream:
            stream.write("-- added after installing Bloom\n")
        self.bloom("uninstall")
        self.assertEqual(path.read_text(), "-- personal configuration\n-- added after installing Bloom\n")

    def test_uninstall_restores_pre_bloom_application_theme(self):
        self.bloom("install")
        relative = Path(".config/gtk-3.0/gtk.css")
        original = self.state / "app-themes" / relative
        original.parent.mkdir(parents=True)
        original.write_text("/* original desktop theme */\n")
        (self.state / "app-themes/manifest").write_text(str(relative) + "\n")
        current = self.home / relative
        current.parent.mkdir(parents=True)
        current.write_text("/* Bloom palette */\n")
        self.bloom("uninstall")
        self.assertEqual(current.read_text(), "/* original desktop theme */\n")

    def test_edited_managed_unit_blocks_uninstall_before_stopping(self):
        self.bloom("install")
        path = self.config / "systemd/user/bloom-shell.service"
        path.unlink()
        path.write_text("[Service]\nExecStart=my-custom-shell\n")
        self.bloom("uninstall", success=False)
        self.assertEqual(path.read_text(), "[Service]\nExecStart=my-custom-shell\n")
        self.assertTrue(json.loads((self.base / "service").read_text())["active"])





    def git(self, *args, cwd=None):
        return subprocess.check_output(["git", *args], cwd=cwd or self.root, stderr=subprocess.DEVNULL, text=True).strip()

    def test_update_customized_template_and_rollback(self):
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Bloom Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("add", ".")
        self.git("commit", "-m", "fixture")
        initial = self.git("rev-parse", "HEAD")
        bare = self.base / "remote.git"
        self.git("clone", "--bare", str(self.root), str(bare))
        self.git("remote", "add", "origin", str(bare))
        self.git("fetch", "origin")
        self.git("branch", "--set-upstream-to=origin/main", "main")
        upstream = self.base / "upstream"
        self.git("clone", str(bare), str(upstream))
        self.git("config", "user.name", "Bloom Test", cwd=upstream)
        self.git("config", "user.email", "test@example.invalid", cwd=upstream)
        self.bloom("install")
        custom = self.config / "hypr/custom/bloom.lua"
        custom.write_text("-- user changed this\n")
        (upstream / "hypr/custom/bloom.lua").write_text("-- new upstream template\n")
        self.git("add", ".", cwd=upstream)
        self.git("commit", "-m", "new template", cwd=upstream)
        self.git("push", cwd=upstream)
        self.bloom("update")
        self.assertEqual(custom.read_text(), "-- user changed this\n")
        self.assertEqual(custom.with_name("bloom.lua.new").read_text(), "-- new upstream template\n")
        self.bloom("update", "--rollback")
        self.assertEqual(self.git("rev-parse", "HEAD"), initial)
        self.assertEqual(custom.read_text(), "-- user changed this\n")
        self.bloom("update")
        self.assertNotEqual(self.git("rev-parse", "HEAD"), initial)
        (self.root / "VERSION").write_text("edited\n")
        self.bloom("update", success=False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
