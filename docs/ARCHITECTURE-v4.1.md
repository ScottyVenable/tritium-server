# Architecture -- Tritium Team v4.1 (Omni-Refactor)

Extends v4.0 Genesis. See ARCHITECTURE-v4.md for base components.

## New in v4.1

### Encrypted vault (tritium-crypt)

AES-256-GCM encrypted payload store at `world/vault/`.
X25519/HKDF-SHA-256 key wrapping. Ed25519 manifest signing.
Full spec: docs/SECURITY-tritium-crypt.md.

CLI: `tritium-crypt {init,init-keys,seal,open,close,verify,list,status}`
Wrappers: `tritium-open <id>`, `tritium-close <id>`

### Tier system (tier-auto)

Four-tier agent model:

| Tier | Agent  | Model             | Scope                  |
|------|--------|-------------------|------------------------|
| T0   | Scout  | gemini-3-flash    | Baseline, always-on    |
| T1   | Bridge | gemini-1.5-pro    | Coordination only      |
| T2   | Sol/Jesse/Vex | claude-sonnet-4.6 | Specialists  |
| T3   | Rook   | claude-opus-4.7   | QA/release             |

CLI: `tier-auto {set <0-3>,snap,status,agent}`

Snap-back: after any T1+ session, `tier-auto snap` closes open vault
payloads and returns runtime to T0 (Scout).

### Scout (T0 pre-dispatch)

Bridge now pre-dispatches T0-safe requests to Scout before any routing
decision (Rule 0). Scout handles greetings, status queries, lightweight
lookups without escalating tier or cost.

### Control panel (tritium-cp)

Python ASCII dashboard. Shows registry, tier, Scout, vault, ledger,
shield, git branch, and credits at a glance.

CLI: `tritium-cp` or alias `tcp`

### Diagnostics (tritium-doctor)

11-point diagnostic suite. Exits non-zero on FAIL.
Checks all v4.1 components including crypto keys, open payloads,
gitignore boundary, and shield freshness.

CLI: `tritium-doctor`

### Shield

`~/.tritium-team/state/shield.ok` -- timestamp file renewed by
`tritium-authorize`. tritium-open checks freshness (< 24h).

## Data flow

```
Request
  |
Bridge (T1) -- Rule 0 --> Scout (T0) if T0-safe
  |
  +--> Sol / Jesse / Vex (T2) for specialist work
  +--> Rook (T3) for QA/release
  |
tier-auto snap --> T0 (Scout)  [closes vault payloads]
```

## File layout additions

```
.github/agents/         agent spec .md files
agents/scout/           Scout runtime directory
data/registry/
  models.json           tier/model registry
  credits.ledger        credit monitoring
world/vault/
  manifest.json         encrypted payload index
  *.enc                 ciphertext blobs
.tritium_mirror/        ephemeral plaintext (gitignored)
data/
  ledger.schema.sql     SQLite schema
bridge/tritium_bridge/
  ledger.py             event ledger facade
mobile-environment/configs/
  bashrc.sh             Termux shell integration
scripts/
  tritium-crypt         vault CLI (Python)
  tritium-open          open wrapper (bash)
  tritium-close         close wrapper (bash)
  tier-auto             tier manager (bash)
  tritium-cp            control panel (Python)
  tritium-doctor        diagnostics (bash)
  tritium-id            identity printer (bash)
  tritium-authorize     shield renewal (bash)
  setup.sh              idempotent bootstrapper (bash)
docs/
  SECURITY-tritium-crypt.md
  ARCHITECTURE-v4.md
  ARCHITECTURE-v4.1.md
AGENTS.md               agent roster
```
