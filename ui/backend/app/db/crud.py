"""CRUD operations for the template registry database."""
from datetime import datetime, timezone
from typing import Optional

import aiosqlite

from .models import (
    FileHash,
    FileHashCreate,
    Template,
    TemplateCreate,
    TemplateUpdate,
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _row_to_template(row: aiosqlite.Row) -> Template:
    return Template(
        id=row["id"],
        name=row["name"],
        repo_url=row["repo_url"],
        repo_path=row["repo_path"],
        branch=row["branch"],
        tfvars_ui=row["tfvars_ui"],
        snapshot_date=row["snapshot_date"],
        created_date=row["created_date"],
        updated_date=row["updated_date"],
    )


def _row_to_file_hash(row: aiosqlite.Row) -> FileHash:
    return FileHash(
        id=row["id"],
        template_id=row["template_id"],
        filename=row["filename"],
        hash=row["hash"],
        hard_stop=bool(row["hard_stop"]),
    )


# ── TemplateDB ─────────────────────────────────────────────


class TemplateDB:
    """CRUD operations for the templates table."""

    def __init__(self, db: aiosqlite.Connection):
        self.db = db

    async def create(self, data: TemplateCreate) -> Template:
        now = _now()
        snapshot = data.snapshot_date.isoformat() if data.snapshot_date else None
        cursor = await self.db.execute(
            """
            INSERT INTO templates
                (name, repo_url, repo_path, branch, tfvars_ui, snapshot_date, created_date, updated_date)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                data.name,
                data.repo_url,
                data.repo_path,
                data.branch,
                data.tfvars_ui,
                snapshot,
                now,
                now,
            ),
        )
        await self.db.commit()
        return await self.get(cursor.lastrowid)  # type: ignore[arg-type]

    async def get(self, template_id: int) -> Optional[Template]:
        cursor = await self.db.execute(
            "SELECT * FROM templates WHERE id = ?", (template_id,)
        )
        row = await cursor.fetchone()
        return _row_to_template(row) if row else None

    async def get_by_name(self, name: str) -> Optional[Template]:
        cursor = await self.db.execute(
            "SELECT * FROM templates WHERE name = ?", (name,)
        )
        row = await cursor.fetchone()
        return _row_to_template(row) if row else None

    async def list(self) -> list[Template]:
        cursor = await self.db.execute("SELECT * FROM templates ORDER BY name")
        rows = await cursor.fetchall()
        return [_row_to_template(r) for r in rows]

    async def update(self, template_id: int, data: TemplateUpdate) -> Optional[Template]:
        existing = await self.get(template_id)
        if existing is None:
            return None

        updates = data.model_dump(exclude_unset=True)
        if not updates:
            return existing

        # Convert snapshot_date to ISO string
        if "snapshot_date" in updates and updates["snapshot_date"] is not None:
            updates["snapshot_date"] = updates["snapshot_date"].isoformat()

        updates["updated_date"] = _now()

        set_clause = ", ".join(f"{k} = ?" for k in updates)
        values = list(updates.values()) + [template_id]

        await self.db.execute(
            f"UPDATE templates SET {set_clause} WHERE id = ?",  # noqa: S608
            values,
        )
        await self.db.commit()
        return await self.get(template_id)

    async def delete(self, template_id: int) -> bool:
        cursor = await self.db.execute(
            "DELETE FROM templates WHERE id = ?", (template_id,)
        )
        await self.db.commit()
        return cursor.rowcount > 0


# ── FileHashDB ─────────────────────────────────────────────


class FileHashDB:
    """CRUD operations for the file_hashes table."""

    def __init__(self, db: aiosqlite.Connection):
        self.db = db

    async def create(self, data: FileHashCreate) -> FileHash:
        cursor = await self.db.execute(
            """
            INSERT INTO file_hashes (template_id, filename, hash, hard_stop)
            VALUES (?, ?, ?, ?)
            """,
            (data.template_id, data.filename, data.hash, int(data.hard_stop)),
        )
        await self.db.commit()
        return await self.get(cursor.lastrowid)  # type: ignore[arg-type]

    async def get(self, file_hash_id: int) -> Optional[FileHash]:
        cursor = await self.db.execute(
            "SELECT * FROM file_hashes WHERE id = ?", (file_hash_id,)
        )
        row = await cursor.fetchone()
        return _row_to_file_hash(row) if row else None

    async def get_by_template(self, template_id: int) -> list[FileHash]:
        cursor = await self.db.execute(
            "SELECT * FROM file_hashes WHERE template_id = ? ORDER BY filename",
            (template_id,),
        )
        rows = await cursor.fetchall()
        return [_row_to_file_hash(r) for r in rows]

    async def bulk_insert(self, items: list[FileHashCreate]) -> list[FileHash]:
        if not items:
            return []
        await self.db.executemany(
            """
            INSERT INTO file_hashes (template_id, filename, hash, hard_stop)
            VALUES (?, ?, ?, ?)
            """,
            [(i.template_id, i.filename, i.hash, int(i.hard_stop)) for i in items],
        )
        await self.db.commit()
        # Return all hashes for the template (assumes single template per bulk op)
        return await self.get_by_template(items[0].template_id)

    async def bulk_replace(self, template_id: int, items: list[FileHashCreate]) -> list[FileHash]:
        """Delete all existing hashes for a template, then bulk-insert new ones."""
        await self.db.execute(
            "DELETE FROM file_hashes WHERE template_id = ?", (template_id,)
        )
        if not items:
            await self.db.commit()
            return []
        await self.db.executemany(
            """
            INSERT INTO file_hashes (template_id, filename, hash, hard_stop)
            VALUES (?, ?, ?, ?)
            """,
            [(i.template_id, i.filename, i.hash, int(i.hard_stop)) for i in items],
        )
        await self.db.commit()
        return await self.get_by_template(template_id)

    async def delete(self, file_hash_id: int) -> bool:
        cursor = await self.db.execute(
            "DELETE FROM file_hashes WHERE id = ?", (file_hash_id,)
        )
        await self.db.commit()
        return cursor.rowcount > 0
