-- Tritium Team v4.0 -- Ledger schema
-- Applied by setup.sh and Ledger._ensure_schema() as fallback.

CREATE TABLE IF NOT EXISTS events (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    ts         TEXT    NOT NULL DEFAULT(strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    kind       TEXT    NOT NULL,
    agent      TEXT,
    payload    TEXT
);

CREATE INDEX IF NOT EXISTS idx_events_kind ON events(kind);
CREATE INDEX IF NOT EXISTS idx_events_ts   ON events(ts);

CREATE TABLE IF NOT EXISTS kv (
    key        TEXT PRIMARY KEY,
    value      TEXT,
    updated_at TEXT DEFAULT(strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);
