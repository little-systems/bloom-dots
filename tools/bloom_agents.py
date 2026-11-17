#!/usr/bin/env python3
"""`bloom agents status|connect|disconnect <agent>`: Bloom's agent integrations
(Bloom agent_alerts.rs at 63a9bf5) for Claude Code, Codex and OpenCode, shared
by Settings > Integrations and the CLI. Prints JSON.

Connect merges Bloom's hooks into ~/.claude/settings.json (CLAUDE_CONFIG_DIR)
or ~/.codex/hooks.json (CODEX_HOME), keeping every other setting, key order and
handler, after one `<file>.bloom-backup` of the original; for OpenCode it writes
plugins/bloom-notifications.js and plugins/bloom-notifications/index.js under
$XDG_CONFIG_HOME/opencode. Disconnect removes only Bloom's exact handlers or
unmodified plugins. A config that isn't plain JSON is never rewritten."""
import json
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
AGENTS = ("claude", "codex", "opencode")
HOOK_EVENTS = {
    "claude": ["Stop", "PermissionRequest", "Notification", "UserPromptSubmit", "PreToolUse", "PostToolUse",
               "PostToolUseFailure", "StopFailure", "SessionEnd"],
    "codex": ["Stop", "PermissionRequest", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Interrupt", "SessionEnd"],
}
PLUGINS = (ROOT / "integrations/opencode-bloom-v1.js", ROOT / "integrations/opencode-bloom-v2.js")


class AgentError(Exception):
    pass


def hook_command(root, agent):
    """The command agents run. Their shells interpret it, so a checkout path
    that needs more than single quotes is refused."""
    path = f"{root}/bin/bloom"
    if any(c in path for c in "'\"$`\\\n\r"):
        raise AgentError("The Bloom checkout path has characters agent hooks can't run safely; move it")
    return f"'{path}' agent-hook {agent}"


def hook_handler(command, agent):
    # Claude runs its hooks in the background so a slow start never delays it;
    # Codex waits for the hook, at most 3 s.
    if agent == "claude":
        return {"type": "command", "command": command, "async": True}
    return {"type": "command", "command": command, "timeout": 3}


def merge_hooks(config, command, agent, install):
    """Removes Bloom's exact command from every event, then (install) adds
    Bloom's handler per event. Everything else is left as it was."""
    if not isinstance(config, dict):
        raise AgentError("Agent configuration must be a JSON object")
    hooks = config.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise AgentError("hooks must be an object")
    for event in list(hooks):
        groups = hooks[event]
        if not isinstance(groups, list):
            raise AgentError(f"hooks.{event} must be an array")
        for group in groups:
            if not isinstance(group, dict) or not isinstance(group.get("hooks"), list):
                raise AgentError(f"hooks.{event} has an invalid hook group")
            group["hooks"] = [h for h in group["hooks"] if not (isinstance(h, dict) and h.get("command") == command)]
        hooks[event] = [g for g in groups if g["hooks"]]
        if not hooks[event]:
            del hooks[event]
    if install:
        for event in HOOK_EVENTS[agent]:
            group = {"hooks": [hook_handler(command, agent)]}
            if event == "Notification":
                group["matcher"] = "permission_prompt|elicitation_dialog"
            hooks.setdefault(event, []).append(group)


def _handlers(config, event):
    groups = config.get("hooks", {}).get(event, []) if isinstance(config.get("hooks"), dict) else []
    return [h for g in groups if isinstance(g, dict) and isinstance(g.get("hooks"), list) for h in g["hooks"]]


def hook_state(config, command, agent):
    """(installed, needs_update): installed once Stop has Bloom's command;
    current only when every event has this version's exact handler."""
    if not isinstance(config, dict):
        return False, False
    installed = any(isinstance(h, dict) and h.get("command") == command for h in _handlers(config, "Stop"))
    current = all(hook_handler(command, agent) in _handlers(config, e) for e in HOOK_EVENTS[agent])
    return installed, installed and not current


def agent_home(agent):
    home = Path(os.environ.get("HOME") or Path.home())
    if agent == "claude":
        return Path(os.environ.get("CLAUDE_CONFIG_DIR") or home / ".claude")
    if agent == "codex":
        return Path(os.environ.get("CODEX_HOME") or home / ".codex")
    return Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config") / "opencode"


def config_path(agent):
    return agent_home(agent) / {"claude": "settings.json", "codex": "hooks.json"}.get(agent, "plugins/bloom-notifications.js")


def plugin_paths():
    v1 = config_path("opencode")
    return v1, v1.with_suffix("") / "index.js"


def render_plugin(template):
    return template.read_text().replace('"__BLOOM_HOOK__"', json.dumps(str(ROOT / "bin/bloom")))


def same_plugin(a, b):
    return a.replace("\r\n", "\n") == b.replace("\r\n", "\n")


def _read(path):
    try:
        return path.read_text()
    except FileNotFoundError:
        return None


def _save(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        if path.exists():
            os.chmod(tmp, path.stat().st_mode & 0o7777)
        os.replace(tmp, path)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def state_file():
    home = Path(os.environ.get("HOME") or Path.home())
    return Path(os.environ.get("XDG_STATE_HOME") or home / ".local/state") / "bloom/agents.json"


def verified():
    try:
        data = json.loads(state_file().read_text())
    except (OSError, ValueError):
        return {}
    return {k: v for k, v in data.items() if k in AGENTS and isinstance(v, int)} if isinstance(data, dict) else {}


def forget_verification(agent):
    data = verified()
    if data.pop(agent, None) is not None:
        _save(state_file(), json.dumps(data) + "\n")


def status():
    known = verified()
    rows = []
    for agent in AGENTS:
        path = config_path(agent)
        if agent == "opencode":
            v1, v2 = plugin_paths()
            current = [same_plugin(_read(p) or "", render_plugin(t)) for p, t in zip((v1, v2), PLUGINS)]
            installed, needs_update = any(current), any(current) and not all(current)
        else:
            try:
                config = json.loads(_read(path) or "null")
            except ValueError:
                config = None
            installed, needs_update = hook_state(config, hook_command(ROOT, agent), agent)
        rows.append({"agent": agent, "installed": installed, "needsUpdate": needs_update,
                     "verifiedAt": known.get(agent), "path": str(path)})
    return {"integrations": rows}


def configure_opencode(install):
    files = [(path, render_plugin(template)) for path, template in zip(plugin_paths(), PLUGINS)]
    originals = []
    for path, source in files:
        old = _read(path)
        if old is not None and not same_plugin(old, source):
            raise AgentError(f"The Bloom plugin at {path} was modified. Move it aside before changing this integration.")
        originals.append(old)
    for (path, source), original in zip(files, originals):
        if install:
            _save(path, source)
        elif original is not None:
            path.unlink()
    if not install:
        try:
            files[1][0].parent.rmdir()
        except OSError:
            pass


def configure(agent, install):
    if agent not in AGENTS:
        raise AgentError(f"Unknown agent: {agent}")
    if agent == "opencode":
        configure_opencode(install)
    else:
        path = config_path(agent)
        command = hook_command(ROOT, agent)
        original = _read(path)
        if original is None and not install:
            return
        try:
            config = json.loads(original) if original is not None else {}
        except ValueError as error:
            raise AgentError(f"Cannot read {path}: {error}") from None
        merge_hooks(config, command, agent, install)
        if original is not None:
            # One backup of the file as it was before Bloom first changed it.
            backup = path.with_name(path.name + ".bloom-backup")
            if not backup.exists():
                _save(backup, original)
        _save(path, json.dumps(config, indent=2, ensure_ascii=False) + "\n")
    forget_verification(agent)


def main(argv):
    action = argv[1] if len(argv) > 1 else ""
    try:
        if action == "status" and len(argv) == 2:
            print(json.dumps(status()))
            return 0
        if action in ("connect", "disconnect") and len(argv) == 3:
            configure(argv[2], action == "connect")
            print(json.dumps({"ok": True}))
            return 0
        raise AgentError("usage: bloom agents status | connect <agent> | disconnect <agent>")
    except (AgentError, OSError) as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
