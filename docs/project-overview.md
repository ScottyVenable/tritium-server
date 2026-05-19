# Tritium OS Project Overview

This document is a repo-grounded overview of the Tritium OS project as it exists in this checkout under `/storage/self/primary/Coding/tritium_os`.

It is intentionally broad and practical. It covers what Tritium is, why it exists, how the repo is laid out, how the runtime works, what the agents are for, how adapters fit in, what the world layer is doing, how install and verify flows work, what packaging and release paths currently look like, where the rough edges are, and which parts are clearly current versus clearly historical or aspirational.

Where the repository contains drift between older and newer layers, this document says so plainly.

---

## Table of Contents

1. [Executive summary](#executive-summary)
2. [What Tritium is](#what-tritium-is)
3. [Why the project exists](#why-the-project-exists)
4. [Core design ideas](#core-design-ideas)
5. [Current repo snapshot at a glance](#current-repo-snapshot-at-a-glance)
6. [Top-level directory map](#top-level-directory-map)
7. [How the major pieces fit together](#how-the-major-pieces-fit-together)
8. [Runtime server architecture](#runtime-server-architecture)
9. [SQLite data model and message bus](#sqlite-data-model-and-message-bus)
10. [REST API and WebSocket surface](#rest-api-and-websocket-surface)
11. [Dashboard](#dashboard)
12. [CLI](#cli)
13. [Settings model](#settings-model)
14. [Agent roster and responsibilities](#agent-roster-and-responsibilities)
15. [Agent directories, memory, portfolio, and prompt discipline](#agent-directories-memory-portfolio-and-prompt-discipline)
16. [Adapters](#adapters)
17. [OpenAI-compatible runner](#openai-compatible-runner)
18. [Heartbeat service](#heartbeat-service)
19. [Scripts](#scripts)
20. [Install flow](#install-flow)
21. [Verify flow](#verify-flow)
22. [Package flow](#package-flow)
23. [Release and CI flow](#release-and-ci-flow)
24. [World layer](#world-layer)
25. [Operational patterns](#operational-patterns)
26. [Docs map](#docs-map)
27. [Known constraints and current limitations](#known-constraints-and-current-limitations)
28. [Current state: what looks current, legacy, or aspirational](#current-state-what-looks-current-legacy-or-aspirational)
29. [Extension points](#extension-points)
30. [Terminology](#terminology)
31. [Practical mental model](#practical-mental-model)
32. [Closing summary](#closing-summary)

---

## Executive summary

Tritium is a local-first multi-agent coordination layer. In the current repo, that means:

- A Node-based runtime under `runtime/server/` that exposes a local REST API, WebSocket updates, a SQLite message store, and a no-build dashboard at `http://localhost:7330` by default.
- A CLI at `runtime/cli/tritium.js` plus launcher scripts under `scripts/` for starting the runtime, checking inboxes, sending IM/email, listing agents, and reading status.
- A nine-agent roster in `agents/` and `AGENTS.md`: Bridge, Scout, Sol, Jesse, Vex, Rook, Robert, Lux, and Nova.
- Several adapter packs under `adapters/` for VS Code Copilot, Claude CLI, Gemini CLI, and OpenAI-compatible endpoints such as LM Studio.
- A settings model in `SETTINGS.example.jsonc` plus JSON schemas in `runtime/schemas/`.
- A "world" snapshot in `world/` that captures social channels, locations, team conventions, and in-world identity.
- A separate Python heartbeat service under `runtime/heartbeat/` that is still present and documented, but clearly reflects an older world-tree layout and should be treated as a distinct, partially legacy subsystem rather than the current normalized runtime core.

At the highest level, Tritium is trying to solve a practical problem: how to make a group of named, role-specific AI agents feel like a coherent crew inside a real repository, with shared settings, shared conventions, visible communication, and portable adapter integration.

The current repo is strongest and most internally consistent around:

- the Node runtime,
- the CLI,
- the dashboard,
- the current `agents/` tree,
- the install and verify scripts,
- the settings and schemas,
- and the docs in `README.md`, `docs/architecture.md`, `docs/settings-reference.md`, and `docs/troubleshooting.md`.

The current repo also carries older or transitional layers, especially around:

- the Python heartbeat service's assumption of bracketed world paths,
- legacy v4.1 security and vault utilities,
- registry and tier tooling that still points at old paths or older rosters,
- and some world and adapter text that still describes an earlier eight-agent or five-working-agent view.

That does not make the repo incoherent. It means Tritium is in the middle of a unification process that the `CHANGELOG.md` explicitly describes as "Tritium-OS unification (Phases A-D)".

---

## What Tritium is

The README defines Tritium as:

> "A portable, local-first multi-agent workflow coordination layer."

That definition matters because it tells you what Tritium is not trying to be.

Tritium is not:

- a hosted SaaS,
- a single monolithic assistant,
- a full agent execution platform with container orchestration,
- or a purely fictional roleplay layer disconnected from actual repo operations.

In this repo, Tritium is a coordination product made of several linked layers:

| Layer | What it does now | Primary paths |
|---|---|---|
| Runtime | Stores messages, serves dashboard/API, exposes CLI | `runtime/server/`, `runtime/cli/`, `runtime/dashboard/` |
| Agent definitions | Defines who each agent is and what lane they own | `agents/`, `AGENTS.md` |
| Settings | Controls port, DB path, dry-run behavior, per-agent behavior | `SETTINGS.example.jsonc`, `runtime/schemas/settings.json` |
| Adapters | Lets external tools load Tritium prompts and conventions | `adapters/` |
| Scripts | Bootstraps, verifies, packages, scaffolds, and launches | `scripts/` |
| World | Snapshot of team social space, locations, and conventions | `world/` |
| Heartbeat | Separate Python service that can generate world activity through LM Studio + email | `runtime/heartbeat/` |

The term "Tritium OS" is used in script headers, changelog history, and security docs. The top-level product name in the README is just "Tritium." In practice, the repo uses both. A fair reading is:

- "Tritium" = the product label,
- "Tritium OS" = the broader operating layer identity that includes scripts, vault tooling, and world conventions.

---

## Why the project exists

The repo itself answers this in several different ways.

### 1. It wants agent work to be local-first and portable

The README, architecture doc, and runtime code all reinforce the same stance:

- local SQLite instead of a hosted DB,
- local dashboard bound to `127.0.0.1`,
- local adapter files copied into target repos,
- no provider keys stored in repo files,
- and `dryRun: true` by default.

This is not an "AI cloud control plane" design. It is a "put this next to your repo and run it on your own machine" design.

### 2. It wants named specialists instead of one generic assistant

The team structure is one of the core ideas of the project. Instead of asking one general assistant to pretend to be everything at once, Tritium formalizes lanes:

- Bridge routes and plans.
- Scout handles baseline, lightweight work.
- Sol owns code and implementation.
- Jesse owns repo operations and tracking.
- Vex owns authored content and reference pages.
- Rook owns QA and release readiness.
- Robert owns research.
- Lux owns visuals and art direction.
- Nova owns systems and balancing.

This is reflected not only in prose but in concrete files, settings, and adapter prompts.

### 3. It wants communication to be inspectable

Tritium's runtime supports:

- IM messages,
- email-style messages,
- read receipts,
- threads,
- a timeline,
- dashboard views,
- and CLI inbox checks.

The world snapshot supports:

- mailbox notes,
- direct communication files,
- message board posts,
- public blog entries,
- handoff packets,
- planning records,
- and team conventions.

The point is not just "agents can talk." The point is "their talk leaves visible, navigable artifacts."

### 4. It wants adapters to be drop-in

The adapters are intentionally file-copy based. The install scripts do not try to be clever package managers for every environment. They copy adapter payloads into target repos and keep local behavior understandable.

### 5. It wants human operators to stay in control

This shows up in several design choices:

- `dryRun: true` by default,
- local-only binding,
- no built-in auth for public tunnel mode,
- explicit warning that tunneled URLs should be treated as secrets,
- no self-merging in many agent definitions,
- and Bridge explicitly surfacing options instead of making major design choices on the human's behalf.

---

## Core design ideas

Across the repo, several design principles recur.

### Local-first

The runtime binds to `127.0.0.1`. SQLite is a single local file. The dashboard is a static SPA served from the same local runtime. Tunnel mode is documented, but not bundled.

### Portable

Install scripts support Bash and PowerShell. Adapters are installable into arbitrary target repos. The runtime avoids frameworks. The dashboard has no build step.

### Explicit roles

The agent system is not just naming flair. Roles are encoded in:

- `agents/<name>/agent.md`,
- adapter prompt files,
- `AGENTS.md`,
- `world/social/team/TEAM.md`,
- and `SETTINGS.example.jsonc`.

### Transparent coordination

Inbox checking, message views, read receipts, timeline, mailboxes, and handoffs all make coordination visible.

### Low default risk

The repo defaults toward:

- dry-run adapter behavior,
- environment-only API keys,
- local-only networking,
- explicit verify steps,
- and early runtime preflight checks.

### Plain files over hidden state

The project uses a lot of visible, inspectable files:

- markdown docs,
- JSONC settings,
- JSON schemas,
- sqlite DB,
- mailbox text files,
- handoff markdown,
- issue templates,
- adapter prompt files.

That makes the system easier to reason about and easier to recover when something drifts.

---

## Current repo snapshot at a glance

At the repo root, `view` shows these visible top-level entries:

```text
.gemini
.git
.github
.gitignore
.obsidian
AGENTS.md
CHANGELOG.md
LICENSE
README.md
SETTINGS.example.jsonc
adapters
agents
bridge
data
dist
docs
runtime
scripts
world
```

The directories that matter most for the current project shape are:

| Path | Role in current repo |
|---|---|
| `runtime/` | Current runtime and server-side product core |
| `scripts/` | Install, verify, package, launch, and older v4.1 utility layer |
| `agents/` | Canonical current agent definitions |
| `adapters/` | Integration packs for external tools |
| `world/` | Snapshot of the social and narrative layer |
| `docs/` | Product docs, settings docs, troubleshooting, usage |
| `data/registry/` | Legacy or transitional model/tier registry and credit ledger |
| `dist/` | Built package artifacts |

The repo already contains packaged artifacts:

```text
dist/
  tritium-v0.1.0.zip
  tritium-v0.1.0.zip.sha256
```

That matters because packaging is not hypothetical. The packaging scripts are already being used to produce distribution outputs.

---

## Top-level directory map

This is a practical map of the top-level repo, based on current contents rather than generic expectations.

```text
tritium_os/
├── .github/                  # Repo-level CI and agent assets
├── AGENTS.md                 # Human-readable current roster
├── CHANGELOG.md              # History, unification notes, future notes
├── README.md                 # Main entrypoint for users
├── SETTINGS.example.jsonc    # Master settings template
├── adapters/                 # Drop-in integration packs
├── agents/                   # Canonical agent definitions and support dirs
├── data/registry/            # Model/tier registry and credit ledger
├── dist/                     # Built zip artifacts
├── docs/                     # Architecture, settings, usage, troubleshooting
├── runtime/                  # Runtime server, dashboard, CLI, schemas, heartbeat
├── scripts/                  # Install/verify/package and older OS-style utilities
└── world/                    # Snapshot of social/world layer
```

### Notes on notable top-level paths

#### `.github/`

The root `.github/` currently contains:

```text
.github/
  agents
  workflows
```

The visible workflow at repo root is `.github/workflows/verify.yml`, which runs Node 20 and Python 3.11 checks on Linux and Windows and then invokes `scripts/verify.sh` or `scripts/verify.ps1` after starting the runtime.

#### `bridge/`

There is a top-level `bridge/` directory visible at repo root, but the main repo structure and changelog indicate the active heartbeat code now lives under `runtime/heartbeat/`. That top-level `bridge/` presence is another signal that the repo carries transitional history.

#### `data/registry/`

This directory now exists at the flattened `data/registry/` path, but some older scripts still reference `registry/` directly rather than `data/registry/`.

That is important enough to repeat later under limitations.

---

## How the major pieces fit together

If you want one mental model before all the details, use this:

1. **Agents are defined in files.**  
   `agents/<name>/agent.md` is the canonical role definition.

2. **Settings shape runtime behavior.**  
   `SETTINGS.jsonc` or `SETTINGS.example.jsonc` controls the port, database path, dry-run defaults, and per-agent stats.

3. **The Node runtime provides the active coordination layer.**  
   It stores IM and email, serves the dashboard, and exposes the local API.

4. **The CLI is the command-line face of the runtime.**  
   `tritium serve`, `tritium inbox check`, `tritium send-im`, and related commands all route through the runtime or file-mailbox fallback.

5. **Adapters let external AI tools act inside Tritium's conventions.**  
   Claude CLI, Gemini CLI, Copilot, and OpenAI-compatible endpoints all get prompt packs or runner glue.

6. **The world layer gives the agents a social and narrative surface.**  
   It is not required to run the runtime, but it is part of how Tritium presents the crew and supports file-based fallbacks and handoffs.

7. **The heartbeat is a separate service.**  
   It can generate journals, message-board posts, or emails through LM Studio and email, but it currently depends on an older external world-tree layout.

### Data flow in the current normalized runtime

The normalized runtime flow described in `docs/architecture.md` is:

1. User runs `tritium serve`.
2. Runtime loads settings and opens or migrates SQLite.
3. Dashboard becomes available at `http://localhost:<dashboard_port>`.
4. Adapter or user-triggered commands send IM/email through the REST API.
5. Dashboard receives WebSocket events and updates live.
6. Agents check inbox using `tritium inbox check`.
7. If runtime is unavailable, inbox check falls back to file mailboxes in `world/social/mailbox/<agent>/`.

### Coordination flow in the broader Tritium model

The broader model adds:

- handoffs in `world/social/team/handoffs/`,
- planning docs in `world/social/team/interactions/`,
- branch and PR rules in agent definitions,
- and role-specific ownership boundaries enforced socially rather than only technically.

---

## Runtime server architecture

The runtime server lives under:

```text
runtime/server/
  cli/tritium.js
  package.json
  package-lock.json
  src/
    api.js
    db.js
    index.js
    preflight.js
    settings.js
    verify.js
```

### Stack

From `runtime/server/package.json`:

- Node `>=20.0.0`
- `better-sqlite3`
- `ws`
- ES modules
- no external HTTP framework

This is consistent with the architecture doc, which explicitly says Node's built-in `http` is used because it is enough for a local tool.

### Main runtime responsibilities

`runtime/server/src/index.js` says the runtime is responsible for:

1. opening and migrating the SQLite database,
2. serving a REST API for IM, email, agents, settings, and timeline,
3. serving a WebSocket stream for live updates,
4. serving the static dashboard SPA.

### Binding model

The server listens on:

- host: `127.0.0.1`
- port: `settings.global.dashboard_port` or `7330` by default

That means Tritium is explicitly local-only by default.

### Why this matters

Many agent systems bury their state behind a proprietary backend. Tritium makes the runtime:

- inspectable,
- small,
- portable,
- and easy to debug with `curl`, a browser, and a SQLite viewer.

### Settings loading behavior

The runtime loads settings through `runtime/server/src/settings.js`.

It checks:

1. `SETTINGS.jsonc`
2. `SETTINGS.example.jsonc`

It parses JSONC by stripping:

- line comments,
- block comments,
- and trailing commas.

That is practical, because the settings template is heavily commented and meant for humans first.

### Default roster built into runtime

The runtime's settings loader hardcodes a current roster:

```text
bridge
scout
sol
jesse
vex
rook
robert
lux
nova
```

This is important for two reasons:

1. It ensures a nine-agent view even if settings are incomplete.
2. It means the runtime can seed default stats for agents missing from the settings file.

That second behavior is already necessary because `SETTINGS.example.jsonc` currently does **not** include an explicit `scout` section, even though the runtime roster does.

---

## SQLite data model and message bus

The database layer lives in `runtime/server/src/db.js`.

### Database path

By default, the DB path is:

```text
./.tritium/tritium.db
```

Resolved relative to the repo root unless overridden in settings.

### Database characteristics

`db.js` sets:

- WAL mode,
- foreign keys on,
- ISO-like timestamp strings.

Those choices are simple and sensible for a local coordination database:

- WAL supports concurrent readers and writers better than default rollback mode.
- foreign keys help keep attachments and threads consistent.
- readable timestamps make raw inspection easier.

### Tables

The runtime creates these tables:

| Table | Purpose |
|---|---|
| `agents` | Known agents, roles, enabled flag, current task, last heartbeat |
| `threads` | IM thread metadata |
| `im_messages` | Short messages between agents |
| `email` | Longer messages with subject/body |
| `email_attachments` | Attachment records for email |
| `read_receipts` | Per-message read tracking |
| `settings_cache` | Settings mirror/cache table |

### Table-by-table interpretation

#### `agents`

Fields:

- `name`
- `role`
- `enabled`
- `current_task`
- `last_heartbeat`

This table turns settings data into runtime-visible agent state.

#### `threads`

Fields:

- `id`
- `subject`
- `created_at`

If an IM is sent with a subject but no thread ID, the runtime creates a thread.

#### `im_messages`

Fields:

- `id`
- `thread_id`
- `sender`
- `recipient`
- `body`
- `created_at`

This is the short-message layer.

#### `email`

Fields:

- `id`
- `sender`
- `recipient`
- `subject`
- `body`
- `created_at`

This is the longer-form communication channel.

#### `email_attachments`

Fields:

- `id`
- `email_id`
- `kind`
- `name`
- `ref`

Attachments can be either:

- `path`
- `inline`

That design avoids forcing the runtime to store file blobs in a more complex way than needed.

#### `read_receipts`

Fields:

- `kind`
- `message_id`
- `reader`
- `read_at`

This lets inbox views distinguish unread IM from already-read IM.

#### `settings_cache`

This table exists, but the current runtime mainly reads settings directly from disk. The dashboard also currently exposes settings as read-only. So `settings_cache` is more groundwork than a heavily featured live settings system right now.

### Indexes

Indexes are created on:

- IM recipient
- IM thread
- IM created time
- email recipient
- email created time

This is the minimum useful indexing for a communication-focused dashboard.

---

## REST API and WebSocket surface

The runtime server exposes a small, focused local API.

### REST endpoints

From `runtime/server/src/index.js`:

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/api/health` | Health check and version |
| `GET` | `/api/agents` | Agent list with runtime state and stats |
| `GET` | `/api/settings` | Settings snapshot |
| `GET` | `/api/im` | IM list, optionally per-agent and unread-only |
| `POST` | `/api/im` | Send IM |
| `POST` | `/api/im/:id/read` | Mark IM as read |
| `GET` | `/api/email` | Email list, optionally per-agent |
| `POST` | `/api/email` | Send email |
| `POST` | `/api/heartbeat` | Update agent heartbeat |
| `GET` | `/api/timeline` | Unified recent activity feed |

### API validation style

The API layer in `runtime/server/src/api.js` validates required strings and clips payload sizes:

- IM body cap: `32000`
- email body cap: `200000`
- subject cap: `300`
- attachment ref cap: `100000`
- heartbeat current task cap: `500`

The runtime is intentionally defensive without being overengineered.

### Error model

Client-style validation errors may return explicit messages, while unexpected server errors collapse to:

```json
{ "error": "internal server error" }
```

That is a reasonable local-tool security baseline because it avoids leaking file paths and internal stack details through HTTP.

### WebSocket

The server creates a WebSocket server on `/ws`.

It broadcasts:

- `im`
- `email`
- `heartbeat`
- and an initial `hello`

The dashboard uses this for live updates.

### Why the API surface is intentionally small

The current API is not trying to expose every concept in the repo. It is focused on the active coordination runtime:

- messages,
- agent status,
- settings visibility,
- and event timeline.

That makes it stable enough for CLI and dashboard use without pretending the repo is already a full workflow orchestration backend.

---

## Dashboard

The dashboard lives under:

```text
runtime/dashboard/
  index.html
  css/styles.css
  js/app.js
```

### Design philosophy

The dashboard is deliberately simple:

- vanilla JS,
- vanilla CSS,
- no build pipeline,
- no CDN,
- dark theme,
- local-only footer messaging.

The footer says:

> "Local-only. No telemetry."

That sentence is a very good summary of the dashboard's posture.

### Tabs and views

From `runtime/dashboard/index.html`, the dashboard exposes tabs for:

- IM
- Email
- Agents
- Settings
- Timeline

### What each tab does

#### IM

The IM view allows:

- composing and sending IM,
- viewing all IM messages,
- seeing sender, recipient, time, and body,
- and receiving live refreshes through WebSocket.

#### Email

The Email view allows:

- composing and sending email,
- viewing inbox-style email entries,
- showing subject and body,
- and displaying attachment metadata.

#### Agents

The Agents view shows cards with:

- enabled/disabled state,
- role,
- independence,
- verbosity,
- inbox cadence,
- current task,
- last heartbeat.

This is one of the most useful runtime views because it turns abstract agent settings into a visible operational roster.

#### Settings

The Settings view displays the parsed settings object in a `<pre>` block.

Crucially, the view itself states:

> "Read-only in v0.1. Edit SETTINGS.jsonc on disk and restart."

That is an explicit current limitation, not an omission in this overview.

#### Timeline

The Timeline view merges IM and email into a unified stream and truncates bodies for scannability.

### Safety posture in the dashboard

The architecture doc says the dashboard never uses `innerHTML` for user-controlled data. `runtime/dashboard/js/app.js` confirms that:

- it builds DOM nodes through a helper `el()`,
- uses text nodes,
- and does not interpolate arbitrary message bodies into raw HTML.

That is exactly the kind of small safety discipline you want in a local messaging UI.

### Styling characteristics

`runtime/dashboard/css/styles.css` shows a clean, mobile-first layout with:

- dark background palette,
- accent colors,
- sticky top bar,
- minimum 44px touch targets,
- responsive layouts at `720px`,
- monospaced metadata for message headers and stats.

This is not a flashy interface. It is a practical operations panel.

### Current dashboard limitations

Supported by code and docs:

- no live settings editing,
- no auth layer,
- no complex user management,
- no server-side rendering,
- no file upload UI for email attachments,
- no message search UI,
- no advanced filtering beyond what the API already supports.

That is fine for the current scope.

---

## CLI

The canonical CLI entrypoint is:

```text
runtime/cli/tritium.js
```

There is also a thin wrapper at:

```text
runtime/server/cli/tritium.js
```

that simply imports the real CLI.

### Supported commands

The CLI help and source define these commands:

```text
tritium serve
tritium inbox check [--agent <name>] [--all] [--require-api]
tritium send-im --from <a> --to <b> --body "..." [--subject "..."]
tritium send-email --from <a> --to <b> --subject "..." --body "..." [--attach <path>]
tritium run-agent <name> --task "..." [--dry]
tritium agents
tritium status
```

### `serve`

`tritium serve`:

- checks runtime dependency installation via `preflight.js`,
- prints actionable help if `ws` or `better-sqlite3` are missing,
- and then spawns `runtime/server/src/index.js`.

This is better than letting users get a confusing module resolution error.

### `inbox check`

This is one of the defining commands of the project.

Behavior:

- If runtime is up, it shows IM and email from the API.
- If runtime is down, it falls back to `world/social/mailbox/<agent>/`.
- If `--require-api` is passed, fallback is disabled and the command exits non-zero when the runtime is unavailable.

That fallback behavior is important because it lets Tritium preserve a communication model even when the live runtime is down.

### `send-im`

Posts a message through the runtime API. If a subject is provided without a thread ID, the runtime creates a thread row first.

### `send-email`

Posts email through the runtime API. Optional `--attach` creates a `path` attachment entry if the file exists.

### `run-agent`

This command is explicitly a stub in v0.1. The code prints:

```text
# This is the v0.1 stub. Wire your adapter in adapters/<provider>/.
```

That is an important limitation. Tritium has agent definitions and adapters, but the generic "run any agent through the CLI" layer is not yet a finished native dispatch system.

### `agents`

Lists agents from the runtime with:

- enabled dot,
- name,
- role,
- independence,
- verbosity,
- inbox interval.

### `status`

Calls `/api/health` and prints the result as JSON.

### Launcher scripts

The repo also includes launcher wrappers in `scripts/`:

- `scripts/tritium`
- `scripts/tritium.cmd`

The Bash launcher resolves repo root by:

1. using the script-adjacent repo if possible,
2. otherwise reading `~/.tritium-os/state/repo-root`,
3. otherwise failing with guidance to rerun install or set `TRITIUM_REPO_ROOT`.

That makes installed launchers robust across shells and working directories.

---

## Settings model

The master template is `SETTINGS.example.jsonc`. The runtime and adapters read:

1. `SETTINGS.jsonc` if present,
2. otherwise `SETTINGS.example.jsonc`.

### Global settings

Current documented global keys are:

| Key | Meaning |
|---|---|
| `default_model` | Fallback model name when an agent has no override |
| `dashboard_port` | Runtime server, API, WebSocket, and dashboard port |
| `db_path` | SQLite DB path |
| `auto_archive_after_days` | Read IM archive age threshold |
| `premium_budget_hint` | Soft budget guidance to agents |
| `dryRun` | Block outbound adapter API calls unless false |
| `proposed_prompt_edits_dir` | Bridge watchdog proposal output path |

### Per-agent settings

Current per-agent keys are:

| Key | Meaning |
|---|---|
| `independence` | How autonomously the agent acts |
| `verbosity` | Output-length budget |
| `inbox_check_interval` | How often the agent must check inbox |
| `memory_write_quota` | Per-task memory write cap |
| `portfolio_size_limit` | Max portfolio size before prune |
| `model_preference` | Per-agent model override |
| `temperature` | Sampling temperature |
| `enabled` | Whether Bridge should dispatch to this agent |

### Runtime defaults versus template contents

One subtle but important point:

- `runtime/server/src/settings.js` contains a built-in current roster of nine agents.
- `SETTINGS.example.jsonc` currently defines eight agent blocks and omits `scout`.

This means Scout still exists in the runtime with default stats, but it is not explicitly listed in the example settings file.

That is a real repo fact and a good example of current-state drift.

### Budget semantics

The settings reference doc adds behavioral meaning for independence:

| Independence band | Intended behavior |
|---|---|
| `0-3` | Ask often, low autonomy |
| `4-5` | Ask on conflicts or true ambiguity |
| `6` | Default balanced mode |
| `7-8` | Decide and proceed in most cases |
| `9-10` | Maximum autonomy, escalate only for truly user-owned context |

This is useful because it makes "agent personality" operational rather than purely stylistic.

### `dryRun` as a project-wide philosophy switch

`dryRun: true` is one of the most important defaults in the project.

It means:

- adapters will not automatically spend tokens,
- users can inspect payload composition first,
- the project is safer to clone and explore without hidden costs.

For a multi-agent system, that is a strong default.

---

## Agent roster and responsibilities

The current roster in `AGENTS.md` is:

| Agent | Role | Primary lane |
|---|---|---|
| Bridge | Planner / dispatcher / watchdog | Routing, decomposition, handoff quality |
| Scout | Baseline agent | Routine lookups and lightweight requests |
| Sol | Co-creative director / lead programmer | Code, CI, tooling, changelog |
| Jesse | Repository manager | Issues, labels, milestones, board, wiki ops |
| Vex | Content and asset architect | Authored content, docs, lore/reference |
| Rook | QA and release engineer | Build verification, repro, release gating |
| Robert | Research specialist | External references, investigation, gap analysis |
| Lux | Visuals and art direction lead | UI/UX direction, style guides, visual specs |
| Nova | Systems and balance lead | Mechanics, progression, formulas, tuning |

### How the repo distinguishes roster layers

There are actually several roster expressions in the repo:

| File | What it says |
|---|---|
| `AGENTS.md` | Current nine-agent roster |
| `world/social/team/TEAM.md` | Eight-agent coordination map without Scout |
| `README.md` | Current nine-agent crew table |
| `world/README.md` | Five working agents plus three in-world recurring characters |
| adapter `CLAUDE.md` and `GEMINI.md` | Eight-member wording in some places |

This is not a reason to distrust the repo. It is a reason to understand its layering and recency:

- `AGENTS.md`, `README.md`, runtime code, and verify scripts reflect the current nine-agent operational direction.
- parts of `world/` and some adapter copy still reflect earlier phases or a different "active workers versus in-world characters" distinction.

### Bridge

Bridge is the dispatcher and planner. `agents/bridge/agent.md` makes several things explicit:

- Bridge does not implement work itself.
- Bridge routes by lane.
- Bridge sequences cross-domain work.
- Bridge should not dispatch more than four agents at once in CLI mode.
- Bridge handles watchdog proposals for prompt drift.

Bridge is the main "entrypoint identity" for the system when the user does not name a specific specialist.

### Scout

Scout is the lightweight baseline or T0 agent. Its `agent.md` is much shorter than the specialist agent files and explicitly says:

- T0 only,
- surface T1+ work to Bridge,
- memory is ephemeral by default,
- inbox check still applies.

Scout matters as a baseline/snap-back idea even though many world docs barely mention it.

### Sol

Sol's lane is code:

- implementation,
- schemas,
- workflows,
- changelog,
- build commands,
- PR flow.

Sol's agent file is one of the most operationally detailed in the repo and includes PR workflow expectations, build discipline, and UI screenshot capture rules.

### Jesse

Jesse owns:

- issues,
- project board,
- labels,
- milestones,
- wiki operational pages,
- release notes,
- repo hygiene.

Jesse explicitly does not own lore/reference pages or source code.

### Vex

Vex owns:

- authored content files,
- reference/wiki pages,
- mod/example content,
- and tone-sensitive documentation work.

Vex explicitly does not:

- modify schemas,
- write engine code,
- change CI,
- or touch `CHANGELOG.md`.

### Rook

Rook owns:

- build verification,
- CI diagnosis,
- bug reproduction,
- release readiness,
- packaging correctness.

Rook does not author feature code.

### Robert

Robert is research-focused:

- sourced claims,
- citations,
- credibility notes,
- reproducible methods,
- and structured reports.

### Lux

Lux owns:

- visual language,
- style guides,
- tokens/specs,
- accessibility constraints,
- handoff artifacts for Sol and Rook.

Lux explicitly does not author final art assets directly.

### Nova

Nova owns:

- system specs,
- formulas,
- balancing models,
- tuning tables,
- worked examples,
- and performance-budget hints for systems.

Nova explicitly does not implement code.

---

## Agent directories, memory, portfolio, and prompt discipline

Each full agent directory follows a common pattern, even if some agents are simpler than others.

Typical structure:

```text
agents/<name>/
├── agent.md
├── MEMORY.md
├── PORTFOLIO.md
├── prompts/
│   └── system.md
├── identity/
│   ├── PERSONALITY.txt
│   ├── journal/
│   ├── memories/
│   ├── workbook/
│   └── README.txt
├── memory/
│   ├── repo/
│   ├── session/
│   └── personal/
└── portfolio/
```

### `agent.md`

This is the canonical operational contract for the agent.

It usually contains:

- role description,
- allowed and disallowed actions,
- posture/voice,
- workflow expectations,
- team table,
- inbox protocol.

### `prompts/system.md`

This is the adapter-facing prompt scaffold. Adapters and runners load it together with `agent.md`.

### `MEMORY.md`

The memory doc standardizes three scopes:

| Scope | Purpose |
|---|---|
| `memory/repo/` | Repo-scoped durable facts |
| `memory/session/` | Per-task working notes |
| `memory/personal/` | Cross-workspace preferences |

### `PORTFOLIO.md`

This defines:

- what counts as working draft material,
- how to label draft status,
- how to declare destination,
- and how prune discipline works.

Portfolio prune is not a side note. It is treated as a required operational step.

### Identity files

Identity subtrees are a mix of:

- personality text,
- journals,
- workbook notes,
- and world-facing voice material.

Examples:

- `agents/vex/identity/workbook/voice-pillars.txt`
- `agents/jesse/identity/workbook/board-conventions.md`
- `agents/rook/identity/workbook/release-readiness-checklist.md`

These files are not just flavor. They show how the system supports durable, role-specific craft memory.

### Inbox protocol as a shared rule

Every major agent file includes an inbox protocol section:

```text
tritium inbox check --agent <name>
```

and a file-mailbox fallback path:

```text
world/social/mailbox/<name>/
```

This is one of the strongest cross-cutting conventions in the repo.

---

## Adapters

Adapters live under `adapters/`:

```text
adapters/
├── claude-cli/
├── gemini-cli/
├── github-copilot-local/
├── github-copilot-remote/
└── openai-lmstudio/
```

The adapter story is simple by design: copy files into a target repo and let the target environment use its own native mechanism for prompts and instructions.

### Why adapters exist at all

Different AI environments load context in different ways:

- Claude CLI reads `CLAUDE.md`.
- Gemini CLI reads `GEMINI.md` plus `.gemini/settings.json`.
- VS Code Copilot uses `.github/copilot-instructions.md` and custom agent files.
- OpenAI-compatible endpoints need a runner that composes requests and posts them.

Tritium abstracts the team and workflow, but it does **not** pretend all host tools behave the same.

### Adapter installation model

The adapter installer is:

```bash
bash scripts/install-adapter.sh --target /path/to/repo --adapter <name>
```

It:

- walks the adapter directory,
- copies files into the target repo,
- skips adapter README files,
- backs up existing files as `.bak`,
- preserves relative layout.

This is intentionally dumb in the good sense: visible, inspectable, predictable.

---

## OpenAI-compatible runner

The most programmatic adapter is `adapters/openai-lmstudio/`.

Contents:

```text
adapters/openai-lmstudio/
  package.json
  README.md
  src/run.js
```

### Purpose

This runner connects Tritium agents to any endpoint that speaks the OpenAI chat-completions protocol, including:

- LM Studio,
- OpenAI,
- Ollama with an OpenAI shim,
- proxies for Anthropic or Gemini,
- and similar compatible services.

### How it works

`src/run.js` does the following:

1. Parses `--agent` and `--task`.
2. Loads settings.
3. Resolves `dryRun`, model, temperature, and agent stats.
4. Reads:
   - `agents/<name>/prompts/system.md`
   - `agents/<name>/agent.md`
5. Builds a combined `system` prompt.
6. Builds a user prompt that includes:
   - task,
   - independence,
   - verbosity,
   - IM block instructions,
   - signature instruction.
7. If `dryRun`, prints what it would do.
8. Otherwise POSTs to `/chat/completions`.
9. Scans returned text for structured IM blocks:

```text
[[IM to=<name>]]message[[/IM]]
```

10. Forwards those IMs to the local Tritium runtime.

### Why this runner matters

It shows Tritium's architectural style clearly:

- use current agent files as source of truth,
- keep model/provider glue small,
- push live coordination through the runtime,
- and default to dry run.

### Failure behavior

The docs explicitly say the runner fails softly if the runtime is not running:

- the model output is still shown,
- IM forwarding just does not happen.

That is a good operational default.

---

## Heartbeat service

The heartbeat service lives under:

```text
runtime/heartbeat/
```

It has its own Python package:

```text
runtime/heartbeat/tritium_bridge/
```

### What it is supposed to do

The heartbeat README describes it as:

- a local-first agent runtime,
- driven by LM Studio,
- using SMTP and IMAP,
- generating journals, message-board posts, or emails,
- and keeping the Tritium team "alive" while Scotty is offline.

### Current heartbeat modes

From `__main__.py` and the README:

| Mode | Meaning |
|---|---|
| `--check` | Validate env, personas, and LM Studio reachability |
| `--tick` | Run one action and exit |
| `--tick --agent <Name> --action <kind>` | Force a particular agent/action |
| `--dry-run` | Generate but do not write/send |
| `--imap-watch` | Continuous IMAP polling |

### Heartbeat action types

Scheduler weights in `scheduler.py` are:

- `journal`: 50
- `message_board`: 30
- `email`: 20

Email is quota-limited by:

- per-agent nightly cap,
- total nightly cap.

### Tool-call support

The heartbeat has a richer LM loop than the Node runtime. It includes:

- recent-world context injection,
- rolling context summaries,
- OpenAI-style tool-call support,
- and a small tool set for reading team facts, personalities, journals, board, mailbox, and blog.

### Why heartbeat is not the same thing as the Node runtime

This matters a lot.

The Node runtime is the current normalized live coordination core for:

- local API,
- SQLite message bus,
- dashboard,
- CLI.

The heartbeat is a separate Python service for:

- autonomous content generation,
- LM Studio integration,
- IMAP/SMTP exchange,
- and live-world activity.

### Strong current-state caveat: heartbeat clearly assumes an older world layout

This is one of the most important repo realities.

`runtime/heartbeat/tritium_bridge/config.py` still hardcodes bracketed subpaths:

```python
AGENTS_SUBDIR = Path("[3] -- agents --") / "[3a] (agents) directory"
SOCIAL_HUB_SUBDIR = Path("[1] -- social hub --")
```

Other heartbeat files also expect paths such as:

- `[1] -- social hub --/inbox-from-scotty/`
- bracketed agent directory layouts

But the current repo's normalized world snapshot uses:

- `world/social/`
- `world/locations/`
- `world/crew/`

not bracketed folder names.

This means the heartbeat should be read as a distinct subsystem whose source-of-truth world is external and older in shape, not as a drop-in consumer of the repo's normalized `world/` snapshot.

### Additional heartbeat caveats

The heartbeat code also:

- treats only `Bridge`, `Sol`, `Jesse`, `Vex`, and `Rook` as "real agents" in some world-context logic,
- pulls personas from an external `WORLD_ROOT`,
- expects `TEAM_FACTS.md` in that external tree,
- and uses `.env`-driven SMTP/IMAP settings aimed at a real mailbox.

So the heartbeat is real code, but it is not aligned 1:1 with the normalized runtime and world snapshot.

### Still useful conclusions from heartbeat

Even with that drift, it tells us a lot about Tritium's broader ambition:

- agents are intended to have persistent world presence,
- LM-grounded autonomous activity is part of the design,
- truthful disclosure is required in generated email,
- local-model operation is a first-class use case,
- and the system has already dealt with practical issues like fake tool-call blocks, emoji stripping, prompt budgets, and email fallback alerts.

---

## Scripts

The `scripts/` directory is large because it contains both:

1. current bootstrap and packaging tools,
2. older Tritium OS utilities from v4.1.

Current visible files include:

```text
install.sh
install.ps1
install-adapter.sh
install-adapter.ps1
verify.sh
verify.ps1
package.sh
package.ps1
new-agent.sh
new-agent.ps1
setup.sh
setup-ledger.py
tritium
tritium.cmd
tritium-crypt
tritium-open
tritium-close
tritium-doctor
tier-auto
tritium-id
tritium-authorize
tritium-cp
```

### Script categories

| Category | Scripts |
|---|---|
| Current bootstrap | `install.sh`, `install.ps1` |
| Adapter copy/install | `install-adapter.sh`, `install-adapter.ps1` |
| Validation | `verify.sh`, `verify.ps1` |
| Packaging | `package.sh`, `package.ps1` |
| Scaffolding | `new-agent.sh`, `new-agent.ps1`, `setup-ledger.py` |
| Launchers | `tritium`, `tritium.cmd` |
| Deprecated wrapper | `setup.sh` |
| Legacy/OS-style utilities | `tritium-crypt`, `tritium-open`, `tritium-close`, `tritium-doctor`, `tier-auto`, `tritium-id`, `tritium-authorize`, `tritium-cp` |

### Why this split matters

If you are reading the repo operationally, the most current, central scripts are:

- install,
- verify,
- package,
- adapter install,
- new-agent,
- launcher.

The older utility layer is still meaningful, but parts of it clearly lag the current flattened repo layout.

---

## Install flow

The canonical installer is now:

```bash
bash scripts/install.sh
```

or on Windows:

```powershell
powershell -File scripts/install.ps1
```

### What install actually does

From `scripts/install.sh`, the install flow is intentionally conservative:

- detect platform,
- check Node 20+, Python 3.11+, and git,
- create `~/.tritium-os/`,
- initialize ledger DB,
- copy utility scripts into `~/.tritium-os/bin`,
- ensure all nine agent mailboxes exist,
- optionally install Claude/Gemini/Copilot CLIs,
- optionally probe LM Studio,
- print a summary.

### Important install paths

Installer-managed home paths:

```text
~/.tritium-os/
  bin/
  state/
  keys/
  ledger/
```

Important state files:

| Path | Purpose |
|---|---|
| `~/.tritium-os/state/repo-root` | Lets launcher find the repo later |
| `~/.tritium-os/state/env` | Stores detected LM Studio base URL |
| `~/.tritium-os/ledger/ledger.db` | Ledger DB initialized by helper |

### Backward compatibility behavior

If `install.sh` sees:

- `--target`
- or `--adapter`

it delegates to `install-adapter.sh`.

That preserves older usage patterns while making the new installer the main entrypoint.

### Install profiles and flags

Key flags include:

- `--install-deps`
- `--with-claude`
- `--with-gemini`
- `--with-copilot`
- `--with-lmstudio`
- `--profile core|full`
- `--dry-run`
- `--force`
- `--quiet`

### Shared-storage warning

The installer warns when the repo lives on paths like:

- `/storage/...`
- `/sdcard/...`
- `/mnt/sdcard/...`

because `npm ci` may fail when trying to create symlinks under `node_modules/.bin`.

This warning is repeated in the README, troubleshooting, and preflight logic. It is one of the clearest, best-supported operational caveats in the repo.

### Mailbox creation

Install ensures:

```text
world/social/mailbox/
  bridge/
  jesse/
  lux/
  nova/
  robert/
  rook/
  scout/
  sol/
  vex/
```

That is important because the file-mailbox fallback is part of the product, not just a doc idea.

### Installer summary output

The installer prints a concrete operational summary including:

- tool versions or missing-tool hints,
- Tritium home status,
- ledger status,
- mailbox presence,
- adapter coverage counts,
- optional CLI presence,
- LM Studio reachability,
- overall readiness.

That summary is a strong UX touch for a repo-local tool.

---

## Verify flow

The current verification scripts are:

- `scripts/verify.sh`
- `scripts/verify.ps1`

### What verify checks

Current checks include:

- Node version,
- Python version,
- git presence,
- required repo paths,
- `runtime/cli/tritium.js`,
- `runtime/server/`,
- `runtime/heartbeat/`,
- `data/registry/models.json`,
- all nine mailboxes,
- all nine `agents/<name>/agent.md` files,
- adapter prompt coverage for Claude CLI, Gemini CLI, and Copilot local,
- inbox CLI smoke test against the **live** runtime API,
- ledger presence (warn-only),
- optional CLI presence (warn-only),
- LM Studio reachability (warn-only).

### Why the live API check matters

The changelog specifically notes that verify now requires the runtime API for the inbox smoke test. That is a deliberate tightening:

- before, mailbox fallback could make verification look healthy even if the runtime was down;
- now, `--require-api` makes the smoke test honest.

### Repo-level CI integration

Root CI in `.github/workflows/verify.yml`:

- installs runtime deps,
- starts the runtime,
- waits for `/api/health`,
- runs the verify script.

That means the verify scripts are not just developer convenience. They are part of the actual quality gate.

### Runtime smoke verification

There is also a lower-level runtime-specific verifier at:

```text
runtime/server/src/verify.js
```

It:

- creates temporary settings,
- boots the server on port `7331`,
- tests IM send/list/read,
- tests email send with attachment,
- tests heartbeat update,
- tests timeline,
- and exits based on check results.

This is a good sign. It means the runtime itself has a direct smoke test independent of the broader repo verifier.

---

## Package flow

Packaging scripts are:

- `scripts/package.sh`
- `scripts/package.ps1`

### Bash package flow

The Bash packager:

1. reads version from `runtime/server/package.json`,
2. creates `dist/`,
3. builds `dist/tritium-v<VERSION>.zip`,
4. excludes:
   - `dist/`
   - `node_modules/`
   - `.tritium*`
   - `*.bak`
5. writes a SHA-256 checksum if possible.

### PowerShell package flow

The PowerShell packager:

1. reads the same runtime version,
2. creates a staging directory in `%TEMP%`,
3. uses `robocopy` with exclusions,
4. zips the staging directory,
5. writes SHA-256 checksum.

### Packager output

The expected output format is:

```text
dist/tritium-v0.1.0.zip
dist/tritium-v0.1.0.zip.sha256
```

The current repo already contains these outputs.

### What packaging tells us about release shape

Tritium is distributed as a source-like package bundle, not a compiled desktop binary. The package includes:

- runtime,
- scripts,
- docs,
- agents,
- adapters,
- world snapshot.

That fits the product's identity as a portable coordination layer.

---

## Release and CI flow

There are several layers to release flow in the repo.

### 1. Changelog-driven release history

`CHANGELOG.md` includes:

- current unification work under `[Unreleased]`,
- v4.1 "Omni-Refactor",
- v4.0 "Genesis",
- current pre-release `0.1.0`,
- and more future-facing notes.

This tells you the repo has both:

- older "OS-style" lineage,
- and a newer normalized runtime/package lineage.

### 2. Runtime package version

The runtime's `package.json` is versioned `0.1.0`, and package scripts use that version for zip names.

### 3. CI verification

Repo-level GitHub Actions in `.github/workflows/verify.yml` check:

- Linux,
- Windows,
- runtime startup,
- CLI help,
- `npm ci`,
- verify scripts.

### 4. Adapter-remote workflow template

The remote Copilot adapter includes its own workflow file:

```text
adapters/github-copilot-remote/.github/workflows/tritium-verify.yml
```

That workflow runs:

- checkout,
- Node setup,
- `npm ci || npm install`,
- runtime smoke test via `node src/verify.js`

on PRs touching `runtime/**`.

### 5. Rook's release-readiness worldview

Rook's agent file and workbook make the release posture explicit:

- no P0/P1 blockers,
- build commands green,
- version metadata correct,
- changelog valid,
- artifact names correct,
- smoke verification done.

But `agents/rook/identity/workbook/release-readiness-checklist.md` also clearly says it is an **early stub** and should not yet be treated as the fully active gate. It even references another project shape (`DesktopPal`) in several checklist items, which strongly suggests it is a carried-forward template rather than a Tritium-specific finalized release gate.

That is exactly the kind of thing this overview should call out.

### 6. Practical current release flow

Grounded in current repo behavior, the release flow is best understood as:

1. update code/docs/settings/agents as needed,
2. keep `[Unreleased]` changelog current,
3. run install or runtime preflight where needed,
4. run `npm ci` in `runtime/server`,
5. run verify script,
6. run runtime smoke verify if doing runtime changes,
7. package with `scripts/package.sh` or `.ps1`,
8. publish `dist/` artifact and checksum.

This is a real, workable pre-release pipeline.

---

## World layer

The `world/` directory is one of Tritium's most distinctive features.

### What the repo says `world/` is

`world/README.md` is explicit:

- it is a snapshot of the team's living world,
- it is **not** product code,
- it is **not** required to run the runtime,
- the authoritative copy lives elsewhere on Scotty's machine,
- the repo copy may lag.

That framing is essential.

### Main world sections

Current visible structure:

```text
world/
├── crew/
├── locations/
├── social/
└── vault/
```

### `world/social/`

`world/social/README.txt` describes four channels:

| Channel | Purpose |
|---|---|
| `direct communication/` | Threaded DM-style conversations |
| `mailbox/` | One-way or lightweight notes to a specific person |
| `message board/` | Public team announcements |
| `public blog/` | Longer-form reflections or essays |

This is not runtime-only messaging. It is a file-based social layer with specific etiquette and use cases.

### `world/social/mailbox/`

Each agent has a mailbox directory. The repo contains real sample notes, for example:

- `world/social/mailbox/vex/2026-05-05-from-sol-content-merged.txt`
- `world/social/mailbox/vex/2026-05-05-from-jesse-content-labels.txt`

These examples show the mailbox layer functioning as a low-friction handoff surface.

### `world/social/direct communication/`

The repo includes a thread file:

```text
world/social/direct communication/jesse--vex.md
```

It models append-only conversation with explicit "newest at the bottom" guidance.

### `world/social/message board/`

The repo includes public posts such as:

- `2026-05-04--welcome-to-the-tritium.md`
- `2026-05-05--ship-log-week-of-05-04.md`

These illustrate the social layer's tone and practical use:

- team-wide orientation,
- weekly ship notes,
- work visibility.

### `world/social/team/`

This subarea contains:

- `TEAM.md`
- `handoffs/`
- `interactions/`
- `correspondence/`
- `thoughts/`

It is where the repo formalizes how agents work together.

### `world/locations/`

The locations layer gives physical or semi-physical places for the crew:

- `the-office`
- `vexs-room`
- `sols-apartment`
- `jesses-room`
- `rooks-place`
- `lux-studio`
- `nova-loft`
- `roberts-spot`
- `bridges-house`
- `the-cafe`
- `the-library`

These are in-world context files, not runtime dependencies.

### `world/vault/`

The vault directory is the encrypted payload store in the current normalized layout:

```text
world/vault/
  manifest.json
  README.md
```

It is accompanied by security docs and older utility scripts for cryptographic sealing/opening/closing.

### Why the world layer exists

The world layer appears to serve at least four purposes:

1. backup of the social/team state,
2. public record of agent identity,
3. file-based fallback communication,
4. continuity and texture for a named-agent workflow.

### Important world-layer caveat

The repo itself warns that `world/` is a snapshot, not real-time truth. So when world files contradict more current runtime or roster files, treat them as older or parallel layers rather than canonical operational truth.

---

## Operational patterns

Tritium is not just code plus prompts. It encodes patterns of work.

### Pattern: inbox-first checkpoints

Every agent file includes:

```text
tritium inbox check --agent <name>
```

That creates a habit loop:

1. do a bit of work,
2. check for incoming messages,
3. continue.

### Pattern: lanes instead of overlapping authority

The project repeatedly defines boundaries:

- Sol owns code and changelog.
- Jesse owns repo operations and issue state.
- Vex owns authored content and reference pages.
- Rook owns QA/release verification.
- Lux and Nova produce specs, not final code/assets.

This is critical for keeping multi-agent work legible.

### Pattern: file artifacts for coordination

Instead of hiding all collaboration in chat output, Tritium uses:

- mailboxes,
- handoff packets,
- planning docs,
- portfolio drafts,
- memory files,
- workbook notes.

### Pattern: verify before claiming health

The repo does not settle for "the files exist." It includes:

- dependency preflight,
- runtime smoke verify,
- full verify scripts,
- CI workflow integration.

### Pattern: dry-run first

Several parts of the repo default to non-invasive or no-spend behavior:

- installer is conservative by default,
- adapters default to `dryRun: true`,
- runtime only binds locally.

### Pattern: promotion workflow

Portfolio files are explicitly non-canonical until promoted. That means the system is trying to distinguish:

- current experiment,
- review artifact,
- canonical product state.

### Pattern: visible handoffs

`world/social/team/TEAM.md` and `handoffs/README.md` make handoffs explicit, rather than assuming agents can pass context invisibly.

---

## Docs map

The `docs/` directory currently includes:

```text
adding-a-new-agent.md
architecture.md
ARCHITECTURE-v4.md
ARCHITECTURE-v4.1.md
SECURITY-tritium-crypt.md
settings-reference.md
troubleshooting.md
usage-api-openai-lmstudio.md
usage-claude-cli.md
usage-gemini-cli.md
usage-vscode-copilot.md
```

### Practical docs classification

| Doc | What it is best read as |
|---|---|
| `README.md` | Current product landing page |
| `docs/architecture.md` | Current normalized runtime/system overview |
| `docs/settings-reference.md` | Current settings key reference |
| `docs/troubleshooting.md` | Current operational caveats and fixes |
| `docs/usage-*.md` | Current user guidance for adapters |
| `docs/adding-a-new-agent.md` | Current scaffolding guide |
| `docs/ARCHITECTURE-v4.md` | Historical architecture context |
| `docs/ARCHITECTURE-v4.1.md` | Historical/transition architecture context |
| `docs/SECURITY-tritium-crypt.md` | Security spec for the vault tooling layer |

### What the docs are especially good at

Current docs are strongest on:

- explaining the runtime architecture,
- documenting settings,
- showing adapter usage,
- warning about shared-storage npm problems,
- warning about tunnel-mode security,
- and explaining the current install/verify flow.

### What the docs visibly reveal about project evolution

Several docs retain traces of earlier phases:

- v4 and v4.1 architecture docs,
- security spec centered on older vault tooling,
- and some usage or adapter files that refer to earlier path shapes or roster counts.

That is not unusual in a repo undergoing active reorganization, but it is important for readers to notice.

---

## Known constraints and current limitations

This section only includes limitations that are directly supported by repo files, docs, or code.

### Dashboard settings are read-only

The dashboard explicitly says so in code:

> "Read-only in v0.1. Edit SETTINGS.jsonc on disk and restart."

### `tritium run-agent` is a stub

The CLI explicitly prints that it is a v0.1 stub.

### Runtime depends on local install of `ws` and `better-sqlite3`

`runtime/server/src/preflight.js` checks for these exact packages and refuses to start cleanly if they are missing.

### Shared storage can break `npm ci`

This appears in:

- README
- install script
- preflight help
- troubleshooting docs
- usage docs for OpenAI-compatible runner

It is one of the best-supported constraints in the repo.

### Tunnel mode has no auth in v0.1

`docs/troubleshooting.md` explicitly says:

- Tritium has no auth in v0.1,
- tunneled URLs should be treated as secrets,
- `dryRun: true` is recommended while tunneled.

### Heartbeat path assumptions are outdated relative to normalized repo world

Supported by heartbeat code using bracketed world paths.

### Heartbeat relies on external environment and external world tree

It needs:

- SMTP creds,
- IMAP creds,
- LM Studio URL/model,
- external `WORLD_ROOT`,
- project name.

That makes it a more environment-dependent subsystem than the Node runtime.

### Settings/template drift exists

As noted:

- runtime expects nine-agent roster,
- settings template omits Scout,
- some world and adapter docs still describe eight-member or five-working-agent arrangements.

### Legacy scripts still reference older paths

Examples:

- `scripts/tritium-doctor` looks for `world_vault/manifest.json` and `registry/models.json`
- `scripts/tier-auto` points at `registry/models.json`
- `scripts/tritium-crypt` defaults to `world_vault` rather than current `world/vault`

But the normalized repo uses:

- `world/vault/`
- `data/registry/`

This is one of the clearest current-state mismatches in the repository.

### World snapshot is not authoritative live state

`world/README.md` says the authoritative world is external and the repo copy may lag.

### Some workbook/checklist content is template-carried from other contexts

Rook's release-readiness checklist references `DesktopPal` paths and Windows EXE packaging expectations, which makes it useful as a pattern but not yet fully Tritium-specific.

### Security tooling is meaningful but not fully aligned with normalized paths

The vault security model is thoughtfully documented, but some utilities still assume older directory names.

---

## Current state: what looks current, legacy, or aspirational

This section is not a value judgment. It is a practical map for readers trying to understand what to trust most.

### Clearly current and internally consistent

These pieces align well with each other:

- `README.md`
- `docs/architecture.md`
- `docs/settings-reference.md`
- `runtime/server/`
- `runtime/cli/`
- `runtime/dashboard/`
- `runtime/schemas/`
- `scripts/install.sh`
- `scripts/verify.sh`
- `scripts/package.sh`
- `AGENTS.md`
- current `agents/` roster

These are the safest paths to treat as current core.

### Current but still evolving

These pieces are active and useful, but show transitional seams:

- `SETTINGS.example.jsonc` versus runtime default roster
- `world/` snapshot versus runtime roster
- adapter docs versus some current file/path expectations
- `data/registry/` versus older script references

### Legacy or partially legacy but still important

These pieces clearly come from an earlier phase or older repo layout:

- v4 and v4.1 architecture docs
- `scripts/tritium-doctor`
- `scripts/tier-auto`
- `scripts/tritium-crypt`, `tritium-open`, `tritium-close`
- parts of `runtime/heartbeat/`
- portions of `world/README.md` that reference older folder ideas

These are still worth documenting because they reveal the project's lineage and still ship in the repo, but they should not automatically be treated as the source of truth for the normalized runtime.

### Aspirational or explicitly future-facing

`CHANGELOG.md` includes explicit future items such as:

- editable settings panel in dashboard,
- first-class native adapters for OpenAI Assistants API and Anthropic Messages API,
- multi-repo aware Bridge planner.

These should be read as plans, not current features.

### Best "source of truth" rule for this repo

When files disagree, a reasonable priority order is:

1. current runtime code and current scripts,
2. README and current docs,
3. current `agents/` files and `AGENTS.md`,
4. changelog when describing the migration path,
5. world snapshot and older utility docs for historical or parallel context.

---

## Extension points

Tritium is designed to be extended in several practical ways.

### Add a new agent

Current supported path:

```bash
bash scripts/new-agent.sh <name> "<role description>"
```

This scaffolds:

- `agents/<name>/`
- memory directories
- portfolio directory
- system prompt
- settings stub insertion
- roster row insertion in `world/social/team/TEAM.md`
- adapter registration for Claude, Gemini, and Copilot local

This is one of the clearest extension mechanisms in the repo.

### Add per-agent settings

The runtime settings loader explicitly allows user-defined extra agents beyond the built-in roster. That means extension is not limited to the hardcoded default list.

### Add a new adapter

The adapter design is directory-based. A new adapter can follow the same model:

- create `adapters/<name>/`,
- include the files a target environment needs,
- install by copying with `install-adapter.sh`.

### Extend runtime API

The API layer is small and modular:

- routes in `runtime/server/src/index.js`
- DB operations in `runtime/server/src/api.js`
- schema and storage in `db.js`

Adding more runtime operations is structurally straightforward.

### Extend dashboard views

The dashboard is no-build vanilla JS. New views can be added by:

- adding a tab,
- adding a route handler,
- calling new API endpoints,
- reusing the existing DOM helper style.

### Extend schemas

JSON Schemas live under `runtime/schemas/` and currently cover:

- IM
- email
- handoff
- settings

More message or workflow objects could be added here without changing the overall architecture style.

### Extend world conventions

The world layer is file-oriented and README-driven. Each channel documents how it should be used. That means extensions are social and structural, not just code-level.

### Extend security/vault tooling

The vault tooling is already implemented as standalone scripts with a documented threat model. Path drift would need cleanup first, but the crypto layer is designed as an extensible subsystem.

### Extend CI

There is already:

- repo-level verify CI,
- adapter-remote workflow template.

It would be straightforward to add matrix expansions, packaging validation, or docs validation once the project wants them.

---

## Terminology

This glossary is grounded in terms used in the repo itself.

### Agent

A named specialist persona with:

- a canonical `agent.md`,
- settings,
- memory and portfolio conventions,
- and expected communication discipline.

### Bridge

Both:

- a specific agent,
- and the default routing identity in several adapter contexts.

### Scout

The T0 baseline agent. Lightweight, triage-oriented, intended as a snap-back or default low-cost lane in older tier tooling.

### Roster

The set of named agents shipped in the repo.

### Inbox protocol

The repeated rule that agents should run:

```text
tritium inbox check --agent <name>
```

at defined checkpoints.

### IM

Short-form runtime message, optionally threaded.

### Email

Longer-form runtime message with subject/body and optional attachments.

### Message bus

The SQLite-backed runtime storage layer for messages, receipts, and agent state.

### Timeline

Merged view of recent IM and email in the dashboard/runtime API.

### Handoff

Formal transfer of work or state between agents, represented both conceptually in team docs and structurally in `runtime/schemas/handoff.json`.

### Portfolio

An agent's working draft space. Not canonical until promoted.

### Memory

Persistent or semi-persistent notes scoped by repo, session, or personal preference.

### Dry run

A mode where adapters print or prepare payloads without actually calling a paid model endpoint.

### World

The social, location, and in-world identity layer that sits beside the product code.

### Heartbeat

The Python service that can autonomously generate world activity through LM Studio and email, distinct from the Node runtime server.

### Preflight

The runtime dependency check in `runtime/server/src/preflight.js`.

### Verify

The repo-wide environment and structure check in `scripts/verify.*`, plus runtime smoke checks in `runtime/server/src/verify.js`.

### Package

The zip-and-checksum release artifact flow in `scripts/package.*`.

### Tier

A legacy or historical operating model still visible in `data/registry/models.json` and `scripts/tier-auto`, where Scout is T0, Bridge is T1, specialists are higher tiers, and snap-back returns to baseline.

### Snap-back

The idea, from older tier tooling, that work should return to Scout/T0 after higher-tier sessions.

### Proposed prompt edits

Bridge watchdog artifacts suggesting patches to sub-agent prompts, stored under `agents/bridge/proposed-prompt-edits/`.

---

## Practical mental model

If you are coming to the repo fresh and want to operate it effectively without getting lost in the older layers, use this model:

### For normal use

1. Read `README.md`.
2. Copy `SETTINGS.example.jsonc` to `SETTINGS.jsonc` if needed.
3. Run `bash scripts/install.sh`.
4. Run `cd runtime/server && npm ci && npm run doctor`.
5. Start the runtime with `tritium serve`.
6. Use the dashboard at `http://localhost:7330`.
7. Install the adapter you actually want into the target repo.

### For understanding the team model

Read:

- `AGENTS.md`
- `agents/<name>/agent.md`
- `world/social/team/TEAM.md`

### For understanding runtime internals

Read:

- `docs/architecture.md`
- `runtime/server/src/index.js`
- `runtime/server/src/api.js`
- `runtime/server/src/db.js`
- `runtime/cli/tritium.js`

### For understanding operational risks

Read:

- `docs/troubleshooting.md`
- `runtime/server/src/preflight.js`
- `CHANGELOG.md`

### For understanding the broader historical layer

Read:

- `docs/ARCHITECTURE-v4.md`
- `docs/ARCHITECTURE-v4.1.md`
- `docs/SECURITY-tritium-crypt.md`
- `runtime/heartbeat/README.md`
- older utility scripts in `scripts/`

### For understanding the repo honestly

Hold both truths at once:

1. Tritium already has a real current runtime, CLI, dashboard, roster, adapter system, and packaging flow.
2. Tritium also still carries older structures and partially migrated tooling that reveal where the project came from and where it is still being unified.

That is the correct reading of this repository.

---

## Detailed component walkthrough

The earlier sections described the system by category. This section walks it more like a working stack, from entrypoint to deeper subsystems.

### README as the public contract

The README is more than a marketing page. It is the clearest concise contract for current intended use.

It promises:

- nine agents,
- local runtime,
- dashboard on port 7330,
- CLI,
- SQLite message bus,
- drop-in adapters,
- install/verify/package scripts,
- and a world snapshot.

A lot of the rest of the repo does, in fact, support that promise.

### `runtime/server/package.json` as the runtime package contract

This file tells you the runtime is intended to be:

- a Node package,
- private,
- executable through the `bin` field,
- versioned,
- dependency-light.

This is important because it means the runtime is the most productized software layer in the repo.

### `runtime/server/src/settings.js` as normalization glue

This file quietly does a lot of heavy lifting:

- parses JSONC,
- merges defaults,
- materializes a current roster,
- handles missing per-agent config,
- and allows extra custom agents.

That makes settings resilient rather than brittle.

### `runtime/server/src/db.js` as persistence foundation

The DB file is similarly modest but important:

- creates tables,
- seeds agent rows,
- and makes persistence automatic.

There is no separate migration framework. That is a fine tradeoff for the current scale.

### `runtime/server/src/api.js` as behavioral core

This is where the runtime becomes a coordination system rather than just a static dashboard:

- send IM,
- list IM,
- unread IM,
- mark read,
- send email,
- list email,
- list agents,
- update heartbeat,
- build timeline.

It is also where payload clipping and string validation live.

### `runtime/server/src/index.js` as transport shell

This file ties everything together:

- HTTP,
- JSON body parsing,
- static file serving,
- route handling,
- WebSocket broadcast,
- graceful shutdown.

It is deliberately small enough that a reader can understand it in one sitting.

### `runtime/dashboard/` as the human-facing ops panel

The dashboard is not a gimmick. It is the visible part of the runtime and lets users:

- inspect messages,
- inspect agent state,
- test IM/email manually,
- and see the system live.

### `runtime/cli/tritium.js` as shell-friendly control surface

The CLI matters because many adapters and agent prompts instruct agents to use it. It is the bridge between:

- agent conventions,
- live runtime,
- and file-based fallback behavior.

### `runtime/schemas/` as structural clarity

The schemas are not currently enforced end-to-end across every path in the repo, but they still matter because they formalize the project's key object shapes.

### `agents/` as the social-operational layer

This is where Tritium distinguishes itself from "just another runtime." The system is built around named people-like roles with:

- responsibilities,
- ownership limits,
- communication rules,
- memory rules,
- and workflow expectations.

### `adapters/` as the portability layer

Without adapters, the agents would only live inside the Tritium repo. Adapters are what let the same crew model travel into other repos and other tools.

### `world/` as context and culture layer

The world layer gives the system texture, but also fallback communication and durable coordination files.

### `runtime/heartbeat/` as the "alive while offline" layer

Even though it is path-drifted, it shows the repo's broader vision: agents are not only invoked on demand; they can also create periodic world activity, receive mail, and maintain contextual continuity.

---

## File and directory walkthrough by area

This section goes one level deeper and catalogs the repo area by area.

### Root files

#### `README.md`

Primary current guide for:

- what Tritium is,
- quickstart,
- install,
- runtime startup,
- verify,
- adapter install,
- settings,
- docs index.

#### `AGENTS.md`

Compact current roster reference. Useful for orientation.

#### `CHANGELOG.md`

Very important for understanding:

- current unification work,
- historical v4 and v4.1 layers,
- what is intentionally changing,
- what is still future-facing.

#### `SETTINGS.example.jsonc`

Best current human-readable settings template.

### `runtime/`

#### `runtime/cli/`

Holds the main CLI entrypoint.

#### `runtime/dashboard/`

The static SPA for local visibility and manual interaction.

#### `runtime/heartbeat/`

Python service, env-driven, partially legacy in path assumptions.

#### `runtime/schemas/`

JSON Schemas for the main configuration and message objects.

#### `runtime/server/`

The active runtime implementation.

### `scripts/`

This directory is both highly useful and slightly deceptive because it contains mixed generations of tooling.

The safest way to read it is:

- installers and verify/package/new-agent are current,
- launcher scripts are current support tools,
- crypto/tier/doctor scripts are useful but require path-awareness.

### `adapters/`

Each adapter directory is its own installable payload.

#### `adapters/claude-cli/`

Contains:

- `README.md`
- `CLAUDE.md`
- `agents/<name>.md`

#### `adapters/gemini-cli/`

Contains:

- `README.md`
- `GEMINI.md`
- `.gemini/settings.json`
- `agents/<name>.md`

#### `adapters/github-copilot-local/`

Contains:

- `README.md`
- `.github/copilot-instructions.md`
- `.github/TEAM.md`
- `.github/agents/`
- `.github/portfolios/`
- `.github/team/`

#### `adapters/github-copilot-remote/`

Contains:

- `README.md`
- `.github/CODEOWNERS`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/`
- `.github/dependabot.yml`
- `.github/labels.md`
- `.github/workflows/tritium-verify.yml`

#### `adapters/openai-lmstudio/`

Contains the only adapter that is also executable code rather than pure file payload.

### `world/`

The world directory is easiest to read as:

- social channels,
- place descriptions,
- team operating map,
- vault store.

### `data/registry/`

Contains:

- `models.json`
- `credits.ledger`

This layer still reflects a six-agent tier model rather than the current runtime's nine-agent roster, which is another important repo fact.

---

## Data and registry layer

`data/registry/models.json` and `credits.ledger` deserve special mention because they reveal an earlier or parallel operational model.

### `models.json`

This file defines:

- `scout` as T0,
- `bridge` as T1,
- `sol`, `vex`, `jesse` as T2,
- `rook` as T3,

with:

- tier labels,
- cost classes,
- escalation targets,
- snap-back semantics.

Notably absent from this registry:

- Robert
- Lux
- Nova

That means this registry does not match the current nine-agent runtime roster.

### `credits.ledger`

This file is an append-only budget ledger with token-oriented fields. It tracks:

- agent,
- tier,
- cost class,
- budget tokens,
- spent tokens,
- remaining.

The current file is a zero-balance placeholder baseline rather than an actively populated spend ledger.

### Practical interpretation

The registry layer appears to preserve a historical or still-incomplete "tiered agent economy" model. It remains useful for understanding the project's broader design history, but it is not the canonical current roster source.

---

## Security and vault layer

The repo includes a substantial security/vault subsystem centered on `tritium-crypt`.

### Security docs

Primary doc:

```text
docs/SECURITY-tritium-crypt.md
```

It specifies:

- AES-256-GCM for payload encryption,
- X25519 + HKDF for key wrapping,
- Ed25519 for manifest signing,
- hardware-bound keys in `~/.tritium-os/keys/`,
- no plaintext in repo,
- explicit gitignore boundaries.

### Current normalized vault path

The normalized repo contains:

```text
world/vault/
  manifest.json
```

### Utility scripts

Relevant scripts:

- `scripts/tritium-crypt`
- `scripts/tritium-open`
- `scripts/tritium-close`
- `scripts/tritium-doctor`

### Key caveat

These scripts still default to older paths like:

- `world_vault`
- `registry/models.json`

instead of:

- `world/vault`
- `data/registry/models.json`

So the security design is real and carefully thought out, but the path glue needs normalization if this layer is meant to be fully current.

### Why it still matters

Even with drift, the vault subsystem tells you Tritium was designed with a serious local-security mindset:

- shared storage is treated as hostile,
- crypto should not silently degrade,
- plaintext mirrors are ephemeral and gitignored,
- signatures and hash checks matter.

That is an unusually concrete security stance for a repo in this category.

---

## Workflow examples

The best way to understand how Tritium is meant to be used is to walk through a few concrete workflows.

### Workflow: first-time local setup

1. Clone repo.
2. Run `bash scripts/install.sh`.
3. Inspect summary output.
4. Run `cd runtime/server && npm ci`.
5. Run `npm run doctor`.
6. Start runtime with `tritium serve`.
7. Open `http://localhost:7330`.
8. Run `bash scripts/verify.sh`.

### Workflow: install Tritium into another repo for Claude CLI

1. In this Tritium repo, run:

   ```bash
   bash scripts/install-adapter.sh --target /path/to/other-repo --adapter claude-cli
   ```

2. The other repo gets:
   - `CLAUDE.md`
   - `agents/*.md`

3. In that other repo, Claude CLI can act as Bridge by default or switch to named specialists.

### Workflow: send a manual IM

1. Start runtime.
2. Use dashboard IM tab or:

   ```bash
   tritium send-im --from you --to sol --body "Please check the latest verify failure."
   ```

3. Recipient agent sees it through live API or mailbox fallback logic depending on environment.

### Workflow: check inbox honestly

If you want to know whether the runtime is really up:

```bash
tritium inbox check --agent sol --require-api
```

If the runtime is down, this fails instead of quietly showing file mailboxes.

### Workflow: package a release snapshot

1. Ensure changelog and current files are correct.
2. Run:

   ```bash
   bash scripts/package.sh
   ```

3. Inspect:
   - `dist/tritium-v0.1.0.zip`
   - `dist/tritium-v0.1.0.zip.sha256`

### Workflow: scaffold a new agent

1. Run:

   ```bash
   bash scripts/new-agent.sh orbit "Operations analyst"
   ```

2. Edit the generated `agents/orbit/agent.md`.
3. Tune settings.
4. Update handoff matrix details in `world/social/team/TEAM.md`.
5. Install adapter payloads into target repos if needed.

### Workflow: run the heartbeat manually

If you are working with the external world-tree and mail setup:

```powershell
python -m pip install --user -r runtime/heartbeat/requirements.txt
Copy-Item runtime/heartbeat/.env.example runtime/heartbeat/.env
python -m tritium_bridge --check
python -m tritium_bridge --tick --dry-run --agent Bridge --action journal
```

But remember: this workflow belongs to the older/external world-tree model, not the normalized repo snapshot alone.

---

## Practical caveats by subsystem

Sometimes the most useful thing is not a generic "limitations" list but subsystem-specific warnings.

### Runtime caveats

- Needs Node 20+.
- Needs `npm ci` in `runtime/server/`.
- Can fail on shared storage paths.
- Has no auth if tunneled.
- Settings editing is read-only in UI.
- `run-agent` is not fully implemented.

### CLI caveats

- Most commands require the runtime to be running.
- `inbox check` falls back unless `--require-api` is used.
- Launcher depends on install state or explicit repo root.

### Adapter caveats

- Adapters install files, not a universal execution layer.
- Some adapter docs still use older path examples.
- Some adapter overview text still says eight-member crew.
- OpenAI-compatible runner defaults to dry run and requires env vars for actual calls.

### World caveats

- Snapshot only, not live source of truth.
- Some world docs still describe older layouts or eight-member models.
- It is useful context, but not required for runtime operation.

### Heartbeat caveats

- Depends on external world tree and env credentials.
- Uses older bracketed path assumptions.
- Uses a five-"real-agent" subset in some grounding logic.

### Legacy utility caveats

- Path drift versus normalized repo layout.
- Some scripts still look for `world_vault` and `registry/`.
- Some workbook docs carry over language from another product context.

---

## How the pieces reinforce each other

One reason Tritium feels coherent despite its transitional seams is that several layers reinforce the same underlying ideas.

### Roles reinforce runtime behavior

The runtime's `agents` view would be much less useful if agents were only vague names. Instead, roles are concrete enough that:

- the dashboard can show meaningful stats,
- inbox checks make sense,
- adapter switching has purpose,
- and team handoffs have structure.

### Settings reinforce agent discipline

Because settings include:

- independence,
- verbosity,
- inbox cadence,
- memory quotas,
- portfolio limits,

the system can encode behavior expectations without hardcoding all behavior in prose alone.

### Adapters reinforce portability

Because agent definitions live in files and adapters copy prompt material into target environments, Tritium can travel.

### Scripts reinforce operability

Because install, verify, and package flows exist as concrete scripts, the project is not just conceptual. It is deployable and checkable.

### World reinforces continuity

Because world files store:

- notes,
- locations,
- ship logs,
- DM threads,
- handoffs,

the named-agent model has continuity that survives beyond a single session.

### Changelog reinforces migration honesty

Because the changelog explicitly describes repo flattening and unification phases, readers can understand why some subsystems still reflect older layouts.

---

## What a contributor should read first

Different contributors need different entry points.

### If you want to use Tritium as a tool

Read:

1. `README.md`
2. `docs/troubleshooting.md`
3. adapter usage doc for your tool

### If you want to modify the runtime

Read:

1. `docs/architecture.md`
2. `runtime/server/src/index.js`
3. `runtime/server/src/api.js`
4. `runtime/server/src/db.js`
5. `runtime/cli/tritium.js`
6. `runtime/server/src/verify.js`

### If you want to understand the team model

Read:

1. `AGENTS.md`
2. `agents/bridge/agent.md`
3. `world/social/team/TEAM.md`
4. one specialist file such as `agents/sol/agent.md` or `agents/vex/agent.md`

### If you want to understand drift and history

Read:

1. `CHANGELOG.md`
2. `docs/ARCHITECTURE-v4.md`
3. `docs/ARCHITECTURE-v4.1.md`
4. `runtime/heartbeat/README.md`
5. `scripts/tritium-doctor`

### If you want to understand security posture

Read:

1. `docs/SECURITY-tritium-crypt.md`
2. `world/vault/README.md`
3. `scripts/tritium-crypt`

---

## Summary tables

### Major components summary

| Component | Current role | Health/readiness impression |
|---|---|---|
| Node runtime | Local API, DB, dashboard, live coordination | Strong and current |
| CLI | Runtime control and inbox access | Strong and current, except `run-agent` stub |
| Dashboard | Manual inspection and message UI | Strong and current |
| Agent definitions | Canonical role definitions | Strong and current |
| Settings | Central behavior controls | Strong, small drift around Scout |
| Schemas | IM/email/settings/handoff structure | Current and useful |
| Install/verify/package scripts | Bootstrap and quality gates | Strong and current |
| Adapters | Portability into host tools | Current, with some text drift |
| World snapshot | Social and context layer | Useful, intentionally non-authoritative |
| Heartbeat | Autonomous world activity service | Real but path-drifted and external-world dependent |
| Registry/tier tooling | Tier/cost history and utility layer | Legacy or transitional |
| Vault/security tooling | Encrypted payload subsystem | Thoughtful but path normalization incomplete |

### High-confidence current truths

| Statement | Supported by |
|---|---|
| Runtime is local-only by default | `docs/architecture.md`, `index.js`, troubleshooting |
| Dashboard default port is 7330 | settings docs, README, runtime code |
| Runtime uses SQLite + better-sqlite3 | architecture doc, package.json, db.js |
| There are nine current agent dirs in `agents/` | repo tree, `AGENTS.md`, README |
| Verify requires live runtime for inbox smoke test | verify scripts, changelog |
| Adapters default to dry-run or no-spend patterns | settings docs, OpenAI runner, README |
| Shared storage can break runtime install | README, preflight, troubleshooting, install script |

### High-confidence drift points

| Drift point | Evidence |
|---|---|
| Scout missing from settings template | `SETTINGS.example.jsonc` vs runtime roster |
| Eight-member wording still exists in some adapter docs | `CLAUDE.md`, `GEMINI.md` |
| World snapshot describes five working agents plus three recurring characters | `world/README.md` |
| Heartbeat still uses bracketed old world paths | `runtime/heartbeat/tritium_bridge/config.py` |
| Legacy utility scripts still point to `world_vault` and `registry/` | `tritium-crypt`, `tritium-doctor`, `tier-auto` |
| Rook release checklist still references `DesktopPal` | `agents/rook/identity/workbook/release-readiness-checklist.md` |

---

## Closing summary

Tritium OS, as this repo currently stands, is a real and fairly sophisticated local-first multi-agent coordination project with four especially strong pillars:

1. **A current Node runtime** for messages, dashboard, and agent visibility.
2. **A structured agent system** with explicit roles, memory/portfolio discipline, and inbox conventions.
3. **Portable adapters** that let the same crew model plug into several AI environments.
4. **A file-backed world and social layer** that gives the team continuity and visible coordination artifacts.

Its biggest current strengths are clarity and inspectability:

- small runtime,
- understandable code,
- concrete scripts,
- visible files,
- explicit conventions,
- honest docs about local-only behavior and current gaps.

Its biggest current constraints are not conceptual; they are unification-related:

- older utility and heartbeat layers still assume pre-flattening paths,
- some docs and roster descriptions lag the current nine-agent model,
- and the generic agent-runner story inside the CLI is still a stub.

None of those erase the core shape of the project. They just mean Tritium is best understood as a repo that already has a strong current runtime and workflow layer while still carrying a meaningful older OS-style lineage beside it.

If you remember only one sentence, make it this:

> Tritium is a local-first, file-visible, role-driven coordination layer whose current center of gravity is the Node runtime plus agent/adapter system, with a still-present but partially legacy heartbeat and vault lineage around it.

