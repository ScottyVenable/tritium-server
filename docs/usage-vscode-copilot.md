# Usage: VS Code GitHub Copilot

Tritium ships **two** Copilot adapters because GitHub treats local and remote `.github/` differently for custom agents.

## 1. Local custom agents (run inside VS Code)

```bash
bash scripts/install-adapter.sh --target /path/to/repo --adapter github-copilot-local
```

Installs `.github/agents/*.agent.md` (one per Tritium agent), `.github/copilot-instructions.md` (Bridge as default), `.github/TEAM.md`, `.github/portfolios/`, `.github/team/`.

In VS Code, after installing, you can:

- `@Bridge` — invoke the planner.
- `@Sol`, `@Vex`, `@Rook`, `@Robert`, `@Lux`, `@Nova`, `@Jesse` — invoke a specific specialist.

## 2. Remote (synced to GitHub.com)

```bash
bash scripts/install-adapter.sh --target /path/to/repo --adapter github-copilot-remote
```

Installs the GitHub-side `.github/`: CODEOWNERS keyed to agents, PR template with affected-agent checkbox, four issue templates (bug / feature / agent-handoff / research-request), `dependabot.yml`, `labels.md`, and a CI workflow `tritium-verify.yml` that runs the runtime smoke test on PRs touching `runtime/`.

## Both at once

In most repos you want both. Install local first, then remote — they don't overlap:

```bash
bash scripts/install-adapter.sh --target /path/to/repo --adapter github-copilot-local
bash scripts/install-adapter.sh --target /path/to/repo --adapter github-copilot-remote
```

## Live coordination

Run the runtime alongside VS Code:

```bash
bash /path/to/tritium/scripts/runtime-deps.sh ensure
cd /path/to/tritium/runtime/server
npm run doctor
node ../cli/tritium.js serve
# dashboard at http://localhost:7330
```

Now Copilot custom agents can invoke `tritium inbox check` from their bash tool to read incoming messages while you work.
