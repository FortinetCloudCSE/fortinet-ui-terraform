"""Tests for the template_terraform API endpoints."""
import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.db.connection import init_db, close_db
from app.db.crud import TemplateDB, FileHashDB
from app.db.models import TemplateCreate, FileHashCreate
from app.services import FileHashService


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
async def db(tmp_path: Path):
    """Create a fresh database for each test."""
    db_path = tmp_path / "test.db"
    conn = await init_db(db_path)
    yield conn
    await close_db()


@pytest.fixture
def template_dir(tmp_path: Path) -> Path:
    """Create a fake terraform template directory with .tf files."""
    tpl_dir = tmp_path / "clone" / "abc123" / "terraform" / "aws" / "my_template"
    tpl_dir.mkdir(parents=True)
    (tpl_dir / "main.tf").write_text('resource "null_resource" "example" {}')
    (tpl_dir / "variables.tf").write_text('variable "name" {}')
    return tpl_dir


@pytest.fixture
async def template(db, template_dir: Path):
    """Insert a template row in the DB and store file hashes matching template_dir."""
    template_db = TemplateDB(db)
    file_hash_db = FileHashDB(db)

    tpl = await template_db.create(
        TemplateCreate(
            name="aws/my_template",
            repo_url="https://github.com/example/repo.git",
            repo_path="terraform/aws/my_template",
            branch="main",
        )
    )

    # Scan the template_dir to get real hashes, then store them
    hash_service = FileHashService()
    entries = hash_service.scan_directory(template_dir)
    if entries:
        creates = [
            FileHashCreate(
                template_id=tpl.id,
                filename=e.filename,
                hash=e.hash,
                hard_stop=e.hard_stop,
            )
            for e in entries
        ]
        await file_hash_db.bulk_insert(creates)

    return tpl


@pytest.fixture
def mock_git_service(template_dir: Path):
    """Patch GitService so clone_or_pull and get_template_dir use the local temp dir."""
    with patch("app.api.template_terraform._git_service") as mock_factory:
        svc = mock_factory.return_value
        svc.clone_or_pull = AsyncMock(return_value=template_dir.parent)
        svc.get_template_dir = lambda repo_url, repo_path: template_dir
        yield svc


@pytest.fixture
def mock_terraform_commands():
    """Patch run_command_stream to emit fake terraform output instead of running real terraform."""
    async def fake_stream(command, cwd, env=None):
        cmd_name = " ".join(command)
        yield (f"[MOCK] Running: {cmd_name}\n", None)
        yield (f"[MOCK] {cmd_name} completed successfully\n", 0)

    with patch("app.api.template_terraform.run_command_stream", side_effect=fake_stream):
        yield


@pytest.fixture
async def client(db, mock_git_service, mock_terraform_commands):
    """Create an async HTTP client bound to the FastAPI app."""
    from app.main import app

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


# ---------------------------------------------------------------------------
# write-tfvars
# ---------------------------------------------------------------------------


async def test_write_tfvars_success(client: AsyncClient, template, template_dir: Path):
    """POST writes terraform.tfvars content to the cloned template directory."""
    content = 'region = "us-west-2"\ncp = "test"'
    response = await client.post(
        f"/api/templates/{template.id}/terraform/write-tfvars",
        json={"content": content},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert "path" in body

    # Verify the file was written
    tfvars_path = template_dir / "terraform.tfvars"
    assert tfvars_path.exists()
    assert tfvars_path.read_text() == content


async def test_write_tfvars_template_not_found(client: AsyncClient):
    """POST with a nonexistent template ID returns 404."""
    response = await client.post(
        "/api/templates/9999/terraform/write-tfvars",
        json={"content": "some content"},
    )
    assert response.status_code == 404


# ---------------------------------------------------------------------------
# plan
# ---------------------------------------------------------------------------


async def test_plan_success(client: AsyncClient, template, template_dir: Path):
    """GET plan runs init + plan and streams output."""
    response = await client.get(f"/api/templates/{template.id}/terraform/plan")
    assert response.status_code == 200
    text = response.text
    assert "terraform init" in text.lower() or "terraform init" in text
    assert "terraform plan" in text.lower() or "terraform plan" in text
    assert "Plan Complete" in text


async def test_plan_template_not_found(client: AsyncClient):
    """GET plan with nonexistent template ID returns 404."""
    response = await client.get("/api/templates/9999/terraform/plan")
    assert response.status_code == 404


async def test_plan_hard_stop_drift(
    client: AsyncClient, template, template_dir: Path, db
):
    """GET plan with hard-stop drift returns 409 Conflict."""
    # Modify variables.tf to create hard-stop drift
    (template_dir / "variables.tf").write_text('variable "changed" { default = "oops" }')

    response = await client.get(f"/api/templates/{template.id}/terraform/plan")
    assert response.status_code == 409
    body = response.json()
    assert "Hard-stop drift detected" in body["detail"]["error"]
    assert len(body["detail"]["drift_entries"]) > 0


async def test_plan_with_warning_drift(
    client: AsyncClient, template, template_dir: Path
):
    """GET plan with warning-only drift (non-hard-stop file changed) still proceeds."""
    # Modify main.tf (not a hard-stop file) to create warning drift
    (template_dir / "main.tf").write_text('resource "null_resource" "changed" {}')

    response = await client.get(f"/api/templates/{template.id}/terraform/plan")
    assert response.status_code == 200
    text = response.text
    assert "Plan Complete" in text


# ---------------------------------------------------------------------------
# apply
# ---------------------------------------------------------------------------


async def test_apply_success(client: AsyncClient, template, template_dir: Path):
    """GET apply runs init + apply and streams output."""
    response = await client.get(f"/api/templates/{template.id}/terraform/apply")
    assert response.status_code == 200
    text = response.text
    assert "terraform init" in text.lower() or "terraform init" in text
    assert "terraform apply" in text.lower() or "apply" in text.lower()
    assert "Apply Complete" in text


async def test_apply_hard_stop_drift(
    client: AsyncClient, template, template_dir: Path, db
):
    """GET apply with hard-stop drift returns 409 Conflict."""
    # Modify variables.tf to create hard-stop drift
    (template_dir / "variables.tf").write_text('variable "drifted" {}')

    response = await client.get(f"/api/templates/{template.id}/terraform/apply")
    assert response.status_code == 409
    body = response.json()
    assert "Hard-stop drift detected" in body["detail"]["error"]


# ---------------------------------------------------------------------------
# destroy
# ---------------------------------------------------------------------------


async def test_destroy_success(client: AsyncClient, template, template_dir: Path):
    """GET destroy runs init + destroy and streams output."""
    response = await client.get(f"/api/templates/{template.id}/terraform/destroy")
    assert response.status_code == 200
    text = response.text
    assert "terraform init" in text.lower() or "terraform init" in text
    assert "terraform destroy" in text.lower() or "destroy" in text.lower()
    assert "Destroy Complete" in text
