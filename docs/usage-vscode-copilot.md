# Usage: VS Code GitHub Copilot

To drop the Tritium Team workflow into your project for use with **VS Code GitHub Copilot**, run the setup script:

**Windows (PowerShell):**
```powershell
powershell scripts/setup-team.ps1 -Target "/path/to/your/project"
```

**macOS/Linux (Bash):**
```bash
bash scripts/setup-team.sh --target "/path/to/your/project"
```

This installs:

- `.github/copilot-instructions.md` — declares the crew, instructs Copilot to act as Bridge by default, and how to load specialists from `agents/`.
- `agents/` — contains all eight specialized agent prompts.
- `world/` — sets up the mailboxes, locations, and direct communication logs.
- `SETTINGS.jsonc` — configuration settings for the workspace team.

## How Copilot Interacts with the Team

VS Code GitHub Copilot automatically reads `.github/copilot-instructions.md` on startup:

- **Default Agent (Bridge)**: When you prompt Copilot without mentioning a specific agent, it adopts the **Bridge** dispatcher personality.
- **Specialists**: Mentions like `@Sol`, `@Vex`, `@Rook`, `@Robert`, `@Lux`, `@Nova`, or `@Jesse` prompt Copilot to load that agent's system prompt from `agents/<name>/agent.md` and act as that specialist.

## Live Coordination

Keep the Tritium Team coordinator server running in the background:

```bash
tritium serve
```

This allows custom agents to run `tritium inbox check --agent <name>` using their terminal tool to read messages.
