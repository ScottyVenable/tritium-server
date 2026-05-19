// Tritium runtime server.
//
// Responsibilities:
//   1. Open / migrate the SQLite database.
//   2. Serve a REST API for IM, email, agents, settings, timeline.
//   3. Serve a WebSocket stream for live IM updates.
//   4. Serve the static dashboard SPA.
//
// No external HTTP framework — Node's built-in `http` is plenty for a local tool.

import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
import { WebSocketServer } from 'ws';
import { openDatabase } from './db.js';
import { loadSettings } from './settings.js';
import { createApi } from './api.js';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

const ROOT = process.env.TRITIUM_REPO_ROOT
  ? path.resolve(process.env.TRITIUM_REPO_ROOT)
  : path.resolve(__dirname, '..', '..', '..');
const DASHBOARD_DIR = path.join(ROOT, 'runtime', 'dashboard');

const settings = loadSettings(ROOT);
const port = settings.global.dashboard_port ?? 7330;

const db = openDatabase(settings.global.db_path
  ? path.resolve(ROOT, settings.global.db_path)
  : path.resolve(ROOT, '.tritium', 'tritium.db'));

const api = createApi({ db, settings, root: ROOT });

// ─── HTTP server ────────────────────────────────────────────────────────────

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css':  'text/css; charset=utf-8',
  '.js':   'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.png':  'image/png',
  '.txt':  'text/plain; charset=utf-8',
};

function safeStaticPath(reqPath) {
  // Prevent path traversal.
  const decoded = decodeURIComponent(reqPath.split('?')[0]);
  const rel = decoded === '/' ? '/index.html' : decoded;
  const full = path.join(DASHBOARD_DIR, rel);
  if (!full.startsWith(DASHBOARD_DIR)) return null;
  return full;
}

function sendJson(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(body));
}

async function readJsonBody(req, limitBytes = 1_000_000) {
  return new Promise((resolve, reject) => {
    let total = 0;
    const chunks = [];
    req.on('data', (c) => {
      total += c.length;
      if (total > limitBytes) {
        reject(new Error('payload too large'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw) return resolve({});
      try { resolve(JSON.parse(raw)); }
      catch (e) { reject(e); }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  try {
    const u = new URL(req.url, `http://${req.headers.host}`);

    // ─── REST API ─────────────────────────────────────────────────────────
    if (u.pathname.startsWith('/api/')) {
      res.setHeader('cache-control', 'no-store');

      // GET /api/health
      if (req.method === 'GET' && u.pathname === '/api/health') {
        return sendJson(res, 200, { ok: true, version: '0.1.0' });
      }

      // GET /api/agents
      if (req.method === 'GET' && u.pathname === '/api/agents') {
        return sendJson(res, 200, api.listAgents());
      }

      // GET /api/settings
      if (req.method === 'GET' && u.pathname === '/api/settings') {
        return sendJson(res, 200, settings);
      }

      // GET /api/im?agent=<name>&unreadOnly=1
      if (req.method === 'GET' && u.pathname === '/api/im') {
        const agent = u.searchParams.get('agent') || undefined;
        const unreadOnly = u.searchParams.get('unreadOnly') === '1';
        return sendJson(res, 200, api.listIm({ agent, unreadOnly }));
      }

      // POST /api/im   { from, to, body, threadId? }
      if (req.method === 'POST' && u.pathname === '/api/im') {
        const body = await readJsonBody(req);
        const msg = api.sendIm(body);
        broadcastWs({ type: 'im', message: msg });
        return sendJson(res, 201, msg);
      }

      // POST /api/im/:id/read
      const imReadMatch = u.pathname.match(/^\/api\/im\/(\d+)\/read$/);
      if (req.method === 'POST' && imReadMatch) {
        const id = Number(imReadMatch[1]);
        const body = await readJsonBody(req);
        const reader = body.reader;
        if (!reader) return sendJson(res, 400, { error: 'reader required' });
        api.markImRead(id, reader);
        return sendJson(res, 200, { ok: true });
      }

      // GET /api/email?agent=<name>
      if (req.method === 'GET' && u.pathname === '/api/email') {
        const agent = u.searchParams.get('agent') || undefined;
        return sendJson(res, 200, api.listEmail({ agent }));
      }

      // POST /api/email   { from, to, subject, body, attachments? }
      if (req.method === 'POST' && u.pathname === '/api/email') {
        const body = await readJsonBody(req);
        const msg = api.sendEmail(body);
        broadcastWs({ type: 'email', message: msg });
        return sendJson(res, 201, msg);
      }

      // POST /api/heartbeat   { agent, currentTask? }
      if (req.method === 'POST' && u.pathname === '/api/heartbeat') {
        const body = await readJsonBody(req);
        api.heartbeat(body);
        broadcastWs({ type: 'heartbeat', agent: body.agent });
        return sendJson(res, 200, { ok: true });
      }

      // GET /api/timeline
      if (req.method === 'GET' && u.pathname === '/api/timeline') {
        return sendJson(res, 200, api.timeline());
      }

      return sendJson(res, 404, { error: 'not found' });
    }

    // ─── Static dashboard ────────────────────────────────────────────────
    if (req.method !== 'GET') {
      res.writeHead(405); return res.end('method not allowed');
    }
    let file = safeStaticPath(u.pathname);
    if (!file) { res.writeHead(400); return res.end('bad path'); }
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      // SPA fallback
      file = path.join(DASHBOARD_DIR, 'index.html');
    }
    const ext = path.extname(file).toLowerCase();
    const mime = MIME[ext] || 'application/octet-stream';
    res.writeHead(200, { 'content-type': mime, 'cache-control': 'no-store' });
    fs.createReadStream(file).pipe(res);
  } catch (err) {
    console.error('[server]', err);
    // Validation-style errors (statusCode set explicitly) get their message
    // surfaced; unexpected errors return an opaque 500 to avoid leaking
    // internals (file paths, library stack frames, etc.).
    if (!res.headersSent) {
      if (err && Number.isInteger(err.statusCode) && err.statusCode >= 400 && err.statusCode < 500) {
        sendJson(res, err.statusCode, { error: String(err.message ?? 'bad request') });
      } else {
        sendJson(res, 500, { error: 'internal server error' });
      }
    }
  }
});

// ─── WebSocket ──────────────────────────────────────────────────────────────

const wss = new WebSocketServer({ server, path: '/ws' });
const wsClients = new Set();
wss.on('connection', (ws) => {
  wsClients.add(ws);
  ws.on('close', () => wsClients.delete(ws));
  ws.send(JSON.stringify({ type: 'hello', version: '0.1.0' }));
});
function broadcastWs(payload) {
  const data = JSON.stringify(payload);
  for (const ws of wsClients) {
    if (ws.readyState === ws.OPEN) ws.send(data);
  }
}

// ─── Boot ───────────────────────────────────────────────────────────────────

server.listen(port, '127.0.0.1', () => {
  console.log(`[tritium] runtime ready at http://localhost:${port}`);
  console.log(`[tritium] db: ${db.name}`);
  console.log(`[tritium] dashboard: ${DASHBOARD_DIR}`);
});

// Graceful shutdown
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    console.log(`[tritium] ${sig} received, shutting down`);
    server.close(() => {
      try { db.close(); } catch {}
      process.exit(0);
    });
    setTimeout(() => process.exit(1), 5000).unref();
  });
}
