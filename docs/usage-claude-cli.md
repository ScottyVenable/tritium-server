# Usage: Claude CLI

```bash
bash scripts/install-adapter.sh --target /path/to/repo --adapter claude-cli
```

This installs:

- `CLAUDE.md` — declares the crew, tells Claude to act as Bridge by default.
- `agents/<name>.md` — one per Tritium agent.

## Slash commands (conventions, not plugins)

- `/agent <name>` — switch active agent.
- `/plan "<request>"` — Bridge writes a plan to `world/social/team/interactions/`.
- `/inbox` — `tritium inbox check --agent <current>`.
- `/handoff <to> "<subject>"` — open a handoff packet.

## Live coordination

```bash
bash /path/to/tritium/scripts/runtime-deps.sh ensure
cd /path/to/tritium/runtime/server
npm run doctor
node ../cli/tritium.js serve
```

Tell Claude things like:

> Check the Tritium inbox for sol.

and Claude will run `tritium inbox check --agent sol` via its bash tool, then respond.

## Settings

Claude reads `SETTINGS.jsonc` at session start. Honor each agent's `independence` (≥7 = decide, don't ask) and `inbox_check_interval`.
