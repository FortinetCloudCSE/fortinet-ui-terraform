"""Tests for the tfvars.ui management API endpoints."""

import pytest
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock

from httpx import ASGITransport, AsyncClient

from app.db.connection import init_db, close_db, get_db
from app.db.crud import TemplateDB, FileHashDB
from app.db.models import TemplateCreate, FileHashCreate


# ── Fixtures ──────────────────────────────────────────────

SAMPLE_VARIABLES_TF = """\
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "env" {
  description = "Environment name"
  type        = string
}
"""

SAMPLE_TFVARS_EXAMPLE = """\
# @ui-type: select
# @ui-label: AWS Region
# @ui-options: us-east-1, us-west-2
region = "us-west-2"

# @ui-type: text
env = "test"
"""


@pytest.fixture
async def client(tmp_path: Path):
    """Create a test HTTP client backed by a fresh SQLite database."""
    db_path = tmp_path / "test.db"
    await init_db(db_path)

    # Import app after DB is initialised so routers can call get_db()
    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    await close_db()


@pytest.fixture
async def sample_template(client):
    """Insert a template row into the test database."""
    db = get_db()
    template_db = TemplateDB(db)
    template = await template_db.create(
        TemplateCreate(
            name="test-template",
            repo_url="https://github.com/example/repo.git",
            repo_path="terraform/aws/example",
            branch="main",
            tfvars_ui="# empty scaffold",
        )
    )
    return template


@pytest.fixture
async def template_with_hashes(sample_template):
    """Insert a template with stored file hashes."""
    db = get_db()
    file_hash_db = FileHashDB(db)
    await file_hash_db.bulk_insert([
        FileHashCreate(
            template_id=sample_template.id,
            filename="variables.tf",
            hash="abc123",
            hard_stop=True,
        ),
        FileHashCreate(
            template_id=sample_template.id,
            filename="main.tf",
            hash="def456",
            hard_stop=False,
        ),
    ])
    return sample_template


def _mock_clone_or_pull(template_dir: Path):
    """Return an async mock for GitService.clone_or_pull that creates template files."""

    async def _clone_or_pull(repo_url: str, branch: str = "main"):
        template_dir.mkdir(parents=True, exist_ok=True)
        return template_dir.parent  # returns clone root

    return _clone_or_pull


def _setup_template_files(template_dir: Path, variables_tf=True, tfvars_example=True):
    """Create sample terraform files in the template directory."""
    template_dir.mkdir(parents=True, exist_ok=True)
    if variables_tf:
        (template_dir / "variables.tf").write_text(SAMPLE_VARIABLES_TF)
    if tfvars_example:
        (template_dir / "terraform.tfvars.example").write_text(SAMPLE_TFVARS_EXAMPLE)
    # Also create a main.tf so scan_directory picks it up
    (template_dir / "main.tf").write_text('resource "aws_vpc" "main" {}')


# ── POST /scaffold ────────────────────────────────────────


async def test_scaffold_success(client: AsyncClient, sample_template, tmp_path: Path):
    """Scaffold endpoint parses files and returns generated content."""
    template_dir = tmp_path / "clones" / "abcdef123456" / "terraform" / "aws" / "example"
    _setup_template_files(template_dir)

    with (
        patch("app.api.tfvars_ui.GitService") as MockGitService,
    ):
        mock_git = MagicMock()
        mock_git.clone_or_pull = AsyncMock(return_value=template_dir.parent.parent.parent.parent)
        mock_git.get_template_dir = MagicMock(return_value=template_dir)
        MockGitService.return_value = mock_git

        resp = await client.post(f"/api/templates/{sample_template.id}/scaffold")

    assert resp.status_code == 200
    data = resp.json()
    assert "scaffold" in data
    assert data["variable_count"] == 2
    assert "region" in data["scaffold"]
    assert "env" in data["scaffold"]

    # Verify the DB was updated
    db = get_db()
    template_db = TemplateDB(db)
    updated = await template_db.get(sample_template.id)
    assert updated.tfvars_ui == data["scaffold"]


async def test_scaffold_template_not_found(client: AsyncClient):
    """Scaffold returns 404 for a nonexistent template ID."""
    resp = await client.post("/api/templates/9999/scaffold")
    assert resp.status_code == 404


async def test_scaffold_no_variables_tf(client: AsyncClient, sample_template, tmp_path: Path):
    """Scaffold returns 422 when variables.tf is missing."""
    template_dir = tmp_path / "clones" / "abcdef123456" / "terraform" / "aws" / "example"
    # Create directory WITHOUT variables.tf
    _setup_template_files(template_dir, variables_tf=False)

    with patch("app.api.tfvars_ui.GitService") as MockGitService:
        mock_git = MagicMock()
        mock_git.clone_or_pull = AsyncMock(return_value=template_dir.parent.parent.parent.parent)
        mock_git.get_template_dir = MagicMock(return_value=template_dir)
        MockGitService.return_value = mock_git

        resp = await client.post(f"/api/templates/{sample_template.id}/scaffold")

    assert resp.status_code == 422
    assert "variables.tf" in resp.json()["detail"]


# ── GET /export ───────────────────────────────────────────


async def test_export_success(client: AsyncClient, sample_template):
    """Export returns the stored tfvars_ui content."""
    resp = await client.get(f"/api/templates/{sample_template.id}/export")
    assert resp.status_code == 200
    data = resp.json()
    assert data["content"] == "# empty scaffold"
    assert data["name"] == "test-template"


async def test_export_template_not_found(client: AsyncClient):
    """Export returns 404 for a nonexistent template ID."""
    resp = await client.get("/api/templates/9999/export")
    assert resp.status_code == 404


# ── POST /import ──────────────────────────────────────────


async def test_import_success(client: AsyncClient, sample_template, tmp_path: Path):
    """Import updates tfvars_ui in the database."""
    new_content = "# updated scaffold\nregion = \"us-east-1\"\n"
    template_dir = tmp_path / "clones" / "abcdef123456" / "terraform" / "aws" / "example"
    _setup_template_files(template_dir)

    with patch("app.api.tfvars_ui.GitService") as MockGitService:
        mock_git = MagicMock()
        mock_git.clone_or_pull = AsyncMock(return_value=template_dir.parent.parent.parent.parent)
        mock_git.get_template_dir = MagicMock(return_value=template_dir)
        MockGitService.return_value = mock_git

        resp = await client.post(
            f"/api/templates/{sample_template.id}/import",
            json={"content": new_content},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["name"] == "test-template"

    # Verify the DB was updated
    db = get_db()
    template_db = TemplateDB(db)
    updated = await template_db.get(sample_template.id)
    assert updated.tfvars_ui == new_content


async def test_import_template_not_found(client: AsyncClient):
    """Import returns 404 for a nonexistent template ID."""
    resp = await client.post(
        "/api/templates/9999/import",
        json={"content": "# something"},
    )
    assert resp.status_code == 404


# ── GET /drift ────────────────────────────────────────────


async def test_drift_clean(client: AsyncClient, template_with_hashes, tmp_path: Path):
    """Drift endpoint returns clean when stored and current hashes match."""
    template_dir = tmp_path / "clones" / "abcdef123456" / "terraform" / "aws" / "example"
    template_dir.mkdir(parents=True, exist_ok=True)

    # Create files whose hashes match what we stored
    (template_dir / "variables.tf").write_text("# content A")
    (template_dir / "main.tf").write_text("# content B")

    # We need to make the stored hashes match the actual file hashes
    from app.services import FileHashService

    hash_service = FileHashService()
    entries = hash_service.scan_directory(template_dir)

    # Update stored hashes to match the actual file content
    db = get_db()
    file_hash_db = FileHashDB(db)
    await file_hash_db.bulk_replace(
        template_with_hashes.id,
        [
            FileHashCreate(
                template_id=template_with_hashes.id,
                filename=e.filename,
                hash=e.hash,
                hard_stop=e.hard_stop,
            )
            for e in entries
        ],
    )

    with patch("app.api.tfvars_ui.GitService") as MockGitService:
        mock_git = MagicMock()
        mock_git.clone_or_pull = AsyncMock(return_value=template_dir.parent.parent.parent.parent)
        mock_git.get_template_dir = MagicMock(return_value=template_dir)
        MockGitService.return_value = mock_git

        resp = await client.get(f"/api/templates/{template_with_hashes.id}/drift")

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "clean"
    assert data["entries"] == []


async def test_drift_with_changes(client: AsyncClient, template_with_hashes, tmp_path: Path):
    """Drift endpoint detects file changes and returns appropriate status."""
    template_dir = tmp_path / "clones" / "abcdef123456" / "terraform" / "aws" / "example"
    template_dir.mkdir(parents=True, exist_ok=True)

    # Create files with DIFFERENT content than what's stored (hashes won't match)
    (template_dir / "variables.tf").write_text("# completely different content")
    (template_dir / "main.tf").write_text("# also different")

    with patch("app.api.tfvars_ui.GitService") as MockGitService:
        mock_git = MagicMock()
        mock_git.clone_or_pull = AsyncMock(return_value=template_dir.parent.parent.parent.parent)
        mock_git.get_template_dir = MagicMock(return_value=template_dir)
        MockGitService.return_value = mock_git

        resp = await client.get(f"/api/templates/{template_with_hashes.id}/drift")

    assert resp.status_code == 200
    data = resp.json()
    # variables.tf is hard_stop, so overall status should be hard_stop
    assert data["status"] == "hard_stop"
    assert len(data["entries"]) > 0

    # Check that at least one entry is for variables.tf with changed drift_type
    var_entries = [e for e in data["entries"] if e["filename"] == "variables.tf"]
    assert len(var_entries) == 1
    assert var_entries[0]["drift_type"] == "changed"
    assert var_entries[0]["hard_stop"] is True


async def test_drift_template_not_found(client: AsyncClient):
    """Drift returns 404 for a nonexistent template ID."""
    resp = await client.get("/api/templates/9999/drift")
    assert resp.status_code == 404
