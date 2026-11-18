#!/usr/bin/env python3
"""shell/scripts/tray-owners.py: each registered tray icon's D-Bus owner
process (pid, parent, executable) and its Id, Title and IconName, as JSON."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location("tray_owners", ROOT / "shell/scripts/tray-owners.py")
owners = importlib.util.module_from_spec(spec)
spec.loader.exec_module(owners)


class Owners(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="bloom-tray-proc-")
        self.addCleanup(self.tmp.cleanup)
        self.proc = Path(self.tmp.name)

    def process(self, pid, ppid, exe):
        d = self.proc / str(pid)
        d.mkdir()
        (d / "stat").write_text(f"{pid} (my app (1)) S {ppid} 0 0\n")
        (d / "exe").symlink_to(exe)

    def bus(self, calls):
        """A fake busctl: answers by (method or property) from `calls`."""
        def run(args):
            key = args[-1] if args[0] == "get-property" else args[-1]
            if args[0] == "get-property":
                key = (args[2], args[-1])
            elif args[0] == "call":
                key = ("pid", args[-1])
            value = calls.get(key)
            if value is None:
                raise OSError("no reply")
            return value
        return run

    def test_reports_each_item_with_its_process(self):
        self.process(3989, 1, "/usr/lib/chatgpt/ChatGPT")
        self.process(535434, 900, "/opt/spotify/spotify")
        calls = {
            ("/StatusNotifierWatcher", "RegisteredStatusNotifierItems"): [":1.58/StatusNotifierItem", ":1.7/org/ayatana/NotificationItem/spotify_client"],
            ("pid", ":1.58"): 3989, ("pid", ":1.7"): 535434,
            ("/StatusNotifierItem", "Id"): "chrome_status_icon_1", ("/StatusNotifierItem", "Title"): "",
            ("/org/ayatana/NotificationItem/spotify_client", "Id"): "spotify-client",
            ("/org/ayatana/NotificationItem/spotify_client", "Title"): "spotify",
            ("/org/ayatana/NotificationItem/spotify_client", "IconName"): "spotify-linux-32",
        }
        self.assertEqual(owners.collect(self.bus(calls), str(self.proc)), [
            {"service": ":1.58/StatusNotifierItem", "id": "chrome_status_icon_1", "title": "", "iconName": "",
             "pid": 3989, "ppid": 1, "exe": "/usr/lib/chatgpt/ChatGPT"},
            {"service": ":1.7/org/ayatana/NotificationItem/spotify_client", "id": "spotify-client", "title": "spotify",
             "iconName": "spotify-linux-32", "pid": 535434, "ppid": 900, "exe": "/opt/spotify/spotify"},
        ])

    def test_a_well_known_name_service_uses_the_default_path(self):
        self.process(527106, 1, "/usr/lib/claude-desktop/claude")
        calls = {
            ("/StatusNotifierWatcher", "RegisteredStatusNotifierItems"): ["org.freedesktop.StatusNotifierItem-527106-1"],
            ("pid", "org.freedesktop.StatusNotifierItem-527106-1"): 527106,
            ("/StatusNotifierItem", "Id"): "Claude_status_icon_1",
        }
        [item] = owners.collect(self.bus(calls), str(self.proc))
        self.assertEqual((item["pid"], item["exe"], item["id"]), (527106, "/usr/lib/claude-desktop/claude", "Claude_status_icon_1"))

    def test_unreachable_items_are_skipped_and_no_watcher_is_empty(self):
        calls = {("/StatusNotifierWatcher", "RegisteredStatusNotifierItems"): [":1.9/StatusNotifierItem"]}
        self.assertEqual(owners.collect(self.bus(calls), str(self.proc)), [])
        self.assertEqual(owners.collect(self.bus({}), str(self.proc)), [])

    def test_main_prints_json(self):
        self.assertEqual(json.loads(owners.render([])), [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
