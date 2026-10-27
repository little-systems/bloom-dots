import QtQuick
import QtTest
import "../../shell/modules/dock/extras.js" as Extras

TestCase {
	name: "DockExtrasRules"

	function test_onlyRemovableOrUserMountedFilesystems() {
		const raw = JSON.stringify({ blockdevices: [
			{ path: "/dev/sda1", uuid: "efi", fstype: "vfat", mountpoint: "/boot/efi", rm: false, hotplug: false, type: "part" },
			{ path: "/dev/sda2", uuid: "root", fstype: "ext4", mountpoint: "/", rm: false, hotplug: false, type: "part" },
			{ path: "/dev/sda3", uuid: "internal", fstype: "ext4", mountpoint: null, rm: false, hotplug: false, type: "part" },
			{ path: "/dev/sdb1", uuid: "USB", label: "Photos", fstype: "exfat", mountpoint: "/run/media/user/Photos", rm: true, hotplug: true, type: "part" },
			{ path: "/dev/sdc1", uuid: null, label: "Photos", fstype: "ext4", mountpoint: "/mnt/my-data", rm: false, hotplug: false, type: "part" },
			{ path: "/dev/sdd1", uuid: "swap", fstype: "swap", mountpoint: null, rm: true, hotplug: true, type: "part" }
		] });
		const drives = Extras.parseDrives(raw, "[]");
		compare(drives.map(d => d.key), ["drive:USB", "drive:path:/dev/sdc1"]);
		compare(drives.map(d => d.name), ["Photos", "Photos"], "labels are display text, not identity");
		compare(Extras.parseDrives(raw, '["USB"]').map(d => d.key), ["drive:path:/dev/sdc1"]);
		compare(Extras.parseDrives("broken", "[]"), null, "a failed scan preserves the last good state");
	}

	function test_duplicateUuidAndStaleAction() {
		const raw = JSON.stringify({ blockdevices: [
			{ path: "/dev/sdb1", uuid: "clone", fstype: "vfat", rm: true, type: "part" },
			{ path: "/dev/sdc1", uuid: "clone", fstype: "vfat", rm: true, type: "part" }
		] });
		const drives = Extras.parseDrives(raw, "[]");
		compare(drives.map(d => d.key), ["drive:clone@/dev/sdb1", "drive:clone@/dev/sdc1"]);
		compare(Extras.driveAction([], drives[0].key, "open"), null, "unplugged drive cannot be acted on");
		compare(Extras.driveAction(drives, drives[0].key, "open"), ["udisksctl", "mount", "-b", "/dev/sdb1"]);
		compare(Extras.driveAction(drives, drives[0].key, "eject"), ["udisksctl", "power-off", "-b", "/dev/sdb1"]);
	}

	function test_foldersAndTrash() {
		const dirs = { downloads: "/home/me", documents: "/home/me/Documents" };
		const exists = p => ["/home/me/Downloads", "/home/me/Documents", "/srv/Shared"].includes(p);
		const folders = Extras.folderEntries("downloads,documents,none", '[{"name":"Shared","path":"/srv/Shared"}]', dirs, "/home/me", exists);
		compare(folders.map(f => f.path), ["/home/me/Downloads", "/home/me/Documents", "/srv/Shared"]);
		compare(Extras.folderEntries("downloads", "broken", { downloads: "/home/me" }, "/home/me", () => false), []);
		compare(Extras.trashCount("trash::item-count: 12"), 12);
		compare(Extras.trashCount("trash::item-count: nonsense"), null);
	}

	function test_gioDirectoryTypeOnThisMachine() {
		verify(Extras.isDirectoryInfo("standard::type: 2\n"));
		verify(Extras.isDirectoryInfo("standard::type: directory\n"));
		verify(!Extras.isDirectoryInfo("standard::type: 1\n"));
		verify(!Extras.isDirectoryInfo("standard::type: 20\n"));
	}
}
