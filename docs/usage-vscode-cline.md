# Usage: VS Code Cline / Cursor / Windsurf

To drop the Tritium Team workflow into your project for use with **VS Code Cline**, **Cursor**, or **Windsurf**, run the setup script:

**Windows (PowerShell):**
```powershell
powershell scripts/setup-team.ps1 -Target "/path/to/your/project"
```

**macOS/Linux (Bash):**
```bash
bash scripts/setup-team.sh --target "/path/to/your/project"
```

This installs the following rules files in your project root:
* **VS Code Cline**: `.clinerules`
* **Cursor**: `.cursorrules`
* **Windsurf**: `.cursorrules` (Windsurf reads standard `.cursorrules` or `.clinerules`)

It also drops in:
* `agents/` — containing all eight specialized agent prompts.
* `world/` — setting up mailboxes, locations, and direct communication logs.
* `SETTINGS.jsonc` — configuration settings for the workspace team.

## How Cline and Cursor Interact with the Team

* **Default Agent (Bridge)**: When you prompt your tool, it reads `.clinerules` or `.cursorrules` and adopts the **Bridge** planner/dispatcher personality by default.
* **Handoffs & Specialists**: When a task is delegated (e.g., coding, narrative writing, QA, research), tell the agent: *"Switch to Sol to implement the changes"* or *"Act as Robert and research this topic"*. The tool will load the appropriate system prompt from `agents/<name>/agent.md` and continue the task under that agent's voice, constraints, and instructions.
* **Mailboxes & Messages**: Agents will check their mailboxes under `world/social/mailbox/<agent-name>/` for notes. You can leave notes for them or ask them to exchange DMs by writing to each other's mailboxes.

## Live Coordination

Keep the Tritium Team coordinator server running in the background:

```bash
tritium serve
```

This allows agents to run `tritium inbox check --agent <name>` using their terminal tool to read messages.
