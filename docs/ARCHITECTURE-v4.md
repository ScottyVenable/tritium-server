# Architecture -- Tritium Team v4.0 (Genesis)

## Overview

Tritium Team v4.0 "Genesis" establishes the foundational runtime for a
multi-agent AI operating environment designed for Android (Termux) and Linux.

## Components

### tritium-bridge

Python package at `bridge/tritium_bridge/`. Handles:
- Agent persona management (`personas.py`)
- Context window management (`context.py`)
- LM Studio integration (`lmstudio.py`)
- Action dispatch (`actions.py`)
- File drop ingestion (`filedrop.py`)
- Scheduled tasks (`scheduler.py`)
- World context (`worldcontext.py`)
- Ledger facade (`ledger.py`) -- v4.0 addition

### Scripts

Core CLI tools at `scripts/`:
- `install.sh` / `install.ps1` -- dependency installer
- `verify.sh` / `verify.ps1`   -- environment verifier
- `new-agent.sh` / `new-agent.ps1` -- agent scaffold generator
- `package.sh` / `package.ps1` -- release packager

### Mobile environment

`mobile-environment/configs/bashrc.sh` -- Termux shell integration.
Sets TRITIUM_HOME, adds bin to PATH, provides aliases, shield check,
and welcome banner.

### Registry

`data/registry/models.json` -- single source of truth for agent-tier-model
assignments, tier-auto configuration, and snap-back baseline.

`data/registry/credits.ledger` -- append-only AI credit monitoring log.

### Ledger

SQLite database at `~/.tritium-team/ledger/ledger.db`.
Schema at `data/ledger.schema.sql`.
Facade at `bridge/tritium_bridge/ledger.py`.

## Setup flow

1. Clone repo
2. Run `bash scripts/setup.sh`
3. Run `tritium-doctor` to verify
4. Source `mobile-environment/configs/bashrc.sh`

## Design principles

- Idempotent setup
- Android shared storage safe (no POSIX chmod in repo paths)
- No emojis in code or data
- Named constants, no magic strings
- Mobile-first responsive design
