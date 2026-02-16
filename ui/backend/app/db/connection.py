"""SQLite connection management and schema initialisation."""
import logging
from pathlib import Path

import aiosqlite

logger = logging.getLogger(__name__)

SCHEMA_VERSION = 1

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS _meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS templates (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    name           TEXT    NOT NULL UNIQUE,
    repo_url       TEXT    NOT NULL,
    repo_path      TEXT    NOT NULL DEFAULT '',
    branch         TEXT    NOT NULL DEFAULT 'main',
    tfvars_ui      TEXT    NOT NULL DEFAULT 'terraform.tfvars.example',
    snapshot_date  TEXT,
    created_date   TEXT    NOT NULL,
    updated_date   TEXT    NOT NULL
);

CREATE TABLE IF NOT EXISTS file_hashes (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id  INTEGER NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    filename     TEXT    NOT NULL,
    hash         TEXT    NOT NULL,
    hard_stop    INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_file_hashes_template_id ON file_hashes(template_id);
"""

# Module-level connection holder
_db: aiosqlite.Connection | None = None


async def init_db(db_path: Path) -> aiosqlite.Connection:
    """Open (or create) the database, apply schema, and return the connection."""
    global _db  # noqa: PLW0603

    db_path.parent.mkdir(parents=True, exist_ok=True)

    _db = await aiosqlite.connect(str(db_path))
    _db.row_factory = aiosqlite.Row

    # Enable WAL mode and foreign keys
    await _db.execute("PRAGMA journal_mode=WAL")
    await _db.execute("PRAGMA foreign_keys=ON")

    # Apply schema
    await _db.executescript(SCHEMA_SQL)

    # Stamp schema version if missing
    cursor = await _db.execute("SELECT value FROM _meta WHERE key = 'schema_version'")
    row = await cursor.fetchone()
    if row is None:
        await _db.execute(
            "INSERT INTO _meta (key, value) VALUES ('schema_version', ?)",
            (str(SCHEMA_VERSION),),
        )
        await _db.commit()

    logger.info("Database ready at %s (schema v%s)", db_path, SCHEMA_VERSION)
    return _db


def get_db() -> aiosqlite.Connection:
    """Return the current database connection (must call init_db first)."""
    if _db is None:
        raise RuntimeError("Database not initialised — call init_db() first")
    return _db


async def close_db() -> None:
    """Close the database connection."""
    global _db  # noqa: PLW0603
    if _db is not None:
        await _db.close()
        _db = None
        logger.info("Database connection closed")
