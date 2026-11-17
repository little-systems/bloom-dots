# Agent live activities

Bloom shows Claude Code, Codex, and OpenCode activity in the Island.

1. Open **Settings → Integrations** and connect the agent.
2. Restart the agent to load the hooks or plugin. In Codex, review and trust the Bloom hooks in Settings or run `/hooks` in the CLI. If OpenCode 2 uses its shared service, stop it with `opencode service stop` before reopening OpenCode.
3. Submit a new prompt. **Connected** appears after Bloom receives the first real event. **Test notch** sends a temporary preview.

Bloom uses local Quickshell IPC. The hook forwards the agent and session identifiers, the project folder name, a limited activity label, and timing and process information. Prompt text, responses, and tool arguments stay with the agent. Bloom uses the agent process and its start time to clear activities when sessions exit.

**Update** refreshes Bloom’s hooks or plugins. OpenCode adapters have a private hash receipt beside each file. Bloom uses it to recognize installed versions and keeps a backup before updating; locally edited adapters produce an error for you to resolve. **Disconnect** removes the Bloom integration from the agent configuration. Restart the agent after either change. Turning off **Notch Notifications** in Bloom clears current activities and keeps your integrations configured.

## CLI

```sh
bloom agents status
bloom agents connect claude       # or codex or opencode
bloom agents disconnect claude
```

The CLI reports status and errors as JSON. Integration commands operate on the current user's configuration.
