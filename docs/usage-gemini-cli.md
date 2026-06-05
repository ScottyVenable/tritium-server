# Usage: Gemini CLI / Antigravity CLI

To drop the Tritium Team workflow into your project for use with the **Gemini CLI** or **Antigravity CLI**, run the setup script:

```bash
# From the tritium-team repo
bash scripts/setup-team.sh --target /path/to/your/project
```

This installs:

- `.antigravityrules` — rules file for the Antigravity CLI.
- `GEMINI.md` — crew declaration and default-Bridge instruction for Gemini CLI.
- `agents/` — contains all eight specialized agent prompts and histories.
- `world/` — sets up the mailboxes, locations, and direct communication logs.
- `SETTINGS.jsonc` — configuration settings for the workspace team.

## Switch Agent

Tell Gemini or Antigravity: *"Switch to agent vex"* or *"Act as Sol".* The assistant will load `agents/<name>/agent.md` and continue.

## Live Coordination

Keep the Tritium Team coordinator server running in the background:

```bash
tritium serve
```

Then prompt the assistant: *"Run tritium inbox check for sol"* or ask it to scan the mailbox under `world/social/mailbox/sol/`.
