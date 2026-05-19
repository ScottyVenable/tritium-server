# Usage: OpenAI / LM Studio (any OpenAI-compatible API)

The `adapters/openai-lmstudio/` runner targets any endpoint that speaks the OpenAI chat-completions API: OpenAI itself, LM Studio, Ollama (with its OpenAI-compat shim), Azure OpenAI, vLLM, and proxies for Anthropic or Gemini.

## Install

```bash
cd adapters/openai-lmstudio
npm install
```

## Configure

Environment variables:

| Var | Required? | Default |
|---|---|---|
| `TRITIUM_BASE_URL` | yes | `http://localhost:1234/v1` (LM Studio) |
| `TRITIUM_API_KEY`  | when calling OpenAI / hosted | unset |
| `TRITIUM_MODEL`    | optional | inherited from `SETTINGS.jsonc → default_model` |

## Run an agent

```bash
node src/run.js --agent sol --task "implement a thing"
```

By default `dryRun: true` from `SETTINGS.jsonc → global.dryRun`. The runner prints what it would send and exits without making a paid API call. Set `dryRun: false` in `SETTINGS.jsonc` to spend tokens.

## Inter-agent IM

When the model emits a structured block:

```
[[IM to=vex]]
Need a one-paragraph fragment for the loading screen, register: dry-witty.
[[/IM]]
```

…the runner forwards it to the local Tritium runtime (`POST /api/im`). The dashboard updates in real time.

## Live coordination

```bash
bash /path/to/tritium/scripts/runtime-deps.sh ensure
cd /path/to/tritium/runtime/server
npm run doctor
node ../cli/tritium.js serve
```

The runner will fail-soft if the runtime isn't running — IMs simply won't be delivered, and the agent's text output is preserved verbatim.

If the checkout lives on Android or other shared storage, `scripts/runtime-deps.sh ensure` will stage `runtime/server` under `~/.tritium-os/` and avoid the shared-storage symlink failure automatically.

## Security

- API keys are environment-only. Never written to disk by Tritium.
- The runner uses Node's built-in `http`/`https`. No third-party HTTP client.
