"""Unit tests for the template registry database layer."""
import pytest
from pathlib import Path

from app.db.connection import init_db, close_db, SCHEMA_VERSION
from app.db.crud import TemplateDB, FileHashDB
from app.db.models import TemplateCreate, TemplateUpdate, FileHashCreate


@pytest.fixture
async def db(tmp_path: Path):
    """Create a fresh in-memory-like database for each test."""
    db_path = tmp_path / "test.db"
    conn = await init_db(db_path)
    yield conn
    await close_db()


@pytest.fixture
def templates(db):
    return TemplateDB(db)


@pytest.fixture
def file_hashes(db):
    return FileHashDB(db)


# ── Schema ─────────────────────────────────────────────────


async def test_schema_version(db):
    cursor = await db.execute("SELECT value FROM _meta WHERE key = 'schema_version'")
    row = await cursor.fetchone()
    assert row is not None
    assert row["value"] == str(SCHEMA_VERSION)


# ── Template CRUD ──────────────────────────────────────────


async def test_create_template(templates: TemplateDB):
    t = await templates.create(
        TemplateCreate(
            name="aws/existing_vpc_resources",
            repo_url="https://github.com/example/repo.git",
            repo_path="terraform/aws/existing_vpc_resources",
        )
    )
    assert t.id == 1
    assert t.name == "aws/existing_vpc_resources"
    assert t.branch == "main"
    assert t.created_date is not None


async def test_get_template(templates: TemplateDB):
    created = await templates.create(
        TemplateCreate(name="tpl-get", repo_url="https://example.com/repo.git")
    )
    fetched = await templates.get(created.id)
    assert fetched is not None
    assert fetched.name == "tpl-get"


async def test_get_template_nonexistent(templates: TemplateDB):
    assert await templates.get(9999) is None


async def test_get_by_name(templates: TemplateDB):
    await templates.create(
        TemplateCreate(name="find-me", repo_url="https://example.com/repo.git")
    )
    found = await templates.get_by_name("find-me")
    assert found is not None
    assert found.name == "find-me"

    assert await templates.get_by_name("not-here") is None


async def test_list_empty(templates: TemplateDB):
    result = await templates.list()
    assert result == []


async def test_list_multiple(templates: TemplateDB):
    await templates.create(
        TemplateCreate(name="b-template", repo_url="https://example.com/b.git")
    )
    await templates.create(
        TemplateCreate(name="a-template", repo_url="https://example.com/a.git")
    )
    result = await templates.list()
    assert len(result) == 2
    # Ordered by name
    assert result[0].name == "a-template"
    assert result[1].name == "b-template"


async def test_update_partial(templates: TemplateDB):
    created = await templates.create(
        TemplateCreate(name="update-me", repo_url="https://example.com/old.git")
    )
    updated = await templates.update(
        created.id, TemplateUpdate(repo_url="https://example.com/new.git")
    )
    assert updated is not None
    assert updated.repo_url == "https://example.com/new.git"
    assert updated.name == "update-me"  # unchanged
    assert updated.updated_date > created.updated_date


async def test_update_nonexistent(templates: TemplateDB):
    result = await templates.update(
        9999, TemplateUpdate(name="ghost")
    )
    assert result is None


async def test_delete_template(templates: TemplateDB):
    created = await templates.create(
        TemplateCreate(name="delete-me", repo_url="https://example.com/repo.git")
    )
    assert await templates.delete(created.id) is True
    assert await templates.get(created.id) is None


async def test_delete_nonexistent(templates: TemplateDB):
    assert await templates.delete(9999) is False


# ── FileHash CRUD ──────────────────────────────────────────


async def test_create_file_hash(templates: TemplateDB, file_hashes: FileHashDB):
    t = await templates.create(
        TemplateCreate(name="hash-tpl", repo_url="https://example.com/repo.git")
    )
    fh = await file_hashes.create(
        FileHashCreate(template_id=t.id, filename="main.tf", hash="abc123")
    )
    assert fh.id == 1
    assert fh.filename == "main.tf"
    assert fh.hard_stop is False


async def test_get_by_template(templates: TemplateDB, file_hashes: FileHashDB):
    t = await templates.create(
        TemplateCreate(name="list-hashes", repo_url="https://example.com/repo.git")
    )
    await file_hashes.create(
        FileHashCreate(template_id=t.id, filename="b.tf", hash="bbb")
    )
    await file_hashes.create(
        FileHashCreate(template_id=t.id, filename="a.tf", hash="aaa")
    )
    result = await file_hashes.get_by_template(t.id)
    assert len(result) == 2
    assert result[0].filename == "a.tf"  # ordered by filename
    assert result[1].filename == "b.tf"


async def test_bulk_insert(templates: TemplateDB, file_hashes: FileHashDB):
    t = await templates.create(
        TemplateCreate(name="bulk-tpl", repo_url="https://example.com/repo.git")
    )
    items = [
        FileHashCreate(template_id=t.id, filename="one.tf", hash="111"),
        FileHashCreate(template_id=t.id, filename="two.tf", hash="222"),
        FileHashCreate(template_id=t.id, filename="three.tf", hash="333", hard_stop=True),
    ]
    result = await file_hashes.bulk_insert(items)
    assert len(result) == 3
    hard_stops = [fh for fh in result if fh.hard_stop]
    assert len(hard_stops) == 1


async def test_bulk_replace(templates: TemplateDB, file_hashes: FileHashDB):
    t = await templates.create(
        TemplateCreate(name="replace-tpl", repo_url="https://example.com/repo.git")
    )
    await file_hashes.bulk_insert([
        FileHashCreate(template_id=t.id, filename="old.tf", hash="old"),
    ])
    new_items = [
        FileHashCreate(template_id=t.id, filename="new.tf", hash="new"),
        FileHashCreate(template_id=t.id, filename="also_new.tf", hash="new2"),
    ]
    result = await file_hashes.bulk_replace(t.id, new_items)
    assert len(result) == 2
    filenames = {fh.filename for fh in result}
    assert "old.tf" not in filenames
    assert "new.tf" in filenames


async def test_cascade_delete(templates: TemplateDB, file_hashes: FileHashDB):
    t = await templates.create(
        TemplateCreate(name="cascade-tpl", repo_url="https://example.com/repo.git")
    )
    await file_hashes.bulk_insert([
        FileHashCreate(template_id=t.id, filename="keep.tf", hash="k"),
        FileHashCreate(template_id=t.id, filename="also_keep.tf", hash="k2"),
    ])
    # Deleting the template should cascade to file_hashes
    await templates.delete(t.id)
    remaining = await file_hashes.get_by_template(t.id)
    assert remaining == []
