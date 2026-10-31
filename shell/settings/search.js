.import "search-index.js" as Index

// Settings' search: names that start with the words first, then names that hold them.
function find(query) {
	const q = String(query || "").trim().toLowerCase();
	if (!q) return [];
	const score = row => {
		const label = row.label.toLowerCase();
		return label.startsWith(q) ? 0 : label.includes(" " + q) ? 1 : label.includes(q) ? 2 : -1;
	};
	return Index.ROWS.map(row => ({ row: row, score: score(row) })).filter(r => r.score >= 0)
		.sort((a, b) => a.score - b.score || a.row.label.localeCompare(b.row.label)).slice(0, 10).map(r => r.row);
}
