#!/usr/bin/env python3
"""Tritium Team v4.0 -- Ledger facade (SQLite).

Provides append-only event logging and key-value state storage
for the tritium-bridge and associated CLI tools.

Schema lives in data/ledger.schema.sql.
"""
from __future__ import annotations
import json, sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


_DEFAULT_DB = Path.home() / ".tritium-team" / "ledger" / "ledger.db"


class Ledger:
    """Lightweight SQLite ledger facade."""

    def __init__(self, db_path: str | Path | None = None) -> None:
        self._path = Path(db_path) if db_path else _DEFAULT_DB
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._ensure_schema()

    # ---- public API -------------------------------------------------------

    def log_event(
        self,
        *,
        kind: str,
        agent: str | None = None,
        payload: dict[str, Any] | None = None,
    ) -> int:
        """Append an event. Returns the inserted row id."""
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        payload_json = json.dumps(payload or {})
        with self._connect() as cx:
            cur = cx.execute(
                "INSERT INTO events (ts, kind, agent, payload) VALUES (?, ?, ?, ?)",
                (ts, kind, agent, payload_json),
            )
            return cur.lastrowid  # type: ignore[return-value]

    def remember(self, key: str, value: Any) -> None:
        """Upsert a key-value pair."""
        ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        with self._connect() as cx:
            cx.execute(
                "INSERT INTO kv (key, value, updated_at) VALUES (?, ?, ?)"
                " ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at",
                (key, json.dumps(value), ts),
            )

    def recall(self, key: str, default: Any = None) -> Any:
        """Retrieve a value by key."""
        with self._connect() as cx:
            row = cx.execute("SELECT value FROM kv WHERE key = ?", (key,)).fetchone()
        if row is None:
            return default
        try:
            return json.loads(row[0])
        except (json.JSONDecodeError, TypeError):
            return row[0]

    def recent_events(self, limit: int = 20, kind: str | None = None) -> list[dict]:
        """Return recent events as list of dicts."""
        with self._connect() as cx:
            if kind:
                rows = cx.execute(
                    "SELECT ts, kind, agent, payload FROM events WHERE kind=? ORDER BY id DESC LIMIT ?",
                    (kind, limit),
                ).fetchall()
            else:
                rows = cx.execute(
                    "SELECT ts, kind, agent, payload FROM events ORDER BY id DESC LIMIT ?",
                    (limit,),
                ).fetchall()
        return [
            {"ts": r[0], "kind": r[1], "agent": r[2], "payload": _safe_json(r[3])}
            for r in rows
        ]

    def get_state(self, key: str, default: Any = None) -> Any:
        """Alias for recall()."""
        return self.recall(key, default)

    def set_state(self, key: str, value: Any) -> None:
        """Alias for remember()."""
        self.remember(key, value)

    def summary(self) -> dict:
        """Return high-level stats."""
        with self._connect() as cx:
            total = cx.execute("SELECT COUNT(*) FROM events").fetchone()[0]
            kinds = cx.execute(
                "SELECT kind, COUNT(*) FROM events GROUP BY kind ORDER BY COUNT(*) DESC"
            ).fetchall()
            kv_count = cx.execute("SELECT COUNT(*) FROM kv").fetchone()[0]
        return {
            "total_events": total,
            "kv_keys": kv_count,
            "event_kinds": {k: v for k, v in kinds},
        }

    # ---- private ----------------------------------------------------------

    def _connect(self):
        cx = sqlite3.connect(str(self._path))
        cx.row_factory = sqlite3.Row
        return cx

    def _ensure_schema(self):
        schema_path = Path(__file__).resolve().parent.parent.parent / "data" / "ledger.schema.sql"
        with self._connect() as cx:
            if schema_path.exists():
                cx.executescript(schema_path.read_text())
            else:
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


def _safe_json(s: str | None) -> Any:
    if not s:
        return {}
    try:
        return json.loads(s)
    except (json.JSONDecodeError, TypeError):
        return s
