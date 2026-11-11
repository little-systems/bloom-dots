"""Events, operations, doctor and support bundles in throwaway homes."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


events = load("bloom_events", "shell/services/bloom_events.py")
operations = load("bloom_operations", "shell/services/bloom_operations.py")


class Home(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.t = Path(self.temp.name)
        self.home = self.t / "home"
        (self.home / ".config/bloom").mkdir(parents=True)
        (self.home / ".local/state/bloom").mkdir(parents=True)
        self.run_dir = self.t / "run"
        self.run_dir.mkdir(mode=0o700)
        self.bin = self.t / "bin"
        self.bin.mkdir()
        self.env = {"HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin", "XDG_RUNTIME_DIR": str(self.run_dir),
                    "XDG_STATE_HOME": str(self.home / ".local/state"), "XDG_CONFIG_HOME": str(self.home / ".config"),
                    "LANG": "C.UTF-8"}
        self._saved = dict(os.environ)
        os.environ.clear()
        os.environ.update(self.env)
        self.addCleanup(lambda: (os.environ.clear(), os.environ.update(self._saved)))
        self.log = self.home / ".local/state/bloom/log/events.jsonl"

    def records(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def fake(self, name, script):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + script + "\n")
        path.chmod(0o755)


class EventCases(Home):
    def test_envelope_is_versioned_private_and_allowlisted(self):
        log = events.Events("lifecycle")
        self.assertTrue(log.emit("lifecycle.step", op="abc", stage="install", outcome="committed", step=3, bytes=12,
                                 secretValue="hunter2"))
        record = self.records()[0]
        for key in ("v", "ts", "mono", "level", "event", "component", "op", "session", "stage", "outcome"):
            self.assertIn(key, record)
        self.assertEqual(record["v"], 1)
        self.assertEqual(record["detail"], {"step": 3, "bytes": 12, "omitted": 1})
        self.assertEqual(self.log.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.log.parent.stat().st_mode & 0o777, 0o700)

    def test_synthetic_secrets_and_personal_paths_are_redacted(self):
        user = os.environ.get("USER", "")
        log = events.Events("assistant")
        log.emit("request.failed", level="error", error="request failed",
                 reason=f"key=AIzaSyA1234567890abcdefghijklmnopqrstu token: sk-abcdefghijklmnop1234 at {self.home}/x")
        text = self.log.read_text()
        for secret in ("AIzaSyA1234567890", "sk-abcdefghijklmnop1234", str(self.home)):
            self.assertNotIn(secret, text)
        self.assertIn("~/x", text)
        record = self.records()[0]
        self.assertNotIn(user or "\0", record["session"])

    def test_rate_cap_drops_and_reports_floods(self):
        log = events.Events("notifications", rate=5, window=0.2)
        for _ in range(50):
            log.emit("notification.dropped")
        self.assertEqual(len(self.records()), 5)
        time.sleep(0.25)
        log.emit("notification.dropped")
        dropped = [r for r in self.records() if r["event"] == "events.dropped"]
        self.assertEqual(dropped[0]["detail"]["count"], 45)

    def test_rotation_keeps_four_generations_and_ages_out(self):
        log = events.Events("soak", max_bytes=400, generations=4)
        for n in range(60):
            log.emit("soak.sample", count=n)
        files = sorted(p.name for p in self.log.parent.iterdir())
        self.assertEqual(files, ["events.jsonl", "events.jsonl.1", "events.jsonl.2", "events.jsonl.3"])
        old = self.log.parent / "events.jsonl.3"
        then = time.time() - 15 * 86400
        os.utime(old, (then, then))
        events.Events("soak").emit("soak.sample")
        self.assertFalse(old.exists())

    def test_failure_to_log_never_raises(self):
        self.log.parent.mkdir(parents=True)
        self.log.parent.chmod(0o500)
        self.addCleanup(self.log.parent.chmod, 0o700)
        self.assertFalse(events.Events("lock").emit("lock.requested"))


class OperationCases(Home):
    def test_success_has_one_terminal_record(self):
        result = operations.run_operation("lifecycle", "probe", ["sh", "-c", "echo hi"], events=events.Events("lifecycle"))
        self.assertEqual(result["state"], "success")
        self.assertEqual(result["stdout"], "hi\n")
        for key in ("id", "component", "action", "state", "errorCode", "startedMonotonic", "durationMs",
                    "retry", "exitCode", "signal", "verified"):
            self.assertIn(key, result)
        finished = [r for r in self.records() if r["event"] == "operation.finished"]
        self.assertEqual(len(finished), 1)
        self.assertEqual(finished[0]["op"], result["id"])

    def test_missing_binary_is_a_start_failure(self):
        result = operations.run_operation("lifecycle", "probe", ["bloom-no-such-tool"])
        self.assertEqual((result["state"], result["errorCode"]), ("failure", "start-failed"))

    def test_timeout_kills_the_whole_process_tree(self):
        marker = self.t / "child.pid"
        result = operations.run_operation("lifecycle", "probe",
                                          ["sh", "-c", f"sleep 30 & echo $! > {marker}; wait"], timeout=0.5)
        self.assertEqual(result["errorCode"], "timeout")
        time.sleep(0.2)
        child = int(marker.read_text())
        self.assertFalse(Path(f"/proc/{child}").exists() and "sleep" in Path(f"/proc/{child}/cmdline").read_text(),
                         "the background child survived")

    def test_output_is_bounded(self):
        result = operations.run_operation("lifecycle", "probe", ["sh", "-c", "yes x | head -c 1000000"], output_limit=4096)
        self.assertLessEqual(len(result["stdout"]), 4096)
        self.assertTrue(result["truncated"])

    def test_exit_and_signal_are_distinguished(self):
        failed = operations.run_operation("lifecycle", "probe", ["sh", "-c", "exit 4"])
        self.assertEqual((failed["errorCode"], failed["exitCode"]), ("exit", 4))
        killed = operations.run_operation("lifecycle", "probe", ["sh", "-c", "kill -TERM $$"])
        self.assertEqual((killed["errorCode"], killed["signal"]), ("signal", 15))

    def test_readback_decides_verified(self):
        result = operations.run_operation("audio", "set-volume", ["true"], verify=lambda r: False)
        self.assertEqual((result["state"], result["errorCode"], result["verified"]), ("failure", "verify-failed", False))

    def test_cancellation_is_its_own_terminal_state(self):
        import threading
        cancel = threading.Event()
        threading.Timer(0.3, cancel.set).start()
        started = time.monotonic()
        result = operations.run_operation("recording", "record", ["sleep", "30"], cancel=cancel)
        self.assertEqual((result["state"], result["errorCode"]), ("cancelled", "cancelled"))
        self.assertLess(time.monotonic() - started, 5)

    def test_command_text_is_not_logged(self):
        operations.run_operation("launcher", "launch", ["sh", "-c", "echo private-query"], events=events.Events("launcher"))
        self.assertNotIn("private-query", self.log.read_text())


class DoctorCases(Home):
    def doctor(self, *args):
        return subprocess.run([sys.executable, str(ROOT / "tools/bloom-doctor.py"), *args], env=self.env,
                              text=True, capture_output=True, timeout=60)

    def test_doctor_works_without_session_service_or_network(self):
        result = self.doctor("--json")
        report = json.loads(result.stdout)
        self.assertEqual(report["version"], 1)
        self.assertIn(report["verdict"], ("healthy", "degraded", "failed"))
        self.assertEqual(result.returncode, {"healthy": 0, "degraded": 1, "failed": 2}[report["verdict"]])
        ids = {c["id"] for c in report["checks"]}
        self.assertTrue({"session", "service", "settings", "state", "lifecycle", "dependencies"} <= ids)

    def test_interrupted_lifecycle_is_a_failure_with_recovery(self):
        (self.home / ".local/state/bloom/install-manifest.json").write_text(json.dumps({"status": "uninstalling"}))
        report = json.loads(self.doctor("--json").stdout)
        check = next(c for c in report["checks"] if c["id"] == "lifecycle")
        self.assertEqual(check["status"], "failed")
        self.assertIn("bloom recover", check["recovery"])
        self.assertEqual(report["verdict"], "failed")

    def test_completed_installation_is_healthy(self):
        (self.home / ".local/state/bloom/install-manifest.json").write_text(json.dumps({"status": "complete"}))
        check = next(c for c in json.loads(self.doctor("--json").stdout)["checks"] if c["id"] == "lifecycle")
        self.assertEqual(check["status"], "ok")

    def test_rate_limited_service_is_reported(self):
        self.fake("systemctl", 'echo "LoadState=loaded"; echo "ActiveState=failed"; echo "SubState=failed"; echo "Result=start-limit-hit"; echo "NRestarts=5"')
        report = json.loads(self.doctor("--json").stdout)
        check = next(c for c in report["checks"] if c["id"] == "service")
        self.assertEqual(check["status"], "failed")
        self.assertIn("reset-failed", check["recovery"])

    def test_quarantined_and_corrupt_state_is_reported(self):
        state = self.home / ".local/state/bloom"
        (state / "dock.json").write_text("{broken")
        (state / "notifications.json.bak").write_text("old")
        check = next(c for c in json.loads(self.doctor("--json").stdout)["checks"] if c["id"] == "state")
        self.assertEqual(check["status"], "degraded")
        self.assertIn("dock", check["summary"])

    def test_foreign_notification_owner_is_a_conflict(self):
        self.fake("busctl", 'case "$3" in org.freedesktop.Notifications) echo "PID=42"; echo "Comm=dunst";; *) exit 1;; esac')
        check = next(c for c in json.loads(self.doctor("--json").stdout)["checks"] if c["id"] == "bus")
        self.assertEqual(check["status"], "degraded")
        self.assertIn("dunst", check["summary"])

    def test_doctor_changes_nothing_and_leaks_no_home_path(self):
        (self.home / ".config/bloom/settings.json").write_text('{"bloom-gemini-key": "AIzaSyA1234567890abcdefghijk"}')
        before = sorted(str(p) for p in self.home.rglob("*"))
        result = self.doctor("--json")
        self.assertEqual(sorted(str(p) for p in self.home.rglob("*")), before)
        self.assertNotIn(str(self.home), result.stdout)
        self.assertNotIn("AIzaSy", result.stdout)

    def test_recent_failures_come_from_the_event_log(self):
        events.Events("lifecycle").emit("lifecycle.failed", level="error", error="backup-missing")
        report = json.loads(self.doctor("--json").stdout)
        self.assertEqual(report["recentFailures"][0]["event"], "lifecycle.failed")


class SupportCases(Home):
    def support(self, *args):
        return subprocess.run([sys.executable, str(ROOT / "tools/bloom-doctor.py"), "--support", *args], env=self.env,
                              text=True, capture_output=True, timeout=60)

    def test_preview_writes_nothing(self):
        result = self.support("--preview")
        self.assertIn("doctor.json", result.stdout)
        self.assertFalse((self.home / ".local/state/bloom/support").exists())

    def test_bundle_is_private_allowlisted_and_redacted(self):
        (self.home / ".config/bloom/settings.json").write_text(json.dumps({"bloom-gemini-key": "AIzaSyA1234567890abcdefghijk", "bloom-theme-mode": "dark"}))
        events.Events("assistant").emit("request.failed", level="error", reason="token=sk-abcdefghijklmnop1234")
        out = self.t / "bundle.tar.gz"
        result = self.support("--output", str(out))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(out.stat().st_mode & 0o777, 0o600)
        with tarfile.open(out) as bundle:
            names = sorted(bundle.getnames())
            self.assertEqual(names, ["doctor.json", "events.jsonl", "settings-keys.json", "versions.txt"])
            text = "".join(bundle.extractfile(n).read().decode() for n in names)
        for leak in ("AIzaSy", "sk-abcdefghijklmnop1234", str(self.home), "dark"):
            self.assertNotIn(leak, text)
        self.assertIn("bloom-theme-mode", text)


if __name__ == "__main__":
    unittest.main(verbosity=1)
