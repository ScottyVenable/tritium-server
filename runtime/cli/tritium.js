#!/usr/bin/env node
// `tritium` CLI.
//
// Subcommands:
//   serve                                     — start the runtime server.
//   inbox check [--agent <name>] [--all]      — list unread IMs and recent emails.
//   send-im --from <a> --to <b> --body "..."  — post an IM.
//   send-email --from --to --subject --body [--attach <path>]
//   run-agent <name> --task "..."             — adapter-side dispatch (stub in v0.1).

import path from 'node:path';
import fs from 'node:fs';
import url from 'node:url';
import http from 'node:http';
import { spawn, spawnSync } from 'node:child_process';
import { checkRuntimeInstall, formatRuntimeInstallHelp } from '../server/src/preflight.js';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..');

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next == null || next.startsWith('--')) { args[key] = true; }
      else { args[key] = next; i++; }
    } else {
      args._.push(a);
    }
  }
  return args;
}

function loadSettingsForPort() {
  // Lightweight: read the file and try to find dashboard_port via a regex, otherwise default.
  const p = fs.existsSync(path.join(ROOT, 'SETTINGS.jsonc'))
    ? path.join(ROOT, 'SETTINGS.jsonc')
    : path.join(ROOT, 'SETTINGS.example.jsonc');
  try {
    const raw = fs.readFileSync(p, 'utf8');
    const m = raw.match(/dashboard_port"\s*:\s*(\d+)/);
    return m ? Number(m[1]) : 7330;
  } catch { return 7330; }
}

const PORT = loadSettingsForPort();

function apiFetch(method, path_, body) {
  const data = body ? JSON.stringify(body) : null;
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1', port: PORT, path: path_, method,
      headers: data ? { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) } : {},
    }, (res) => {
      let buf = '';
      res.on('data', (c) => buf += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, json: buf ? JSON.parse(buf) : null }); }
        catch { resolve({ status: res.statusCode, raw: buf }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function help() {
  console.log(`tritium 0.1.0
usage:
  tritium serve
  tritium inbox check [--agent <name>] [--all] [--require-api]
  tritium send-im --from <a> --to <b> --body "..." [--subject "..."]
  tritium send-email --from <a> --to <b> --subject "..." --body "..." [--attach <path>]
  tritium run-agent <name> --task "..." [--dry]
  tritium agents
  tritium status

The runtime must be running for send/status commands. Start it with: tritium serve
By default, inbox check falls back to the file mailbox when the API is down.
Pass --require-api to fail instead of falling back.
`);
}

async function isApiRunning() {
  try {
    const r = await apiFetch('GET', '/api/health');
    return r.status === 200;
  } catch {
    return false;
  }
}

function exitApiUnavailable(extra) {
  console.error(`error: tritium runtime not reachable at http://localhost:${PORT}`);
  if (extra) console.error(extra);
  console.error('start it with: tritium serve');
  process.exit(2);
}

async function ensureRunning() {
  if (await isApiRunning()) return true;
  exitApiUnavailable();
}

const cmd = process.argv[2];
const args = parseArgs(process.argv.slice(3));

(async () => {
  switch (cmd) {
    case 'serve':
    case 'start': {
      let installCheck = checkRuntimeInstall(ROOT);
      if (installCheck.needsWorkaround) {
        const helper = path.join(ROOT, 'scripts', 'runtime-deps.sh');
        if (!fs.existsSync(helper)) {
          console.error('error: scripts/runtime-deps.sh is missing');
          process.exit(2);
        }
        const ensure = spawnSync('bash', [helper, '--quiet', 'ensure'], {
          cwd: ROOT,
          stdio: 'inherit',
        });
        if ((ensure.status ?? 1) !== 0) {
          process.exit(ensure.status ?? 1);
        }
        installCheck = checkRuntimeInstall(ROOT);
      }
      if (!installCheck.ok) {
        console.error(formatRuntimeInstallHelp(installCheck));
        process.exit(2);
      }
      const child = spawn(process.execPath, [path.join(installCheck.serverRoot, 'src', 'index.js')], {
        stdio: 'inherit',
        cwd: installCheck.serverRoot,
        env: {
          ...process.env,
          TRITIUM_REPO_ROOT: ROOT,
          TRITIUM_RUNTIME_SERVER_ROOT: installCheck.serverRoot,
        },
      });
      child.on('exit', (code) => process.exit(code ?? 0));
      break;
    }

    case 'inbox': {
      const sub = args._[0];
      if (sub !== 'check') { help(); process.exit(1); }
      const agent = args.agent;
      if (!agent && !args.all) {
        console.error('error: --agent <name> required (or pass --all)');
        process.exit(1);
      }

      // Probe the runtime; if unreachable, fall back to the file mailbox.
      const apiUp = await isApiRunning();

      if (!apiUp) {
        if (args['require-api']) {
          exitApiUnavailable('file-mailbox fallback disabled by --require-api');
        }
        // File-mailbox fallback. Recipient-managed: do not mark anything as read.
        const targets = agent ? [agent] : (() => {
          const mbRoot = path.join(ROOT, 'world', 'social', 'mailbox');
          if (!fs.existsSync(mbRoot)) return [];
          return fs.readdirSync(mbRoot, { withFileTypes: true })
            .filter(d => d.isDirectory() && !d.name.startsWith('['))
            .map(d => d.name);
        })();
        console.log('# IM (API unavailable — showing file mailbox)');
        for (const a of targets) {
          const dir = path.join(ROOT, 'world', 'social', 'mailbox', a);
          if (!fs.existsSync(dir)) continue;
          const entries = fs.readdirSync(dir, { withFileTypes: true })
            .filter(d => d.isFile() && d.name !== '.gitkeep')
            .map(d => {
              const full = path.join(dir, d.name);
              return { name: d.name, mtime: fs.statSync(full).mtimeMs };
            })
            .sort((a, b) => b.mtime - a.mtime);
          for (const e of entries) {
            console.log(`  world/social/mailbox/${a}/${e.name}`);
          }
        }
        break;
      }

      const q = agent ? `?agent=${encodeURIComponent(agent)}&unreadOnly=1` : '';
      const r = await apiFetch('GET', `/api/im${q}`);
      console.log(`# IM (${r.json.length})`);
      for (const m of r.json) console.log(`  [${m.id}] ${m.created_at}  @${m.sender} → @${m.recipient}: ${m.body}`);
      const eq = agent ? `?agent=${encodeURIComponent(agent)}` : '';
      const e = await apiFetch('GET', `/api/email${eq}`);
      console.log(`# Email (${e.json.length})`);
      for (const m of e.json) console.log(`  [${m.id}] ${m.created_at}  @${m.sender} → @${m.recipient}: ${m.subject}`);
      break;
    }

    case 'send-im': {
      await ensureRunning();
      const payload = { from: args.from, to: args.to, body: args.body, subject: args.subject };
      const r = await apiFetch('POST', '/api/im', payload);
      if (r.status >= 400) { console.error(r.json ?? r.raw); process.exit(1); }
      console.log(`im sent: id=${r.json.id}`);
      break;
    }

    case 'send-email': {
      await ensureRunning();
      const attachments = [];
      if (args.attach) {
        const p = path.resolve(args.attach);
        if (!fs.existsSync(p)) { console.error(`attachment not found: ${p}`); process.exit(1); }
        attachments.push({ kind: 'path', name: path.basename(p), ref: p });
      }
      const r = await apiFetch('POST', '/api/email', {
        from: args.from, to: args.to, subject: args.subject, body: args.body, attachments,
      });
      if (r.status >= 400) { console.error(r.json ?? r.raw); process.exit(1); }
      console.log(`email sent: id=${r.json.id}`);
      break;
    }

    case 'run-agent': {
      const name = args._[0];
      if (!name) { console.error('error: agent name required'); process.exit(1); }
      console.log(`# run-agent ${name} (stub)`);
      console.log(`# task: ${args.task ?? '(none)'}`);
      console.log(`# This is the v0.1 stub. Wire your adapter in adapters/<provider>/.`);
      console.log(`# In dryRun mode, no API call is made.`);
      break;
    }

    case 'agents': {
      await ensureRunning();
      const r = await apiFetch('GET', '/api/agents');
      for (const a of r.json) {
        const stats = a.stats ?? {};
        console.log(`${a.enabled ? '●' : '○'} ${a.name.padEnd(8)} ${a.role ?? ''}  [ind=${stats.independence ?? '?'} verb=${stats.verbosity ?? '?'} inbox/${stats.inbox_check_interval ?? '?'}]`);
      }
      break;
    }

    case 'status': {
      await ensureRunning();
      const r = await apiFetch('GET', '/api/health');
      console.log(JSON.stringify(r.json, null, 2));
      break;
    }

    case undefined:
    case '--help':
    case '-h':
    case 'help':
      help();
      break;

    default:
      console.error(`unknown command: ${cmd}`);
      help();
      process.exit(1);
  }
})().catch((err) => { console.error(err); process.exit(1); });
