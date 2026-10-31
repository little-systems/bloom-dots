#!/usr/bin/env bash
# assistant.py against a local fake Gemini and a fake keyring. No real key, no
# real network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
T="$(mktemp -d)"
SERVER=""
trap '[[ -n "$SERVER" ]] && kill "$SERVER" 2>/dev/null; rm -rf "$T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$T/bin"
cat > "$T/bin/secret-tool" <<SH
#!/bin/sh
[ -f "$T/key" ] && cat "$T/key" && exit 0
exit 1
SH
chmod +x "$T/bin/secret-tool"
export PATH="$T/bin:$PATH"
cat > "$T/server.py" <<'PY'
import http.server, json, sys
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _deny(self):
        if self.headers.get("x-goog-api-key") != "good":
            self.send_response(403); self.end_headers(); return True
    def do_GET(self):
        if self._deny(): return
        self.send_response(200); self.end_headers(); self.wfile.write(b"{}")
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self._deny(): return
        if "missing-model" in self.path:
            self.send_response(404); self.end_headers(); return
        self.send_response(200); self.end_headers()
        said = body["contents"][-1]["parts"][0]["text"]
        for word in ("You said ", said):
            event = {"candidates": [{"content": {"parts": [{"text": word}]}}]}
            self.wfile.write(("data: " + json.dumps(event) + "\n\n").encode())
s = http.server.HTTPServer(("127.0.0.1", 0), H)
print(s.server_port, flush=True)
s.serve_forever()
PY
python3 "$T/server.py" > "$T/port" &
SERVER=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do [[ -s "$T/port" ]] && break; sleep 0.1; done
BLOOM_GEMINI_URL="http://127.0.0.1:$(cat "$T/port")"
export BLOOM_GEMINI_URL
run() { printf '%s' "$1" | python3 "$ROOT/shell/scripts/assistant.py"; }
JOB='{"model":"m","contents":[{"role":"user","parts":[{"text":"hi"}]}]}'

[[ "$(run "$JOB")" == *'"error": "no-key"'* ]] || fail "no key wasn't reported"
echo "ok - a missing key says so"
echo bad > "$T/key"
[[ "$(run "$JOB")" == *'"error": "bad-key"'* ]] || fail "a bad key wasn't reported"
[[ "$(python3 "$ROOT/shell/scripts/assistant.py" --check)" == *bad-key* ]] || fail "check passed a bad key"
echo "ok - a bad key fails, and the check says so"
echo good > "$T/key"
out="$(run "$JOB")"
[[ "$out" == *'"delta": "You said "'* && "$out" == *'"delta": "hi"'* && "$out" == *'"done": true'* ]] || fail "no streamed reply: $out"
[[ "$(python3 "$ROOT/shell/scripts/assistant.py" --check)" == *'"ok": true'* ]] || fail "check failed a good key"
echo "ok - a good key streams the reply"
[[ "$(run '{"model":"missing-model","contents":[]}')" == *bad-model* ]] || fail "a bad model wasn't reported"
echo "ok - a bad model says so"
kill "$SERVER"; wait "$SERVER" 2>/dev/null || true; SERVER=""
[[ "$(run "$JOB")" == *offline* ]] || fail "no server wasn't reported"
echo "ok - no connection says so"
