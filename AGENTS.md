# Tritium OS Agent Roster

This file is a human-readable roster for the 9 named agents shipped in this repo.

For canonical behavior, prompts, and operating rules, see `agents/<name>/agent.md`.
Model selection can change in `SETTINGS.jsonc` and adapter config; do not treat any
single model assignment in this file as authoritative.

| Name | Role | Primary lane |
|---|---|---|
| Bridge | Planner / dispatcher / watchdog | Task routing, decomposition, handoff quality |
| Scout | Baseline agent | Routine lookups, status checks, lightweight requests |
| Sol | Co-creative director / lead programmer | Code, CI, tooling, changelog, implementation |
| Jesse | Repository manager | Issues, labels, milestones, board, repo hygiene |
| Vex | Content & asset architect | Authored content, docs, lore, content structure |
| Rook | QA & release engineer | Builds, CI failures, repro, release readiness |
| Robert | Research specialist | External references, investigation, gap analysis |
| Lux | Visuals & art direction lead | UI/UX direction, style guides, visual specs |
| Nova | Systems & balance lead | Mechanics, progression, tuning, formulas |

## Notes

- The repo currently carries 9 agent directories under `agents/`.
- `world/social/team/TEAM.md` documents handoffs and interaction patterns.
- `scripts/new-agent.sh` and `scripts/new-agent.ps1` are the starting point for expanding the roster.
