# Usage: Claude CLI

To drop the Tritium Team workflow into your project for use with the **Claude CLI**, run the setup script:

```bash
# From the tritium-team repo
bash scripts/setup-team.sh --target /path/to/your/project
```

This installs:

- `CLAUDE.md` — declares the crew, instructs Claude to act as Bridge by default, plan first, and switch agents.
- `agents/` — contains all eight specialized agent prompts and histories.
- `world/` — sets up the mailboxes, locations, and direct communication logs.
- `SETTINGS.jsonc` — configuration settings for the workspace team.

## Slash commands (conventions, not plugins)

Claude CLI will automatically read `CLAUDE.md` and follow these instructions:

- `/agent <name>` — switch active agent (loads `agents/<name>/agent.md`).
- `/plan "<request>"` — Bridge writes a plan to `world/social/team/interactions/`.
- `/inbox` — runs `tritium inbox check --agent <current>` to read updates.
- `/handoff <to> "<subject>"` — open a handoff packet.

## Live coordination

Keep the Tritium Team coordinator server running in the background:

```bash
tritium serve
```

When you prompt Claude CLI:

> Check the Tritium inbox for sol.

Claude will run `tritium inbox check --agent sol` using its bash tool and report the results to you.

## Settings

Claude reads `SETTINGS.jsonc` at session start. Honor each agent's `independence` (≥7 means decide and act, don't ask) and `inbox_check_interval`.
