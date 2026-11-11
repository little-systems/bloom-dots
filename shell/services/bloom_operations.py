"""One typed result for every external command Bloom runs (stdlib only).

`run_operation` starts the command in its own process group, bounds its time
and output, kills the whole group on timeout or flooding, and returns exactly
one terminal result:

    id, component, action, state (success | failure | cancelled), errorCode,
    startedMonotonic, durationMs, retry, exitCode, signal, verified,
    stdout, stderr, truncated

errorCode: None | start-failed | timeout | exit | signal | output-limit |
verify-failed | cancelled. `expected_failure` marks a probe whose non-zero
exit is a normal answer (for example "not enabled"): its outcome is still
recorded, at info level, so it doesn't read as a problem. `cancel` (a threading.Event) ends an owned
operation early; its whole process group is killed. `retry` is the caller's statement that repeating the request is
safe (a desired-state setter); toggles and destructive actions pass False and
must not be replayed after an uncertain result. `verify` is a readback that
decides `verified`; without it `verified` is None. Events record the action
and outcome only, never argv, input or output.
"""
import os
import selectors
import signal
import subprocess
import time
import uuid

OUTPUT_LIMIT = 64 * 1024


def _kill_group(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


def run_operation(component, action, argv, timeout=20.0, output_limit=OUTPUT_LIMIT, events=None, verify=None,
                  retry=False, input=None, cwd=None, env=None, cancel=None, expected_failure=False):
    op = uuid.uuid4().hex[:12]
    started = time.monotonic()
    result = {"id": op, "component": component, "action": action, "state": "failure", "errorCode": None,
              "startedMonotonic": round(started, 3), "durationMs": 0, "retry": bool(retry), "exitCode": None,
              "signal": None, "verified": None, "stdout": "", "stderr": "", "truncated": False}
    if events is not None:
        events.emit("operation.started", op=op, stage=action, action=action)
    try:
        process = subprocess.Popen(argv, stdin=subprocess.PIPE if input is not None else subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd, env=env,
                                   start_new_session=True)
    except OSError:
        result["errorCode"] = "start-failed"
        return _finish(result, started, events, expected_failure)
    if input is not None:
        try:
            process.stdin.write(input.encode() if isinstance(input, str) else input)
        except BrokenPipeError:
            pass
        process.stdin.close()
    buffers = {process.stdout: bytearray(), process.stderr: bytearray()}
    selector = selectors.DefaultSelector()
    for stream in buffers:
        selector.register(stream, selectors.EVENT_READ)
    deadline = started + timeout
    while selector.get_map():
        if cancel is not None and cancel.is_set():
            result["errorCode"] = "cancelled"
            break
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            result["errorCode"] = "timeout"
            break
        for key, _ in selector.select(min(remaining, 0.2)):
            chunk = os.read(key.fileobj.fileno(), 65536)
            if not chunk:
                selector.unregister(key.fileobj)
                continue
            buffer = buffers[key.fileobj]
            room = output_limit - len(buffer)
            if room > 0:
                buffer += chunk[:room]
            if len(chunk) > room:
                result["truncated"] = True
        if result["truncated"] and len(buffers[process.stdout]) >= output_limit:
            result["errorCode"] = "output-limit"
            break
    selector.close()
    if result["errorCode"] in ("timeout", "output-limit", "cancelled"):
        _kill_group(process)
    try:
        code = process.wait(timeout=max(0.1, deadline - time.monotonic()) if result["errorCode"] is None else 2)
    except subprocess.TimeoutExpired:
        _kill_group(process)
        code = process.wait()
        result["errorCode"] = result["errorCode"] or "timeout"
    # A command that exits leaves no background children in its group.
    _kill_group(process)
    for stream in buffers:
        stream.close()
    result["stdout"] = buffers[process.stdout].decode(errors="replace")
    result["stderr"] = buffers[process.stderr].decode(errors="replace")
    if code < 0:
        result["signal"] = -code
    else:
        result["exitCode"] = code
    if result["errorCode"] is None:
        if code < 0:
            result["errorCode"] = "signal"
        elif code != 0:
            result["errorCode"] = "exit"
        elif verify is not None:
            try:
                result["verified"] = bool(verify(result))
            except Exception:  # noqa: BLE001 - a broken readback is a failed readback
                result["verified"] = False
            if not result["verified"]:
                result["errorCode"] = "verify-failed"
    if result["errorCode"] is None:
        result["state"] = "success"
    elif result["errorCode"] == "cancelled":
        result["state"] = "cancelled"
    return _finish(result, started, events, expected_failure)


def _finish(result, started, events, expected_failure=False):
    result["durationMs"] = round((time.monotonic() - started) * 1000)
    if events is not None:
        quiet = result["state"] == "success" or expected_failure
        events.emit("operation.finished", level="info" if quiet else "warning",
                    op=result["id"], stage=result["action"], outcome=result["state"], error=result["errorCode"],
                    action=result["action"], exitCode=result["exitCode"], signal=result["signal"],
                    durationMs=result["durationMs"], verified=result["verified"], truncated=result["truncated"])
    return result
