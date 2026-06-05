# Tritium Team

**A portable, local-first skilled team workflow layer you can drop into any AI environment.**

[![Version](https://img.shields.io/badge/version-v0.1.0-blue?style=flat-square)](https://github.com/ScottyVenable/tritium/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Status](https://img.shields.io/badge/status-pre--release-orange?style=flat-square)](https://github.com/ScottyVenable/tritium)

---

## What is Tritium Team?

**Tritium Team** is NOT another bland, standalone AI agent tool. It is a **portable team workflow layer** designed to drop directly into your existing development environments and AI tools (such as VS Code Cline, Cursor, Claude CLI, Antigravity CLI, or GitHub Copilot).

It transforms your standard, single-agent interactions into a collaborative, highly-skilled team of **eight specialized personalities**. Each member has their own voice, history, expertise, mailboxes, and persistent memory system, letting them collaborate with each other and with you using a local-first SQLite message bus and a real-time web dashboard.

---

## The Crew

The team consists of eight distinct roles, working together to move projects from idea to release:

| Agent | Role | Specialty | Prompt Path |
|---|---|---|---|
| 🌐 **Bridge** | Planner · Dispatcher · Watchdog | Decomposes tasks into numbered plans, coordinates specialists, and audits progress | `agents/bridge/agent.md` |
| 💻 **Sol** | Lead Programmer | Software implementation, architecture, automation, CI/CD, and refactoring | `agents/sol/agent.md` |
| ✍️ **Vex** | Content Architect | High-quality narrative text, lore, user manuals, and authored documentation | `agents/vex/agent.md` |
| 🔍 **Rook** | QA & Release Engineer | Test verification, bug reproduction, code auditing, and release gating | `agents/rook/agent.md` |
| 📚 **Robert** | Master Researcher | Sourcing external knowledge, competitive analysis, and resolving information gaps | `agents/robert/agent.md` |
| 🎨 **Lux** | Visuals & Art Director | Style guides, design specifications, UI/UX wireframes, and aesthetics | `agents/lux/agent.md` |
| ⚙️ **Nova** | Gameplay Systems | Mechanics design, math formulas, progression curves, and balance sheets | `agents/nova/agent.md` |
| 🗃️ **Jesse** | Repository Manager | Tracking tasks, managing backlogs, labels, PR workflows, and milestones | `agents/jesse/agent.md` |

---

## How It Works

1. **Drop it in**: You run the setup script in your project repository. It automatically generates the required workflow directory (`agents/`, `world/`), default settings, and drop-in configuration rules for whatever AI tools you use.
2. **AI Tool Autoloads Rules**: When you open your AI tool (e.g. VS Code Cline or Claude CLI) in that repo, it detects the rule files (e.g. `.clinerules` or `CLAUDE.md`) and automatically adopts the **Bridge** dispatcher personality.
3. **Collaborative Handoffs**: When a task is code-focused, the AI switches roles to **Sol**, loads Sol's system prompt and memories, performs the task, and leaves a handoff note for **Rook** (QA) in their local mailbox.
4. **Local Message Bus**: All agent messages (IMs, emails, plans, and files) are tracked locally in a SQLite database and broadcasted in real-time to a local dashboard.

---

## Quickstart

### 1. Install Tritium Team Globally
First, run the installer to check system requirements (Node 20+, Python 3.11+), set up the global runtime directory (`~/.tritium-team/`), initialize the ledger, and install CLI utilities.

**Windows (PowerShell):**
```powershell
powershell scripts/install.ps1 -InstallDeps -WithClaude -WithGemini -WithCopilot
```

**macOS/Linux (Bash):**
```bash
bash scripts/install.sh --install-deps --with-claude --with-gemini --with-copilot
```

Verify the global installation at any time:
```bash
# Windows
powershell scripts/verify.ps1

# macOS/Linux
bash scripts/verify.sh
```

### 2. Drop the Workflow into a Project
To drop the Tritium Team workflow (prompts, memory directories, and rule integrations) into any target coding repository, run the setup script:

**Windows (PowerShell):**
```powershell
powershell scripts/setup-team.ps1 -Target "/path/to/your/project"
```

**macOS/Linux (Bash):**
```bash
bash scripts/setup-team.sh --target "/path/to/your/project"
```

This will automatically create the following in your target project:
* `agents/` — Copy of all eight agent prompts and schema definitions.
* `world/` — The mailbox system, direct communication folders, and project context files.
* `SETTINGS.jsonc` — Local workflow configurations.
* **Tool Rules** — Universal drop-in files for AI tools:
  * VS Code Cline (`.clinerules`)
  * Claude CLI (`CLAUDE.md`)
  * Cursor (`.cursorrules`)
  * Antigravity / Gemini CLI (`.antigravityrules`, `GEMINI.md`)
  * GitHub Copilot (`.github/copilot-instructions.md`)

### 3. Start the Live Coordination Server
Tritium Team runs a local-first coordination dashboard and SQLite database so your agents can communicate. Start it from the repository root:

```bash
# Start the server CLI
tritium serve

# Or run it directly from the runtime server directory:
cd runtime/server
npm install
npm start
```
Open your browser to **`http://localhost:7330`** to view the live dashboard stream.

---

## Master Settings (`SETTINGS.jsonc`)

Copy `SETTINGS.example.jsonc` to `SETTINGS.jsonc` in your project root to configure agent properties:

```jsonc
{
  "global": {
    "default_model": "claude-sonnet-4.5",  // Model inherited by all agents unless overridden
    "dashboard_port": 7330,
    "db_path": "./.tritium/tritium.db",
    "dryRun": true                         // Flip to false to allow active API executions
  },
  "agents": {
    "bridge": {
      "independence": 7,     // 0-10: Higher means they make decisions without asking you
      "verbosity": 3,        // 0-5: Control prompt output sizes
      "inbox_check_interval": 1,
      "enabled": true
    },
    "sol": {
      "independence": 6,
      "verbosity": 4,
      "enabled": true
    }
  }
}
```

---

## Documentation

* [Architecture & Data Flow](docs/architecture.md) — System design, SQLite schema, and dashboard WebSocket details.
* [Settings Reference](docs/settings-reference.md) — Master guide for all tunables.
* [Troubleshooting](docs/troubleshooting.md) — Solves common environment, Node, and Python runtime bugs.
* [Adding a New Agent](docs/adding-a-new-agent.md) — Command reference to expand the crew.

### Tool Integration Guides
* [VS Code Cline, Cursor, and Windsurf](docs/usage-vscode-cline.md) — Setup and usage for rule-based editors.
* [VS Code GitHub Copilot](docs/usage-vscode-copilot.md) — Custom agents and prompt instructions.
* [Claude CLI](docs/usage-claude-cli.md) — Command-line chat tool workflows.
* [Gemini CLI / Antigravity CLI](docs/usage-gemini-cli.md) — Custom instructions for Gemini-based CLIs.
* [OpenAI / LM Studio API](docs/usage-api-openai-lmstudio.md) — Connecting local models.

---

## License

MIT — see [LICENSE](LICENSE).
