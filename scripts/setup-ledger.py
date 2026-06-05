#!/usr/bin/env python3
"""Initialize Tritium Team ledger database. Called by setup.sh."""
import sys, sqlite3
from pathlib import Path

db_path = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / ".tritium-team" / "ledger" / "ledger.db")
Path(db_path).parent.mkdir(parents=True, exist_ok=True)
with sqlite3.connect(db_path) as cx:
    cx.execute("""CREATE TABLE IF NOT EXISTS events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts TEXT NOT NULL DEFAULT(strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
        kind TEXT NOT NULL,
        agent TEXT,
        payload TEXT
    )""")
    cx.execute("""CREATE TABLE IF NOT EXISTS kv (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT DEFAULT(strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
    )""")
    cx.commit()
print(f'[ OK ] Ledger DB ready: {db_path}')
