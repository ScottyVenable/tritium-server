# Troubleshooting

## Runtime won't start

- **`tritium serve` says runtime dependencies are not installed**: run `bash scripts/runtime-deps.sh ensure`, then `cd runtime/server && npm run doctor`.
- **`npm ci` fails with `EACCES: symlink ... node_modules/.bin/...`**: the repo is probably on shared storage (`/storage/...`, SD card, or similar) where npm cannot create symlinks. Run `bash scripts/runtime-deps.sh ensure` instead. Tritium will stage `runtime/server` under `~/.tritium-os/runtime-server/`, run `npm ci` there, and use that staged path for `doctor`, `serve`, and runtime verification.
- **`Error: better-sqlite3 binary mismatch`**: rebuild with `npm rebuild better-sqlite3` inside `runtime/server/`.
- **Port already in use**: change `global.dashboard_port` in `SETTINGS.jsonc`.
- **Permission denied on `.tritium/`**: the directory is created next to your current working dir. Make sure that dir is writable, or set `global.db_path` to an absolute path.

## Dashboard shows "offline"

- Confirm the runtime is up: `curl http://localhost:7330/api/health`.
- Browser blocks WebSocket: the dashboard uses `ws://` on `localhost`. Some corporate proxies break this. Try a different browser or disable the proxy for `localhost`.
- Mixed-content: don't open the dashboard via `file://`. Use the HTTP URL the server prints on boot.

## Agents don't see their messages

- Check the agent's `inbox_check_interval` in `SETTINGS.jsonc`. If it's high (e.g. 10), they only check after 10 tool calls. Lower it.
- Confirm IMs are reaching the db: `curl 'http://localhost:7330/api/im?agent=<name>'`.

## Tunnel mode (remote dashboard)

Tritium ships **local-only** by default. To access the dashboard from your phone or another machine, use a trusted tunnel — Tritium does not bundle one because they all have install/auth steps that vary by user.

**Tailscale** (recommended for personal devices on your tailnet):

```bash
tailscale up
# Then on the host:
sudo tailscale serve --bg --https=443 http://localhost:7330
```

Your dashboard is now at `https://<host>.<tailnet>.ts.net/`.

**Cloudflare Tunnel** (public URL, requires Cloudflare account):

```bash
cloudflared tunnel --url http://localhost:7330
```

Cloudflare prints a `https://<random>.trycloudflare.com` URL. Treat as ephemeral.

**ngrok**:

```bash
ngrok http 7330
```

For all tunnel modes:

- Tritium has no auth in v0.1. **Treat any tunneled URL as a secret.** Don't share it.
- Set `dryRun: true` while tunneled to prevent runaway API spend if someone finds the URL.

## Smoke test fails

```bash
cd runtime/server && node src/verify.js
```

If a check fails, re-run with logs:

```bash
DEBUG=1 node src/verify.js 2>&1 | tee /tmp/verify.log
```

Common causes: stale `.tritium/` directory in the package root, port collision, or a partially-written `SETTINGS.jsonc`.

## Agent emits malformed output

- If an OpenAI-compatible model is producing junk, lower `temperature` to ≤0.2 for engineering agents.
- If responses are too terse, raise `verbosity` to 4 or 5.
- If an agent keeps asking for clarification, raise `independence` to 7 or 8.
