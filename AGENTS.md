# Tritium Team -- Agent Roster

This file is the authoritative list of named agents in Tritium Team v4.1.

| Name   | Role                           | Tier | Model             |
|--------|--------------------------------|------|-------------------|
| Bridge | Team Lead, Dispatcher          | T1   | gemini-1.5-pro    |
| Scout  | T0 Baseline, always-on         | T0   | gemini-3-flash    |
| Sol    | Co-Creative Director, Lead Dev | T2   | claude-sonnet-4.6 |
| Jesse  | Repository Manager             | T2   | claude-sonnet-4.6 |
| Vex    | Content and Asset Architect    | T2   | claude-sonnet-4.6 |
| Rook   | QA and Release Engineer        | T3   | claude-opus-4.7   |

## Tier hierarchy

- T0 Scout   -- fast, lightweight, always-on baseline. Snap-back target.
- T1 Bridge  -- coordinator only. Routes and delegates. No implementation.
- T2 Specialists (Sol, Jesse, Vex) -- domain experts for code, repo, content.
- T3 Rook    -- QA/release, most expensive. Only for build and CI work.

## Snap-back

After any T1-T3 session, `tier-auto snap` closes open vault payloads
and returns the runtime to T0 (Scout). Bridge enforces Rule 0: pre-dispatch
all T0-safe requests to Scout before escalating.

## Agent configuration files

Each agent has a spec at `.github/agents/<Name>.agent.md`.
Scout also has a runtime directory at `agents/scout/`.

## Adding agents

1. Add entry to `data/registry/models.json`.
2. Create `.github/agents/<Name>.agent.md`.
3. Update this file.
4. Update `CHANGELOG.md`.
