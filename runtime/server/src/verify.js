// Smoke test for the Tritium runtime.
// Spins up the server, exercises the REST API, validates responses, exits.

import http from 'node:http';
import path from 'node:path';
import fs from 'node:fs';
import url from 'node:url';
import { spawn } from 'node:child_process';
import { checkRuntimeInstall, formatRuntimeInstallHelp } from './preflight.js';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..', '..', '..');
const installCheck = checkRuntimeInstall(ROOT);
const PORT = 7331; // distinct from default to avoid clashing with a running instance

if (!installCheck.ok) {
  console.error(formatRuntimeInstallHelp(installCheck));
  process.exit(2);
}

const TMP = path.resolve(ROOT, '.tritium-verify');
fs.rmSync(TMP, { recursive: true, force: true });
fs.mkdirSync(TMP, { recursive: true });

// Write a temporary settings file pointing at a throwaway db + alt port.
const settingsPath = path.join(TMP, 'SETTINGS.jsonc');
fs.writeFileSync(settingsPath, JSON.stringify({
  global: {
    dashboard_port: PORT,
    db_path: path.join(TMP, 'tritium.db'),
    dryRun: true,
  },
  agents: {},
}, null, 2));

// Override settings location: the server reads SETTINGS.jsonc from package root,
// so for the verify run we copy our temp file into ROOT/SETTINGS.jsonc.
const targetSettings = path.join(ROOT, 'SETTINGS.jsonc');
const hadExisting = fs.existsSync(targetSettings);
const backup = hadExisting ? fs.readFileSync(targetSettings, 'utf8') : null;
fs.copyFileSync(settingsPath, targetSettings);

const child = spawn(process.execPath, [path.join(installCheck.serverRoot, 'src', 'index.js')], {
  cwd: installCheck.serverRoot,
  stdio: ['ignore', 'pipe', 'pipe'],
  env: {
    ...process.env,
    TRITIUM_REPO_ROOT: ROOT,
    TRITIUM_RUNTIME_SERVER_ROOT: installCheck.serverRoot,
  },
});

let serverOutput = '';
child.stdout.on('data', (d) => { serverOutput += d; process.stdout.write(`[server] ${d}`); });
child.stderr.on('data', (d) => { serverOutput += d; process.stderr.write(`[server] ${d}`); });

function cleanup(code) {
  child.kill('SIGTERM');
  setTimeout(() => child.kill('SIGKILL'), 2000).unref();
  // restore SETTINGS
  if (hadExisting) fs.writeFileSync(targetSettings, backup);
  else fs.rmSync(targetSettings, { force: true });
  fs.rmSync(TMP, { recursive: true, force: true });
  process.exit(code);
}

function req(method, path_, body) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const r = http.request({
      hostname: '127.0.0.1', port: PORT, path: path_, method,
      headers: data ? { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data) } : {},
    }, (res) => {
      let buf = '';
      res.on('data', (c) => buf += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, json: buf ? JSON.parse(buf) : null }); }
        catch (e) { resolve({ status: res.statusCode, raw: buf }); }
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

async function waitReady() {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await req('GET', '/api/health');
      if (r.status === 200 && r.json?.ok) return;
    } catch {}
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('server did not become ready');
}

(async () => {
  const checks = [];
  function check(name, ok, detail) {
    checks.push({ name, ok, detail });
    console.log(`${ok ? 'PASS' : 'FAIL'} — ${name}${detail ? `: ${detail}` : ''}`);
  }
  try {
    await waitReady();
    check('server boots and /api/health is ok', true);

    const agents = await req('GET', '/api/agents');
    check('GET /api/agents returns 9 default roster entries',
      agents.status === 200 && Array.isArray(agents.json) && agents.json.length === 9,
      `got ${agents.json?.length}`);

    const sent = await req('POST', '/api/im', { from: 'sol', to: 'vex', body: 'verify-test' });
    check('POST /api/im 201 + id', sent.status === 201 && sent.json?.id > 0, `id=${sent.json?.id}`);

    const ims = await req('GET', '/api/im?agent=vex');
    check('GET /api/im?agent=vex returns the message',
      ims.status === 200 && ims.json.some((m) => m.body === 'verify-test'));

    const unreadBefore = await req('GET', '/api/im?agent=vex&unreadOnly=1');
    const unreadCount = unreadBefore.json.length;
    check('vex has at least one unread im', unreadCount >= 1);

    const read = await req('POST', `/api/im/${sent.json.id}/read`, { reader: 'vex' });
    check('POST /api/im/:id/read 200', read.status === 200);

    const unreadAfter = await req('GET', '/api/im?agent=vex&unreadOnly=1');
    check('unread count decreased after read receipt',
      unreadAfter.json.length < unreadCount);

    const email = await req('POST', '/api/email', {
      from: 'vex', to: 'sol', subject: 'verify subject', body: 'verify email body',
      attachments: [{ kind: 'inline', name: 'note.txt', ref: 'hello' }],
    });
    check('POST /api/email 201 with attachment',
      email.status === 201 && email.json?.attachments?.length === 1);

    const hb = await req('POST', '/api/heartbeat', { agent: 'sol', currentTask: 'verifying' });
    check('POST /api/heartbeat 200', hb.status === 200);

    const tl = await req('GET', '/api/timeline');
    check('GET /api/timeline 200 with at least 2 entries',
      tl.status === 200 && tl.json.length >= 2);

    const failed = checks.filter((c) => !c.ok);
    if (failed.length > 0) {
      console.log(`\n${failed.length} check(s) failed.`);
      cleanup(1);
    } else {
      console.log(`\nAll ${checks.length} checks passed.`);
      cleanup(0);
    }
  } catch (err) {
    console.error('verify error:', err);
    cleanup(2);
  }
})();
