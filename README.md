# Tritium

**A portable, local-first multi-agent workflow coordination layer.**

[![Version](https://img.shields.io/badge/version-v0.1.0-blue?style=flat-square)](https://github.com/ScottyVenable/tritium/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Status](https://img.shields.io/badge/status-pre--release-orange?style=flat-square)](https://github.com/ScottyVenable/tritium)

---

## What is Tritium?

Tritium is a portable, self-contained multi-agent workflow coordination layer you can drop into a repository or local CLI environment. It ships a 9-agent roster (Bridge, Scout, Sol, Jesse, Vex, Rook, Robert, Lux, Nova), a local SQLite message bus, a live dashboard at `localhost:7330`, a CLI, and drop-in adapters for VS Code Copilot, Claude CLI, Gemini CLI, and OpenAI-compatible endpoints such as LM Studio.

---

## The Crew

| Agent | Role | Specialty |
|---|---|---|
| **Bridge** | Planner · dispatcher · watchdog | Decomposes requests, routes work, audits handoffs |
| **Scout** | Baseline agent | Lightweight status checks and routine lookups |
| **Sol** | Lead programmer | Implementation, architecture, automation, CI/CD |
| **Jesse** | Repository manager | Issues, project boards, milestones, labels, wiki |
| **Vex** | Content architect | Narrative text, authored docs, content tables |
| **Rook** | QA & release engineer | Build verification, reproduction cases, release gates |
| **Robert** | Research specialist | External knowledge, references, gap analysis |
| **Lux** | Visuals & art direction | Style guides, UI/UX briefs, asset specifications |
| **Nova** | Systems design | Mechanics, progression, balance formulas |

For the handoff matrix and interaction rules, see [world/social/team/TEAM.md](world/social/team/TEAM.md).

---

## What's in the Box

```text
tritium/
├── agents/                 # Canonical agent definitions
│   ├── bridge/
│   ├── jesse/
│   ├── lux/
│   ├── nova/
│   ├── robert/
│   ├── rook/
│   ├── scout/
│   ├── sol/
│   └── vex/
├── adapters/               # Drop-in integrations
│   ├── claude-cli/
│   ├── gemini-cli/
│   ├── github-copilot-local/
│   ├── github-copilot-remote/
│   └── openai-lmstudio/
├── data/registry/          # Model registry and ledger-related data
├── docs/                   # Architecture, usage guides, troubleshooting
├── runtime/                # Server, dashboard, CLI, schemas, heartbeat
│   ├── cli/
│   ├── dashboard/
│   ├── heartbeat/
│   ├── schemas/
│   └── server/
├── scripts/                # Install, verify, package, scaffolding, helpers
├── world/                  # Snapshot of the crew's living world
├── AGENTS.md
├── CHANGELOG.md
├── LICENSE
└── SETTINGS.example.jsonc
```

---

## Quickstart

### 1. Install Tritium

The unified installer checks requirements (Node 20+, Python 3.11+, git), sets up `~/.tritium-os/`, records the repo root for the launcher, installs helper scripts into `~/.tritium-os/bin`, and ensures all 9 mailboxes exist.

```bash
# Check + local setup
bash scripts/install.sh

# Optional deps and adapter CLIs
bash scripts/install.sh --install-deps --with-claude --with-gemini --with-copilot

# Windows
powershell -File scripts/install.ps1 -InstallDeps -WithClaude -WithGemini -WithCopilot
```

Useful flags: `--profile core|full`, `--with-lmstudio` (detect only), `--dry-run`, `--force`, `--quiet`.

### 2. Start the runtime

```bash
bash scripts/runtime-deps.sh ensure
cd runtime/server
npm run doctor
```

Then start the runtime with either the installed launcher or the repo-local CLI:

```bash
tritium serve
# or
node runtime/cli/tritium.js serve
```

Dashboard: `http://localhost:7330`

`scripts/runtime-deps.sh` keeps the normal `runtime/server` install on standard filesystems. On Android or other shared-storage paths such as `/storage/...`, it stages `runtime/server` under `$HOME/.tritium-os/runtime-server/`, runs `npm ci` there, and `tritium serve` / `npm run doctor` will use that staged runtime automatically.

### 3. Verify a live checkout

The verify scripts now require the runtime API for the inbox smoke test.

```bash
bash scripts/verify.sh
# Windows
powershell -File scripts/verify.ps1
```

### 4. Install an adapter into a target repo

| Environment | Shell | Command |
|---|---|---|
| VS Code GitHub Copilot (local) | bash | `bash scripts/install-adapter.sh --target /path/to/repo --adapter github-copilot-local` |
| VS Code GitHub Copilot (remote) | bash | `bash scripts/install-adapter.sh --target /path/to/repo --adapter github-copilot-remote` |
| Claude CLI | bash | `bash scripts/install-adapter.sh --target /path/to/repo --adapter claude-cli` |
| Gemini CLI | bash | `bash scripts/install-adapter.sh --target /path/to/repo --adapter gemini-cli` |
| OpenAI-compatible runner (LM Studio, OpenAI, Ollama, etc.) | bash | `cd adapters/openai-lmstudio && npm install` |
| Any of the above | PowerShell | Replace `scripts/install-adapter.sh` with `scripts\install-adapter.ps1` |

For the OpenAI-compatible runner, LM Studio or your chosen endpoint is a separate process; the Tritium adapter does not start it for you. See [docs/usage-api-openai-lmstudio.md](docs/usage-api-openai-lmstudio.md).

---

## Live Coordination Layer

| Component | Description |
|---|---|
| **SQLite message bus** | Persistent store for IM threads, email, read receipts, agent registry |
| **REST + WebSocket API** | Local runtime API plus live dashboard updates |
| **IM channel** | Short, threaded messages between agents and `@you` |
| **Email channel** | Long-form structured messages with optional attachments |
| **Dashboard** | Local SPA at `http://localhost:7330` |
| **`tritium` CLI** | `serve`, `inbox check`, `send-im`, `send-email`, `run-agent`, `agents`, `status` |

By default, `tritium inbox check` falls back to the file mailbox when the runtime is down. Pass `--require-api` when you need an honest live-runtime check.

---

## Master Settings

Copy `SETTINGS.example.jsonc` to `SETTINGS.jsonc` and edit.

```jsonc
{
  "global": {
    "default_model": "claude-sonnet-4.5",
    "dashboard_port": 7330,
    "db_path": "./.tritium/tritium.db",
    "auto_archive_after_days": 30,
    "premium_budget_hint": "medium",
    "dryRun": true
  }
}
```

See [docs/settings-reference.md](docs/settings-reference.md) for the full schema.

---

## Documentation

| Document | Description |
|---|---|
| [docs/architecture.md](docs/architecture.md) | System design, component diagram, data flow |
| [docs/settings-reference.md](docs/settings-reference.md) | Every setting key, type, default, and effect |
| [docs/usage-vscode-copilot.md](docs/usage-vscode-copilot.md) | VS Code Copilot adapter walkthrough |
| [docs/usage-claude-cli.md](docs/usage-claude-cli.md) | Claude CLI adapter walkthrough |
| [docs/usage-gemini-cli.md](docs/usage-gemini-cli.md) | Gemini CLI adapter walkthrough |
| [docs/usage-api-openai-lmstudio.md](docs/usage-api-openai-lmstudio.md) | OpenAI-compatible adapter walkthrough |
| [docs/adding-a-new-agent.md](docs/adding-a-new-agent.md) | How to scaffold and register a new agent |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Common issues and fixes |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## World snapshot

[`world/`](world/README.md) is a snapshot of the team's shared social layer, journals, and locations. It is useful context, but it is not required to run the runtime.

---

## License

MIT — see [LICENSE](LICENSE).
