#!/usr/bin/env python3
"""Talks to Gemini for the launcher's chat, one JSON object per line on stdout.

The request comes in on stdin and the key from the keyring, so neither ever
appears on a command line. `--check` tests the key instead.
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

BASE = os.environ.get("BLOOM_GEMINI_URL", "https://generativelanguage.googleapis.com/v1beta")


def say(**fields):
    print(json.dumps(fields), flush=True)


def key():
    try:
        out = subprocess.run(["secret-tool", "lookup", "service", "bloom", "key", "gemini"],
                             capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return out.stdout.strip() if out.returncode == 0 else ""


def error_code(status):
    if status in (400, 401, 403):
        return "bad-key"
    if status == 404:
        return "bad-model"
    if status == 429:
        return "rate-limit"
    return "server"


def request(url, api_key, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, headers={"x-goog-api-key": api_key, "Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=60)


def check(api_key):
    with request(BASE + "/models?pageSize=1", api_key):
        say(ok=True)


# Budgets: the whole answer, its size, and any single stream line.
MAX_ANSWER_CHARS = 64 * 1024
MAX_LINE_BYTES = 1024 * 1024
DEADLINE_S = 180


def deadline():
    # Tests may only shorten it.
    try:
        return min(DEADLINE_S, float(os.environ.get("BLOOM_AI_DEADLINE_S", DEADLINE_S)))
    except ValueError:
        return DEADLINE_S


def chat(api_key):
    job = json.load(sys.stdin)
    url = "%s/models/%s:streamGenerateContent?alt=sse" % (BASE, job["model"])
    ends = time.monotonic() + deadline()
    sent = 0
    with request(url, api_key, {"contents": job["contents"]}) as reply:
        while True:
            if time.monotonic() > ends:
                say(error="timeout")
                return
            raw = reply.readline(MAX_LINE_BYTES + 1)
            if not raw:
                break
            if len(raw) > MAX_LINE_BYTES:
                say(error="too-long")
                return
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            event = json.loads(line[5:])
            for candidate in event.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    text = part.get("text")
                    if not text:
                        continue
                    if sent + len(text) > MAX_ANSWER_CHARS:
                        say(error="too-long")
                        return
                    sent += len(text)
                    say(delta=text)
    say(done=True)


def main():
    api_key = key()
    if not api_key:
        say(error="no-key")
        return
    try:
        check(api_key) if "--check" in sys.argv else chat(api_key)
    except urllib.error.HTTPError as failure:
        say(error=error_code(failure.code))
    except (urllib.error.URLError, TimeoutError, OSError):
        say(error="offline")
    except (ValueError, KeyError):
        say(error="server")


if __name__ == "__main__":
    main()
