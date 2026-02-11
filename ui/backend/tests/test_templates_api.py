"""Tests for the template registry API endpoints."""
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.db.connection import init_db, close_db
from app.main import app
from app.services.file_hash_service import FileHashEntry


SAMPLE_REPO_URL = "https://github.com/example/repo.git"
SAMPLE_TEMPLATE = {
    "name": "aws/existing_vpc_resources",
    "repo_url": SAMPLE_REPO_URL,
    "repo_path": "terraform/aws/existing_vpc_resources",
    "branch": "main",
}


SAMPLE_HASHES = [
    FileHashEntry(filename="main.tf", hash="abc123", hard_stop=False),
    FileHashEntry(filename="variables.tf", hash="def456", hard_stop=True),
]


@pytest.fixture
async def client(tmp_path):
    """Create a test client with a fresh database."""
    db_path = tmp_path / "test.db"
    await init_db(db_path)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    await close_db()


def _mock_git_clone(tmp_path: Path):
    """Return an AsyncMock for clone_or_pull that returns a temp directory."""
    clone_path = tmp_path / "clones" / "abc123"
    clone_path.mkdir(parents=True, exist_ok=True)
    mock = AsyncMock(return_value=clone_path)
    return mock


def _mock_git_template_dir(tmp_path: Path):
    """Return a MagicMock for get_template_dir that returns a temp directory."""
    template_dir = tmp_path / "clones" / "abc123" / "terraform"
    template_dir.mkdir(parents=True, exist_ok=True)
    mock = MagicMock(return_value=template_dir)
    return mock


# ── List Templates ────────────────────────────────────────


async def test_list_templates_empty(client: AsyncClient):
    """GET /api/templates returns empty list when no templates exist."""
    resp = await client.get("/api/templates/")
    assert resp.status_code == 200
    assert resp.json() == []


async def test_list_templates_after_create(client: AsyncClient, tmp_path: Path):
    """GET /api/templates returns created templates."""
    mock_clone = _mock_git_clone(tmp_path)
    mock_dir = _mock_git_template_dir(tmp_path)

    with (
        patch("app.api.templates._git_service") as mock_git_svc,
        patch("app.api.templates._hash_service") as mock_hash_svc,
    ):
        svc = MagicMock()
        svc.clone_or_pull = mock_clone
        svc.get_template_dir = mock_dir
        mock_git_svc.return_value = svc

        hsvc = MagicMock()
        hsvc.scan_directory.return_value = SAMPLE_HASHES
        mock_hash_svc.return_value = hsvc

        # Create two templates
        await client.post("/api/templates/", json=SAMPLE_TEMPLATE)
        await client.post(
            "/api/templates/",
            json={**SAMPLE_TEMPLATE, "name": "aws/autoscale_template"},
        )

    resp = await client.get("/api/templates/")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2
    names = {t["name"] for t in data}
    assert "aws/existing_vpc_resources" in names
    assert "aws/autoscale_template" in names


# ── Create Template ───────────────────────────────────────


async def test_create_template(client: AsyncClient, tmp_path: Path):
    """POST /api/templates creates and returns a template."""
    mock_clone = _mock_git_clone(tmp_path)
    mock_dir = _mock_git_template_dir(tmp_path)

    with (
        patch("app.api.templates._git_service") as mock_git_svc,
        patch("app.api.templates._hash_service") as mock_hash_svc,
    ):
        svc = MagicMock()
        svc.clone_or_pull = mock_clone
        svc.get_template_dir = mock_dir
        mock_git_svc.return_value = svc

        hsvc = MagicMock()
        hsvc.scan_directory.return_value = SAMPLE_HASHES
        mock_hash_svc.return_value = hsvc

        resp = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)

    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == SAMPLE_TEMPLATE["name"]
    assert data["repo_url"] == SAMPLE_TEMPLATE["repo_url"]
    assert data["repo_path"] == SAMPLE_TEMPLATE["repo_path"]
    assert data["branch"] == "main"
    assert "id" in data
    assert "created_date" in data
    assert "updated_date" in data


async def test_create_template_duplicate_name(client: AsyncClient, tmp_path: Path):
    """POST /api/templates with duplicate name returns 400."""
    mock_clone = _mock_git_clone(tmp_path)
    mock_dir = _mock_git_template_dir(tmp_path)

    with (
        patch("app.api.templates._git_service") as mock_git_svc,
        patch("app.api.templates._hash_service") as mock_hash_svc,
    ):
        svc = MagicMock()
        svc.clone_or_pull = mock_clone
        svc.get_template_dir = mock_dir
        mock_git_svc.return_value = svc

        hsvc = MagicMock()
        hsvc.scan_directory.return_value = SAMPLE_HASHES
        mock_hash_svc.return_value = hsvc

        # Create first
        resp1 = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)
        assert resp1.status_code == 201

        # Duplicate
        resp2 = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)
        assert resp2.status_code == 400
        assert "already exists" in resp2.json()["detail"]


async def test_create_template_clone_fails(client: AsyncClient):
    """POST /api/templates returns 400 when git clone fails."""
    from app.services.git_service import GitError

    with patch("app.api.templates._git_service") as mock_git_svc:
        svc = MagicMock()
        svc.clone_or_pull = AsyncMock(
            side_effect=GitError("fatal: repo not found", returncode=128, stderr="not found")
        )
        mock_git_svc.return_value = svc

        resp = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)

    assert resp.status_code == 400
    assert "Failed to clone repository" in resp.json()["detail"]


async def test_create_template_bad_repo_path(client: AsyncClient, tmp_path: Path):
    """POST /api/templates returns 400 when repo_path not found in clone."""
    mock_clone = _mock_git_clone(tmp_path)

    with (
        patch("app.api.templates._git_service") as mock_git_svc,
    ):
        svc = MagicMock()
        svc.clone_or_pull = mock_clone
        svc.get_template_dir = MagicMock(
            side_effect=FileNotFoundError("Template path 'bad/path' not found in clone")
        )
        mock_git_svc.return_value = svc

        resp = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)

    assert resp.status_code == 400
    assert "not found" in resp.json()["detail"]


# ── Get Template ──────────────────────────────────────────


async def test_get_template(client: AsyncClient, tmp_path: Path):
    """GET /api/templates/{id} returns the template."""
    mock_clone = _mock_git_clone(tmp_path)
    mock_dir = _mock_git_template_dir(tmp_path)

    with (
        patch("app.api.templates._git_service") as mock_git_svc,
        patch("app.api.templates._hash_service") as mock_hash_svc,
    ):
        svc = MagicMock()
        svc.clone_or_pull = mock_clone
        svc.get_template_dir = mock_dir
        mock_git_svc.return_value = svc

        hsvc = MagicMock()
        hsvc.scan_directory.return_value = SAMPLE_HASHES
        mock_hash_svc.return_value = hsvc

        create_resp = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)
        template_id = create_resp.json()["id"]

    resp = await client.get(f"/api/templates/{template_id}")
    assert resp.status_code == 200
    assert resp.json()["name"] == SAMPLE_TEMPLATE["name"]
    assert resp.json()["id"] == template_id


async def test_get_template_not_found(client: AsyncClient):
    """GET /api/templates/{id} returns 404 for non-existent template."""
    resp = await client.get("/api/templates/9999")
    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()


# ── Update Template ───────────────────────────────────────


async def test_update_template(client: AsyncClient, tmp_path: Path):
    """PUT /api/templates/{id} updates and returns the template."""
    mock_clone = _mock_git_clone(tmp_path)
    mock_dir = _mock_git_template_dir(tmp_path)

    with (
        patch("app.api.templates._git_service") as mock_git_svc,
        patch("app.api.templates._hash_service") as mock_hash_svc,
    ):
        svc = MagicMock()
        svc.clone_or_pull = mock_clone
        svc.get_template_dir = mock_dir
        mock_git_svc.return_value = svc

        hsvc = MagicMock()
        hsvc.scan_directory.return_value = SAMPLE_HASHES
        mock_hash_svc.return_value = hsvc

        # Create first
        create_resp = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)
        template_id = create_resp.json()["id"]

        # Update name only (no repo/branch change, so no re-clone)
        resp = await client.put(
            f"/api/templates/{template_id}",
            json={"name": "renamed-template"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "renamed-template"
    assert data["repo_url"] == SAMPLE_TEMPLATE["repo_url"]  # unchanged


async def test_update_template_not_found(client: AsyncClient):
    """PUT /api/templates/{id} returns 404 for non-existent template."""
    resp = await client.put(
        "/api/templates/9999",
        json={"name": "ghost"},
    )
    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()


# ── Delete Template ───────────────────────────────────────


async def test_delete_template(client: AsyncClient, tmp_path: Path):
    """DELETE /api/templates/{id} removes the template."""
    mock_clone = _mock_git_clone(tmp_path)
    mock_dir = _mock_git_template_dir(tmp_path)

    with (
        patch("app.api.templates._git_service") as mock_git_svc,
        patch("app.api.templates._hash_service") as mock_hash_svc,
    ):
        svc = MagicMock()
        svc.clone_or_pull = mock_clone
        svc.get_template_dir = mock_dir
        svc.cleanup_clone = MagicMock(return_value=True)
        mock_git_svc.return_value = svc

        hsvc = MagicMock()
        hsvc.scan_directory.return_value = SAMPLE_HASHES
        mock_hash_svc.return_value = hsvc

        # Create first
        create_resp = await client.post("/api/templates/", json=SAMPLE_TEMPLATE)
        template_id = create_resp.json()["id"]

        # Delete
        resp = await client.delete(f"/api/templates/{template_id}")

    assert resp.status_code == 200
    assert resp.json()["success"] is True

    # Verify gone
    get_resp = await client.get(f"/api/templates/{template_id}")
    assert get_resp.status_code == 404


async def test_delete_template_not_found(client: AsyncClient):
    """DELETE /api/templates/{id} returns 404 for non-existent template."""
    resp = await client.delete("/api/templates/9999")
    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()
