// JSONC (JSON-with-comments) loader and settings resolver.

import fs from 'node:fs';
import path from 'node:path';

const ROSTER = ['bridge', 'scout', 'sol', 'jesse', 'vex', 'rook', 'robert', 'lux', 'nova'];

const ROLES = {
  bridge: 'Planner / Dispatcher / Watchdog',
  scout:  'Baseline Agent',
  sol:    'Co-Creative Director and Lead Programmer',
  jesse:  'Repository Manager / Community Coordinator',
  vex:    'Content & Lore Architect',
  rook:   'QA & Release Engineer',
  robert: 'Master Researcher',
  lux:    'Visuals & Art Direction Lead',
  nova:   'Gameplay Systems & Balancing Lead',
};

const DEFAULT_AGENT_STATS = {
  independence: 6,
  verbosity: 3,
  inbox_check_interval: 3,
  memory_write_quota: 25,
  portfolio_size_limit: 100,
  model_preference: null,
  temperature: 0.3,
  enabled: true,
};

const DEFAULT_GLOBAL = {
  default_model: 'claude-sonnet-4.5',
  dashboard_port: 7330,
  db_path: './.tritium/tritium.db',
  auto_archive_after_days: 30,
  premium_budget_hint: 'medium',
  dryRun: true,
  proposed_prompt_edits_dir: './agents/bridge/proposed-prompt-edits',
};

/**
 * Strip JSONC comments and trailing commas, then JSON.parse.
 * Handles `//`, block comments, and trailing commas before `}` or `]`.
 * Strings (including with escaped quotes) are preserved verbatim.
 */
export function parseJsonc(text) {
  let out = '';
  let i = 0;
  const n = text.length;
  let inStr = false;
  let strCh = '';
  while (i < n) {
    const c = text[i];
    const c2 = text[i + 1];
    if (inStr) {
      out += c;
      if (c === '\\' && i + 1 < n) { out += c2; i += 2; continue; }
      if (c === strCh) inStr = false;
      i++;
      continue;
    }
    if (c === '"' || c === "'") { inStr = true; strCh = c; out += c; i++; continue; }
    if (c === '/' && c2 === '/') {
      while (i < n && text[i] !== '\n') i++;
      continue;
    }
    if (c === '/' && c2 === '*') {
      i += 2;
      while (i < n && !(text[i] === '*' && text[i + 1] === '/')) i++;
      i += 2;
      continue;
    }
    out += c;
    i++;
  }
  // Trim trailing commas: ,\s*}  or  ,\s*]
  out = out.replace(/,(\s*[}\]])/g, '$1');
  return JSON.parse(out);
}

export function loadSettings(rootDir) {
  const candidates = [
    path.join(rootDir, 'SETTINGS.jsonc'),
    path.join(rootDir, 'SETTINGS.example.jsonc'),
  ];
  let raw = null;
  let source = null;
  for (const p of candidates) {
    if (fs.existsSync(p)) { raw = fs.readFileSync(p, 'utf8'); source = p; break; }
  }
  let parsed = {};
  if (raw) {
    try { parsed = parseJsonc(raw); }
    catch (e) {
      console.warn(`[tritium] failed to parse ${source}: ${e.message}. Falling back to defaults.`);
    }
  }
  const global = { ...DEFAULT_GLOBAL, ...(parsed.global ?? {}) };
  const agents = {};
  for (const name of ROSTER) {
    agents[name] = {
      role: ROLES[name],
      ...DEFAULT_AGENT_STATS,
      ...((parsed.agents ?? {})[name] ?? {}),
    };
  }
  // Allow user-defined extra agents.
  for (const name of Object.keys(parsed.agents ?? {})) {
    if (!agents[name]) {
      agents[name] = {
        role: ROLES[name] ?? 'custom',
        ...DEFAULT_AGENT_STATS,
        ...parsed.agents[name],
      };
    }
  }
  return { global, agents, _source: source };
}

export { ROSTER, ROLES };
