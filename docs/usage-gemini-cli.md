# Usage: Gemini CLI

```bash
bash scripts/install-adapter.sh --target /path/to/repo --adapter gemini-cli
```

Installs:

- `GEMINI.md` — crew declaration, default-Bridge instruction.
- `.gemini/settings.json` — tool-allow list including `tritium`, `git`, `node`, `npm`.
- `agents/<name>.md` — per-agent prompts.

## Switch agent

Tell Gemini: *"Switch to agent vex"* or *"Act as Sol".* Gemini loads `agents/<name>.md` and continues.

## Live coordination

```bash
bash /path/to/tritium/scripts/runtime-deps.sh ensure
cd /path/to/tritium/runtime/server
npm run doctor
node ../cli/tritium.js serve
```

Then prompt: *"Run tritium inbox check for sol".*

## Notes

Gemini CLI is younger than Claude CLI, so the slash-command surface is less stable. Tritium's adapter avoids depending on plugin-style features.
