"""Black-box lifecycle contracts: no real packages, services or session changes."""
import json
import re
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import signal
import socket
import fcntl
import hashlib

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
        shutil.copy2(ROOT / ".gitignore", self.root / ".gitignore")
        for relative in ("bin", "systemd", "share", "hypr", "kitty", "packaging"):
            shutil.copytree(ROOT / relative, self.root / relative)
        (self.root / "tools").mkdir()
        for tool in ("bloom-lifecycle.py", "bloom_system.py", "bloom_ui.py"):
            shutil.copy2(ROOT / "tools" / tool, self.root / "tools" / tool)
        shutil.copytree(ROOT / "sddm", self.root / "sddm")
        (self.root / "shell").mkdir()
        (self.root / "shell/scripts").mkdir()
        for script in ("adaptive-theme.sh", "theme-owner.py", "app-theme.py"):
            shutil.copy2(ROOT / "shell/scripts" / script, self.root / "shell/scripts" / script)
        (self.root / "shell/services").mkdir()
        for module in ("bloom_retention.py", "bloom_events.py", "bloom_operations.py"):
            shutil.copy2(ROOT / "shell/services" / module, self.root / "shell/services" / module)
        shutil.copytree(ROOT / "shell/theming", self.root / "shell/theming")
        (self.root / "shell/settings-app.qml").write_text("// fixture\n")
        (self.root / "shell/shell.qml").write_text("// fixture\n")
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
        self.env["TMPDIR"] = str(self.base)
        # The machine Bloom installs into: a fake root with one regular account.
        self.sysroot = self.base / "sysroot"
        (self.sysroot / "etc/systemd/system").mkdir(parents=True)
        import pwd
        self.user = pwd.getpwuid(os.getuid()).pw_name
        (self.sysroot / "etc/passwd").write_text(
            f"root:x:0:0::/root:/bin/bash\n{self.user}:x:{os.getuid()}:{os.getgid()}::{self.home}:/bin/bash\n")
        (self.sysroot / "etc/group").write_text("root:x:0:\n")
        self.env["BLOOM_SYSTEM_ROOT"] = str(self.sysroot)
        # A fake live Hyprland session (Wayland and instance sockets), so tests
        # never depend on the machine they run on.
        runtime = self.base / "run"
        (runtime / "hypr/fixture").mkdir(parents=True, mode=0o700)
        runtime.chmod(0o700)
        for path in (runtime / "wayland-fixture", runtime / "hypr/fixture/.socket.sock"):
            sock = socket.socket(socket.AF_UNIX)
            sock.bind(str(path))
            self.addCleanup(sock.close)
        self.env.update(XDG_RUNTIME_DIR=str(runtime), WAYLAND_DISPLAY="wayland-fixture",
                        HYPRLAND_INSTANCE_SIGNATURE="fixture")
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
    elif args[-2:] == ['shell', 'ping']:
        # A candidate whose VERSION says "unhealthy" never answers.
        unhealthy = (base / 'checkout with spaces/VERSION').read_text().startswith('unhealthy')
        # Quickshell prints warnings (e.g. a non-UTF-8 locale) on stdout first.
        print('  WARN: Detected locale "C" which is not UTF-8.')
        print('dead' if unhealthy else os.environ.get('STUB_PING', 'pong'))
    elif args[-2:] == ['polkit', 'state']: print(json.dumps({'registered': os.environ.get('STUB_POLKIT', 'yes') == 'yes'}))
    else: print(json.dumps({'ownership': os.environ.get('STUB_OWNERSHIP', 'owned')}))
elif name == 'busctl': print('u ' + os.environ.get('STUB_TRAY_PID', '4242'))
elif os.environ.get('STUB_FAIL') == name: sys.exit(1)
elif name == 'sudo':
    if args[0] == '-v': sys.exit(1 if os.environ.get('STUB_NO_SUDO') else 0)
    os.execvpe(args[0], args, dict(os.environ, BLOOM_AS_ROOT='1'))
elif name == 'runuser':
    rest = args[args.index('--') + 1:]
    os.execvp(rest[0], rest)
elif name == 'systemd-detect-virt': sys.exit(0 if os.environ.get('STUB_CHROOT') else 1)
elif name == 'makepkg': Path('bloom-shell-deps-1-1-any.pkg.tar.zst').write_text('package')
elif name in ('pacman', 'chown', 'notify-send'): pass
elif name in ('groupadd', 'usermod', 'groupdel'):
    group = Path(os.environ['BLOOM_SYSTEM_ROOT']) / 'etc/group'
    lines = group.read_text().splitlines()
    if name == 'groupadd': lines.append(args[-1] + ':x:960:')
    elif name == 'groupdel': lines = [l for l in lines if not l.startswith(args[-1] + ':')]
    else: lines = [l + (',' if l.split(':')[3] else '') + args[-1] if l.startswith('bloom-login:') else l for l in lines]
    group.write_text('\\n'.join(lines) + '\\n')
elif name == 'systemctl' and args[0] != '--user':
    units = Path(os.environ['BLOOM_SYSTEM_ROOT']) / 'etc/systemd/system'
    unit = args[-1]
    link = units / 'display-manager.service' if unit == 'sddm.service' else units / 'multi-user.target.wants' / unit
    if 'enable' in args:
        link.parent.mkdir(parents=True, exist_ok=True)
        if not link.is_symlink(): link.symlink_to('/usr/lib/systemd/system/' + unit)
    elif 'disable' in args and link.is_symlink(): link.unlink()
elif name == 'hyprctl': print(json.dumps({'tag': os.environ.get('STUB_HYPR_VERSION', 'v0.56.2')}))
elif name == 'systemctl':
    if os.environ.get('STUB_NO_USER_MANAGER'): sys.exit(1)
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
        for name in ("qs", "hyprctl", "systemctl", "makepkg", "sudo", "busctl", "pacman", "runuser", "chown",
                     "groupadd", "usermod", "groupdel", "systemd-detect-virt", "notify-send"):
            path = self.bin / name
            path.write_text(stub)
            path.chmod(0o755)

    def bloom(self, *args, success=True, **variables):
        env = dict(self.env, **variables)
        result = subprocess.run([str(self.root / "bin/bloom"), *args], env=env, text=True, capture_output=True, timeout=30)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def snapshot(self):
        result = {}
        for path in sorted(self.home.rglob("*")):
            key = str(path.relative_to(self.home))
            # The private event log is diagnostics, not installed configuration.
            if key.startswith(".local/state/bloom/log") or key in (".local", ".local/state", ".local/state/bloom"):
                continue
            result[key] = ("link", os.readlink(path)) if path.is_symlink() else (
                ("file", path.read_bytes()) if path.is_file() else ("dir",))
        return result

    def test_failures_are_recorded_and_dry_runs_are_not(self):
        log = self.state / "log/events.jsonl"
        self.bloom("install", "--dry-run")
        self.assertFalse(log.exists())
        self.bloom("install")
        path = self.config / "systemd/user/bloom-shell.service"
        path.unlink()
        path.write_text("[Service]\nExecStart=my-custom-shell\n")
        self.bloom("uninstall", success=False)
        records = [json.loads(line) for line in log.read_text().splitlines()]
        failed = [r for r in records if r["event"] == "lifecycle.failed"]
        self.assertEqual(len(failed), 1)
        self.assertEqual(failed[0]["component"], "lifecycle")
        self.assertNotIn(str(self.home), log.read_text())
        self.assertEqual(log.stat().st_mode & 0o777, 0o600)

    def test_install_without_a_session_enables_bloom_for_the_next_login(self):
        # From a console or SSH before the first Hyprland login.
        result = self.bloom("install", WAYLAND_DISPLAY="", HYPRLAND_INSTANCE_SIGNATURE="")
        self.assertIn("next Hyprland login", result.stdout)
        service = json.loads((self.base / "service").read_text())
        self.assertTrue(service["enabled"])
        self.assertFalse(service["active"])
        self.assertNotIn("ping", (self.base / "calls").read_text())
        manifest = json.loads((self.state / "install-manifest.json").read_text())
        self.assertEqual(manifest["status"], "complete")

    def fresh_hyprland(self, default="-- Hyprland default config\nhl.config({})\n"):
        # A fresh Arch: Hyprland installed but never started, so no user config.
        (self.config / "hypr/hyprland.lua").unlink()
        shipped = self.base / "hyprland-default.lua"
        if default is not None:
            shipped.write_text(default)
        return {"BLOOM_HYPR_DEFAULT_CONFIG": str(shipped)}

    def test_missing_hyprland_config_starts_from_hyprlands_default(self):
        (self.config / "quickshell/ii").mkdir(parents=True)
        env = self.fresh_hyprland()
        config = self.config / "hypr/hyprland.lua"
        dry = self.bloom("install", "--dry-run", **env)
        self.assertIn("Hyprland's default configuration", dry.stdout)
        self.assertFalse(config.exists(), "a dry run creates nothing")
        self.bloom("install", **env)
        text = config.read_text()
        self.assertTrue(text.startswith("-- Hyprland default config\nhl.config({})\n"))
        self.assertEqual(sum(line.endswith("-- bloom managed loader") for line in text.splitlines()), 1)

    def test_uninstall_removes_an_unedited_created_hyprland_config(self):
        env = self.fresh_hyprland()
        self.bloom("install", **env)
        self.bloom("uninstall", **env)
        self.assertFalse((self.config / "hypr/hyprland.lua").exists())

    def test_uninstall_keeps_a_created_hyprland_config_the_owner_edited(self):
        env = self.fresh_hyprland()
        self.bloom("install", **env)
        config = self.config / "hypr/hyprland.lua"
        with config.open("a") as stream:
            stream.write("-- my own bind\n")
        self.bloom("uninstall", **env)
        text = config.read_text()
        self.assertIn("-- my own bind", text)
        self.assertNotIn("bloom managed loader", text)

    def test_missing_config_without_hyprlands_default_is_refused_with_instructions(self):
        env = self.fresh_hyprland(default=None)
        result = self.bloom("install", success=False, **env)
        self.assertIn("/hypr/hyprland.lua", result.stderr)
        self.assertIn("start Hyprland once", result.stderr)
        self.assertFalse((self.state / "install-manifest.json").exists())

    def test_a_clean_install_logs_no_problems(self):
        self.bloom("install")
        log = self.state / "log/events.jsonl"
        problems = [r for r in map(json.loads, log.read_text().splitlines()) if r["level"] in ("warning", "error")]
        self.assertEqual(problems, [], "expected probe results must not read as problems")

    def test_without_ii_every_module_is_on(self):
        self.bloom("install")
        settings = json.loads((self.config / "bloom/settings.json").read_text())
        modules = re.search(r"var MODULES = (\[.*?\]);", (ROOT / "shell/services/settings.js").read_text()).group(1)
        self.assertEqual(settings["bloom-enabled-modules"], json.loads(modules))

    def test_without_ii_a_fresh_machine_gets_blooms_desktop(self):
        env = self.fresh_hyprland()
        dry = self.bloom("install", "--dry-run", **env)
        self.assertIn("Bloom's desktop", dry.stdout)
        self.bloom("install", **env)
        self.bloom("install", **env)
        lines = (self.config / "hypr/hyprland.lua").read_text().splitlines()
        self.assertTrue(lines[0].endswith("-- bloom managed desktop"), "Bloom's desktop loads before personal lines")
        self.assertIn("hypr/desktop.lua", lines[0])
        self.assertEqual(sum(line.endswith("-- bloom managed desktop") for line in lines), 1)
        self.assertEqual(sum(line.endswith("-- bloom managed loader") for line in lines), 1)
        self.assertNotIn("Hyprland default config", "\n".join(lines))
        self.bloom("uninstall", **env)
        self.assertFalse((self.config / "hypr/hyprland.lua").exists())

    def test_hyprlands_untouched_example_becomes_blooms_desktop_and_comes_back(self):
        env = self.fresh_hyprland()
        stock = Path(env["BLOOM_HYPR_DEFAULT_CONFIG"]).read_text()
        (self.config / "hypr/hyprland.lua").write_text(stock)
        self.bloom("install", **env)
        self.assertIn("-- bloom managed desktop", (self.config / "hypr/hyprland.lua").read_text())
        self.bloom("uninstall", **env)
        self.assertEqual((self.config / "hypr/hyprland.lua").read_text(), stock)

    def test_a_personal_config_never_gets_blooms_desktop(self):
        self.bloom("install")
        text = (self.config / "hypr/hyprland.lua").read_text()
        self.assertTrue(text.startswith("-- personal configuration\n"))
        self.assertNotIn("bloom managed desktop", text)

    def test_beside_ii_the_wallpaper_stays_with_ii(self):
        (self.config / "quickshell/ii").mkdir(parents=True)
        self.bloom("install")
        settings = json.loads((self.config / "bloom/settings.json").read_text())
        self.assertEqual(settings["bloom-enabled-modules"], ["notch", "dock"])

    # kitty: Bloom's settings are included first, so the user's own lines win.
    def test_kitty_gets_blooms_settings_first_and_loses_them_on_uninstall(self):
        self.bloom("install")
        kitty = self.config / "kitty/kitty.conf"
        lines = kitty.read_text().splitlines()
        self.assertTrue(re.fullmatch(r"include /.*/kitty/bloom\.conf", lines[0]), lines[0])
        self.assertTrue((Path(lines[0].split(" ", 1)[1])).is_file())
        self.bloom("uninstall")
        self.assertFalse(kitty.exists())

    def test_an_existing_kitty_config_keeps_its_lines(self):
        kitty = self.config / "kitty/kitty.conf"
        kitty.parent.mkdir(parents=True)
        kitty.write_text("font_size 14\n")
        self.bloom("install")
        text = kitty.read_text()
        self.assertTrue(text.startswith("include "))
        self.assertTrue(text.endswith("font_size 14\n"))
        self.bloom("install")
        self.assertEqual(kitty.read_text(), text)
        with kitty.open("a") as stream:
            stream.write("cursor_shape block\n")
        self.bloom("uninstall")
        self.assertEqual(kitty.read_text(), "font_size 14\ncursor_shape block\n")

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
        self.bloom("install", "--restart", success=False, STUB_FAIL_START="1")
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

    def test_uninstall_keeps_theme_files_edited_after_bloom_themed_them(self):
        self.bloom("install")
        relative = ".config/gtk-3.0/gtk.css"
        current = self.home / relative
        current.parent.mkdir(parents=True)
        current.write_text("/* original desktop theme */\n")
        stage = self.base / "stage"
        (stage / relative).parent.mkdir(parents=True)
        (stage / relative).write_text("/* Bloom palette */\n")
        subprocess.run(["python3", str(self.root / "shell/scripts/theme-owner.py"), "commit", str(stage)],
                       env=self.env, check=True, capture_output=True)
        current.write_text("/* edited by the owner */\n")
        self.bloom("uninstall")
        self.assertEqual(current.read_text(), "/* edited by the owner */\n")
        self.assertFalse((self.state / "app-themes/ownership.json").exists())

    def test_edited_managed_unit_blocks_uninstall_before_stopping(self):
        self.bloom("install")
        path = self.config / "systemd/user/bloom-shell.service"
        path.unlink()
        path.write_text("[Service]\nExecStart=my-custom-shell\n")
        self.bloom("uninstall", success=False)
        self.assertEqual(path.read_text(), "[Service]\nExecStart=my-custom-shell\n")
        self.assertTrue(json.loads((self.base / "service").read_text())["active"])

    def test_missing_original_blocks_uninstall_before_any_effect(self):
        launcher = self.home / ".local/bin/bloom"
        launcher.parent.mkdir(parents=True)
        launcher.write_text("original launcher\n")
        self.bloom("install")
        manifest = json.loads((self.state / "install-manifest.json").read_text())
        original = next(e for e in manifest["entries"] if e["path"] == str(launcher))
        Path(original["backup"]).unlink()
        before = self.snapshot()
        self.bloom("uninstall", success=False)
        self.assertEqual(before, self.snapshot())
        self.assertTrue(json.loads((self.base / "service").read_text())["active"])

    def test_corrupt_original_blocks_uninstall_before_any_effect(self):
        launcher = self.home / ".local/bin/bloom"
        launcher.parent.mkdir(parents=True)
        launcher.write_text("original launcher\n")
        self.bloom("install")
        manifest = json.loads((self.state / "install-manifest.json").read_text())
        original = next(e for e in manifest["entries"] if e["path"] == str(launcher))
        Path(original["backup"]).write_text("damaged original\n")
        before = self.snapshot()
        self.bloom("uninstall", success=False)
        self.assertEqual(before, self.snapshot())
        self.assertTrue(json.loads((self.base / "service").read_text())["active"])

    def test_manifest_traversal_and_malformed_entries_refused_before_effects(self):
        self.bloom("install")
        path = self.state / "install-manifest.json"
        original = json.loads(path.read_text())
        variants = [
            {"path": str(self.config / ".." / "outside"), "kind": "file", "installed": "file:" + "a" * 64, "backup": None},
            {"path": str(self.config / "bloom/settings.json"), "kind": "file", "installed": "file:" + "a" * 64,
             "backup": str(self.state / "backups/../../outside")},
            "not an entry",
        ]
        for entry in variants:
            with self.subTest(entry=entry):
                broken = dict(original, entries=[entry])
                path.write_text(json.dumps(broken))
                before = self.snapshot()
                self.bloom("uninstall", success=False)
                self.assertEqual(before, self.snapshot())
                self.assertTrue(json.loads((self.base / "service").read_text())["active"])

    def test_uninstall_missing_loader_is_safe(self):
        self.bloom("install")
        (self.config / "hypr/hyprland.lua").unlink()
        self.bloom("uninstall")
        self.assertEqual((self.config / "hypr/hyprland.lua").read_text(), "-- personal configuration\n")

    def test_loader_permissions_survive_apply_and_owner_edits(self):
        loader = self.config / "hypr/hyprland.lua"
        loader.chmod(0o640)
        self.bloom("install")
        self.assertEqual(loader.stat().st_mode & 0o777, 0o640)
        loader.write_text(loader.read_text() + "-- owner addition\n")
        self.bloom("uninstall")
        self.assertEqual(loader.stat().st_mode & 0o777, 0o640)
        self.assertIn("-- owner addition", loader.read_text())

    def test_reinstall_does_not_restart_converged_service(self):
        self.bloom("install")
        (self.base / "calls").write_text("")
        self.bloom("install")
        calls = [json.loads(line) for line in (self.base / "calls").read_text().splitlines()]
        self.assertFalse(any(c[0] == 'systemctl' and c[2] in ('start', 'restart', 'enable', 'daemon-reload') for c in calls))

    def test_parent_symlink_cannot_redirect_removal(self):
        self.bloom("install")
        original = self.config / "systemd/user"
        moved = self.base / "foreign-user-units"
        original.rename(moved)
        original.symlink_to(moved)
        before = self.snapshot()
        self.bloom("uninstall", success=False)
        self.assertEqual(before, self.snapshot())
        self.assertTrue((moved / "bloom-shell.service").is_symlink())

    def test_lifecycle_lock_refuses_concurrent_writer_without_changes(self):
        key = hashlib.sha256(str(self.config.resolve()).encode()).hexdigest()[:16]
        directory = self.base / f"bloom-lifecycle-{os.getuid()}-{key}"
        directory.mkdir(mode=0o700)
        with (directory / "lock").open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            before = self.snapshot()
            result = self.bloom("install", success=False)
            self.assertIn("another Bloom lifecycle operation", result.stderr)
            self.assertEqual(before, self.snapshot())

    def test_recovery_inspection_is_read_only_and_originals_can_be_restored(self):
        self.cut("install", "place", 4)
        before = self.snapshot()
        self.bloom("recover")
        self.assertEqual(before, self.snapshot())
        self.bloom("recover", "--restore-originals")
        self.assertFalse((self.state / "install-manifest.json").exists())
        self.assertEqual((self.config / "hypr/hyprland.lua").read_text(), "-- personal configuration\n")

    def cut(self, command, seam, count=1, after=False):
        # Kill the actual CLI at its filesystem seam. Only this disposable
        # module instance is instrumented; production has no failure switches.
        script = '''import importlib.util, os, signal, sys, tempfile
tempfile.tempdir = os.environ['BLOOM_TEST_DIR']
spec = importlib.util.spec_from_file_location('lifecycle', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
name, remaining, after = sys.argv[3], int(sys.argv[4]), sys.argv[5] == '1'
original = getattr(m, name)
def cut(*args, **kwargs):
    global remaining
    remaining -= 1
    if remaining == 0 and not after: os.kill(os.getpid(), signal.SIGKILL)
    result = original(*args, **kwargs)
    if remaining == 0 and after: os.kill(os.getpid(), signal.SIGKILL)
    return result
setattr(m, name, cut)
sys.argv = [sys.argv[1], sys.argv[2]]
m.main()
'''
        p = subprocess.run(["python3", "-c", script, str(self.root / "tools/bloom-lifecycle.py"),
                            command, seam, str(count), str(int(after))], env=self.env,
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, -signal.SIGKILL, p.stdout + p.stderr)

    def test_killed_install_resumes_before_and_after_replacement(self):
        self.bloom("install")
        total = len(json.loads((self.state / "install-manifest.json").read_text())["entries"])
        self.bloom("uninstall")
        for count, after in ((n, side) for n in range(1, total + 1) for side in (False, True)):
            with self.subTest(count=count, after=after):
                self.cut("install", "place", count, after)
                result = self.bloom("recover")
                self.assertIn("installing", result.stdout)
                self.bloom("recover", "--resume")
                self.assertTrue(json.loads((self.base / "service").read_text())["active"])
                self.bloom("uninstall")

    def test_killed_uninstall_keeps_originals_and_resumes(self):
        launcher = self.home / ".local/bin/bloom"
        launcher.parent.mkdir(parents=True)
        launcher.write_text("original launcher\n")
        for after in (False, True):
            with self.subTest(after=after):
                self.bloom("install")
                self.cut("uninstall", "restore", 3, after)
                manifest = json.loads((self.state / "install-manifest.json").read_text())
                self.assertEqual(manifest['status'], 'uninstalling')
                self.assertTrue(all(Path(e['backup']).exists() for e in manifest['entries'] if e['backup']))
                self.bloom("recover", "--resume")
                self.assertEqual(launcher.read_text(), "original launcher\n")
                self.bloom("uninstall")  # removing twice is a no-op

    def test_changed_file_during_removal_refuses_resume(self):
        self.bloom("install")
        self.cut("uninstall", "restore", 1)
        unit = self.config / "systemd/user/bloom-shell.service"
        unit.unlink()
        unit.write_text("owner edit after interruption\n")
        before = self.snapshot()
        self.bloom("recover", "--resume", success=False)
        self.assertEqual(before, self.snapshot())





    def git(self, *args, cwd=None):
        return subprocess.check_output(["git", *args], cwd=cwd or self.root, stderr=subprocess.DEVNULL, text=True).strip()

    def test_update_installs_with_the_new_revisions_installer(self):
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Bloom Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("add", ".")
        self.git("commit", "-m", "fixture")
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
        lifecycle = upstream / "tools/bloom-lifecycle.py"
        text = lifecycle.read_text()
        anchor = '    ui.stage(total, total, "Your desktop")\n'
        self.assertIn(anchor, text)
        lifecycle.write_text(text.replace(anchor, anchor + '    ui.say("installed by the new revision")\n', 1))
        self.git("add", ".", cwd=upstream)
        self.git("commit", "-m", "new installer", cwd=upstream)
        self.git("push", cwd=upstream)
        result = self.bloom("update")
        self.assertIn("installed by the new revision", result.stdout)

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

    def prepare_updates(self):
        self.git("init", "-b", "main")
        self.git("config", "user.name", "Bloom Test")
        self.git("config", "user.email", "test@example.invalid")
        self.git("add", ".")
        self.git("commit", "-m", "fixture")
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
        return upstream, self.git("rev-parse", "HEAD")

    def publish(self, upstream, path, text):
        (upstream / path).parent.mkdir(parents=True, exist_ok=True)
        (upstream / path).write_text(text)
        self.git("add", "-A", cwd=upstream)
        self.git("commit", "-m", "change " + path, cwd=upstream)
        self.git("push", cwd=upstream)

    def test_broken_candidate_is_refused_before_the_checkout_changes(self):
        upstream, initial = self.prepare_updates()
        self.publish(upstream, "tools/bloom-lifecycle.py", "def broken(:\n")
        (self.base / "calls").write_text("")
        result = self.bloom("update", success=False)
        self.assertIn("failed validation", result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), initial)
        self.assertNotIn("restart", (self.base / "calls").read_text())

    def test_recover_update_killed_after_fast_forward(self):
        upstream, initial = self.prepare_updates()
        self.publish(upstream, "VERSION", "0.2.0\n")
        git = shutil.which("git")
        shim = self.bin / "git"
        shim.write_text(f"""#!/usr/bin/env python3
import os, signal, subprocess, sys
status = subprocess.call([{git!r}, *sys.argv[1:]])
if status == 0 and sys.argv[1:3] == ["merge", "--ff-only"]:
    os.kill(os.getppid(), signal.SIGKILL)
raise SystemExit(status)
""")
        shim.chmod(0o755)
        try:
            result = self.bloom("update", success=False)
            self.assertEqual(result.returncode, -signal.SIGKILL, result.stderr)
        finally:
            shim.unlink()
        record = self.state / "update.json"
        self.assertEqual(json.loads(record.read_text())["status"], "updating")
        self.assertNotEqual(self.git("rev-parse", "HEAD"), initial)
        self.assertIn("Update state: updating", self.bloom("recover").stdout)
        (self.root / "VERSION").write_text("owner edit\n")
        self.assertIn("local changes", self.bloom("recover", "--resume", success=False).stderr)
        self.assertEqual((self.root / "VERSION").read_text(), "owner edit\n")
        self.git("restore", "VERSION")
        self.bloom("recover", "--resume")
        self.assertEqual(self.git("rev-parse", "HEAD"), initial)
        self.assertEqual(self.git("symbolic-ref", "--short", "HEAD"), "main")
        self.assertEqual(json.loads(record.read_text())["status"], "complete")
        self.bloom("update")
        self.assertNotEqual(self.git("rev-parse", "HEAD"), initial)

    def test_unhealthy_candidate_rolls_back_to_the_verified_last_good(self):
        upstream, initial = self.prepare_updates()
        self.publish(upstream, "VERSION", "unhealthy\n")
        result = self.bloom("update", success=False)
        self.assertIn("previous version", result.stderr)
        self.assertIn("answering", result.stderr)
        self.assertEqual(self.git("rev-parse", "HEAD"), initial)
        record = json.loads((self.state / "update.json").read_text())
        self.assertEqual(record.get("lastGood"), initial)
        self.publish(upstream, "VERSION", "0.2.0\n")
        self.bloom("update")
        self.assertEqual(json.loads((self.state / "update.json").read_text())["lastGood"], self.git("rev-parse", "HEAD"))


    def calls(self):
        path = self.base / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def test_install_without_quickshell_installs_it_first(self):
        # A fresh Arch has no qs yet: the package step comes before any version check.
        (self.bin / "qs").rename(self.bin / "qs-later")
        (self.bin / "makepkg").write_text((self.bin / "runuser").read_text().replace(
            "elif name == 'makepkg':", "elif name == 'makepkg':\n    Path(os.environ['BLOOM_TEST_DIR'], 'stubs', 'qs-later').rename(Path(os.environ['BLOOM_TEST_DIR'], 'stubs', 'qs'))\n   "))
        result = self.bloom("install")
        names = [c[0] for c in self.calls()]
        self.assertLess(names.index("makepkg"), names.index("qs"))
        self.assertIn("pacman", names)
        self.assertNotIn("missing qs", result.stderr)

    def test_root_install_runs_system_then_user_phase_as_the_user(self):
        result = self.bloom("install", BLOOM_AS_ROOT="1", STUB_CHROOT="1", STUB_NO_USER_MANAGER="1")
        calls = self.calls()
        self.assertTrue(any(c[:3] == ["runuser", "-u", self.user] for c in calls))
        self.assertNotIn("sudo", [c[0] for c in calls])
        self.assertEqual(json.loads((self.sysroot / "var/lib/bloom/system-manifest.json").read_text())["status"], "complete")
        self.assertTrue((self.state / "install-manifest.json").exists())
        self.assertIn("Reboot", result.stdout)

    def test_root_install_hands_the_checkout_to_the_user(self):
        self.bloom("install", BLOOM_AS_ROOT="1", STUB_CHROOT="1", STUB_NO_USER_MANAGER="1")
        owned = [c for c in self.calls() if c[0] == "chown" and c[-1] == str(self.root)]
        self.assertEqual(owned, [], "the checkout is already the user's in this fixture")
        self.assertTrue(all(c[0] != "chown" or c[-1] != str(self.home) for c in self.calls()))

    def test_chroot_install_leaves_a_first_login_marker(self):
        result = self.bloom("install", BLOOM_AS_ROOT="1", STUB_CHROOT="1", STUB_NO_USER_MANAGER="1")
        self.assertTrue((self.state / "first-login-pending").exists())
        self.assertFalse([c for c in self.calls() if c[:2] == ["systemctl", "--user"] and c[2] in ("enable", "start", "restart")])
        self.assertIn("first login", result.stdout)

    def test_chroot_counts_as_offline_even_when_systemctl_answers(self):
        # Inside arch-chroot systemctl says "Running in chroot, ignoring" and exits 0.
        result = self.bloom("install", BLOOM_AS_ROOT="1", STUB_CHROOT="1")
        self.assertTrue((self.state / "first-login-pending").exists())
        self.assertIn("first login", result.stdout)

    def test_first_login_enables_and_clears_the_marker(self):
        self.bloom("install", BLOOM_AS_ROOT="1", STUB_CHROOT="1", STUB_NO_USER_MANAGER="1")
        self.bloom("first-login", "--start")
        self.assertFalse((self.state / "first-login-pending").exists())
        service = json.loads((self.base / "service").read_text())
        self.assertTrue(service["enabled"] and service["active"])
        before = len(self.calls())
        self.bloom("first-login")
        self.assertEqual(len(self.calls()), before, "no marker, nothing to do")

    def test_first_login_failure_keeps_the_marker(self):
        self.bloom("install", BLOOM_AS_ROOT="1", STUB_CHROOT="1", STUB_NO_USER_MANAGER="1")
        self.bloom("first-login", "--start", success=False, STUB_PING="dead")
        self.assertTrue((self.state / "first-login-pending").exists())
        self.assertIn("notify-send", [c[0] for c in self.calls()])

    def test_user_install_runs_the_system_phase_through_sudo_once(self):
        self.bloom("install")
        sudo = [c for c in self.calls() if c[0] == "sudo" and c[1] != "-v"]
        self.assertEqual(len(sudo), 1)
        self.assertIn("system-apply", sudo[0])

    def test_repeat_install_asks_for_no_sudo(self):
        self.bloom("install")
        (self.base / "calls").unlink()
        self.bloom("install")
        self.assertNotIn("sudo", [c[0] for c in self.calls()])

    def test_without_sudo_nothing_changes(self):
        before = self.snapshot()
        result = self.bloom("install", success=False, STUB_NO_SUDO="1")
        self.assertIn("sudo", result.stderr)
        self.assertEqual(before, self.snapshot())
        self.assertFalse((self.sysroot / "var/lib/bloom").exists())

    def test_dry_run_lists_system_steps(self):
        result = self.bloom("install", "--dry-run")
        self.assertIn("Install the SDDM login screen", result.stdout)
        self.assertIn("Turn on NetworkManager", result.stdout)
        self.assertFalse((self.sysroot / "var/lib/bloom").exists())
        self.assertNotIn("sudo", [c[0] for c in self.calls()])

    def test_output_has_stages_and_a_next_step(self):
        result = self.bloom("install")
        for text in ("[1/2] System", "[2/2] Your desktop", "✓", "bloom uninstall"):
            self.assertIn(text, result.stdout)

    def test_no_colour_without_a_terminal(self):
        self.assertNotIn("\033[", self.bloom("install").stdout)

    def test_failed_system_phase_never_starts_the_user_phase(self):
        result = self.bloom("install", success=False, STUB_FAIL="pacman")
        self.assertFalse((self.state / "install-manifest.json").exists())
        self.assertIn("bloom install", result.stderr)

    def test_uninstall_undoes_the_system_phase(self):
        self.bloom("install")
        self.bloom("uninstall")
        doc = json.loads((self.sysroot / "var/lib/bloom/system-manifest.json").read_text())
        self.assertEqual(doc["status"], "uninstalled")
        self.assertFalse((self.sysroot / "etc/sddm.conf.d/10-bloom.conf").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
