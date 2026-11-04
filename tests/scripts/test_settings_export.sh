#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
python3 - "$ROOT/shell/scripts/export-settings.py" <<'PY'
from pathlib import Path
import subprocess
import sys
import tempfile
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    source, destination = root / "settings.json", root / "export # café.json"
    source.write_text('{"bloom-theme-mode":"dark"}\n')
    def run():
        return subprocess.run(["python3", sys.argv[1], str(source), str(destination)], capture_output=True, timeout=5)
    assert run().returncode == 0
    assert destination.read_bytes() == source.read_bytes()
    assert destination.stat().st_mode & 0o777 == 0o600
    expected = destination.read_bytes()
    for bad in ['{broken', '[]', '{"value":NaN}']:
        source.write_text(bad)
        assert run().returncode != 0
        assert destination.read_bytes() == expected
    source.write_text('{}')
    destination.unlink()
    target = root / "foreign.json"
    target.write_text('keep')
    destination.symlink_to(target)
    assert run().returncode != 0
    assert target.read_text() == 'keep'
print('ok - export commits a private copy and preserves existing data on invalid input or unsafe destination')
PY
