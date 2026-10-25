// System counters for the status widgets (Bloom read the same from Windows).
// `parse` takes SystemStats' command output: /proc/stat, /proc/meminfo,
// /proc/net/dev and `df` free bytes, separated by lines of "---".

function parse(text) {
	const parts = text.split(/^---$/m);
	if (parts.length < 4)
		return null;
	const cpu = _cpu(parts[0]);
	const disk = Number(parts[3].trim());
	if (!cpu || !isFinite(disk))
		return null;
	return { cpu: cpu, mem: _mem(parts[1]), net: _net(parts[2]), diskAvail: disk };
}

function _cpu(s) {
	const line = s.split("\n").find(l => l.startsWith("cpu "));
	if (!line)
		return null;
	const v = line.trim().split(/\s+/).slice(1).map(Number);
	// user nice system idle iowait irq softirq steal (guest time is in user).
	const total = v.slice(0, 8).reduce((a, b) => a + (b || 0), 0);
	return { idle: v[3] + (v[4] || 0), total: total };
}

function _mem(s) {
	const get = key => {
		const m = s.match(new RegExp("^" + key + ":\\s+(\\d+)", "m"));
		return m ? Number(m[1]) : 0;
	};
	return { total: get("MemTotal"), available: get("MemAvailable") };
}

function _net(s) {
	let rx = 0;
	let tx = 0;
	s.split("\n").forEach(line => {
		const m = line.match(/^\s*([^:|]+):\s*(.*)$/);
		if (!m || m[1].trim() === "lo")
			return;
		const f = m[2].trim().split(/\s+/).map(Number);
		rx += f[0] || 0;
		tx += f[8] || 0;
	});
	return { rx: rx, tx: tx };
}

function cpuPercent(prev, cur) {
	if (!prev || !cur)
		return 0;
	const dt = cur.total - prev.total;
	return dt > 0 ? Math.round(100 * (1 - (cur.idle - prev.idle) / dt)) : 0;
}

function ramPercent(mem) {
	return mem.total > 0 ? 100 * (mem.total - mem.available) / mem.total : 0;
}

// Bytes per second up and down; 0 without a previous sample or after a
// counter reset.
function netSpeed(prev, cur, seconds) {
	if (!prev || !cur || seconds <= 0)
		return [0, 0];
	return [Math.max(0, Math.round((cur.tx - prev.tx) / seconds)), Math.max(0, Math.round((cur.rx - prev.rx) / seconds))];
}

// GiB, labelled GB as on Windows.
function diskGB(bytes) {
	return Math.round(bytes / 1073741824);
}

// Bloom formatBytes: "512B", "1.5K", "2.0M".
function formatBytes(bytes) {
	if (bytes < 1024)
		return `${bytes}B`;
	if (bytes < 1024 * 1024)
		return `${(bytes / 1024).toFixed(1)}K`;
	return `${(bytes / (1024 * 1024)).toFixed(1)}M`;
}
