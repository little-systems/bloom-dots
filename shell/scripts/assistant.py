#!/usr/bin/env python3
"""Talks to Gemini for the launcher's chat, one JSON object per line on stdout.

The request comes in on stdin and the key from the keyring, so neither ever
appears on a command line. `--check` tests the key instead.
"""
import json
import os
import subprocess
import sys
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


def chat(api_key):
    job = json.load(sys.stdin)
    url = "%s/models/%s:streamGenerateContent?alt=sse" % (BASE, job["model"])
    with request(url, api_key, {"contents": job["contents"]}) as reply:
        for raw in reply:
            line = raw.decode("utf-8", "replace").strip()
            if not line.startswith("data:"):
                continue
            event = json.loads(line[5:])
            for candidate in event.get("candidates", []):
                for part in candidate.get("content", {}).get("parts", []):
                    if part.get("text"):
                        say(delta=part["text"])
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
