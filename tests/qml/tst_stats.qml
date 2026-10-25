import QtQuick
import QtTest
import "../../shell/services/stats.js" as Stats

TestCase {
	name: "Stats"

	function sample(cpuLine, memAvail, rx, tx, disk) {
		return [
			cpuLine,
			"cpu0 1 2 3 4 5 6 7 8 0 0",
			"intr 12345",
			"---",
			"MemTotal:       16000000 kB",
			"MemFree:         1000000 kB",
			`MemAvailable:   ${memAvail} kB`,
			"---",
			"Inter-|   Receive                                                |  Transmit",
			" face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed",
			`    lo: 999999 10 0 0 0 0 0 0 999999 10 0 0 0 0 0 0`,
			`wlan0: ${rx} 100 0 0 0 0 0 0 ${tx} 80 0 0 0 0 0 0`,
			`  eth0: 500 5 0 0 0 0 0 0 300 3 0 0 0 0 0 0`,
			"---",
			String(disk),
			""
		].join("\n");
	}

	function test_parse() {
		const s = Stats.parse(sample("cpu  100 0 50 800 50 0 0 0 0 0", 4000000, 10000, 2000, 107374182400));
		compare(s.cpu, { idle: 850, total: 1000 });
		compare(s.mem, { total: 16000000, available: 4000000 });
		compare(s.net, { rx: 10500, tx: 2300 }, "lo excluded, others summed");
		compare(s.diskAvail, 107374182400);
	}

	function test_parseRejectsGarbage() {
		compare(Stats.parse("nothing here"), null);
	}

	function test_cpuPercent() {
		const a = { idle: 850, total: 1000 };
		const b = { idle: 1100, total: 1500 };
		compare(Stats.cpuPercent(a, b), 50);
		compare(Stats.cpuPercent(null, b), 0);
		compare(Stats.cpuPercent(b, b), 0, "no time passed");
	}

	function test_ramPercent() {
		compare(Stats.ramPercent({ total: 16000000, available: 4000000 }), 75);
		compare(Stats.ramPercent({ total: 0, available: 0 }), 0);
	}

	function test_netSpeed() {
		compare(Stats.netSpeed({ rx: 1000, tx: 500 }, { rx: 4000, tx: 2000 }, 3), [500, 1000]);
		compare(Stats.netSpeed(null, { rx: 4000, tx: 2000 }, 3), [0, 0]);
		compare(Stats.netSpeed({ rx: 9000, tx: 9000 }, { rx: 4000, tx: 2000 }, 3), [0, 0], "counter reset");
	}

	function test_diskGB() {
		compare(Stats.diskGB(107374182400), 100);
	}

	// Bloom formatBytes.
	function test_formatBytes() {
		compare(Stats.formatBytes(512), "512B");
		compare(Stats.formatBytes(1536), "1.5K");
		compare(Stats.formatBytes(2 * 1024 * 1024), "2.0M");
	}
}
