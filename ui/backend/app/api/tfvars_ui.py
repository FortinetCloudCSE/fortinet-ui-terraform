"""API endpoints for tfvars.ui scaffold generation, export, import, and drift detection."""

import logging
from dataclasses import asdict

from fastapi import APIRouter, HTTPException, Path as PathParam
from pydantic import BaseModel

from app.config import settings
from app.db import get_db, TemplateDB, FileHashDB, FileHashCreate
from app.db.models import TemplateUpdate
from app.services import (
    GitService,
    GitError,
    FileHashService,
    FileHashEntry,
    DriftService,
    parse_variables,
    parse_tfvars_example,
    generate_scaffold,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/templates", tags=["tfvars-ui"])


# ── Request / Response models ─────────────────────────────


class ImportRequest(BaseModel):
    """Request body for the import endpoint."""

    content: str


# ── Helpers ───────────────────────────────────────────────


def _get_crud():
    """Return TemplateDB and FileHashDB instances from the current connection."""
    db = get_db()
    return TemplateDB(db), FileHashDB(db)


async def _store_hashes(
    file_hash_db: FileHashDB,
    template_id: int,
    entries: list[FileHashEntry],
) -> None:
    """Replace stored file hashes for a template with fresh scan results."""
    creates = [
        FileHashCreate(
            template_id=template_id,
            filename=e.filename,
            hash=e.hash,
            hard_stop=e.hard_stop,
        )
        for e in entries
    ]
    await file_hash_db.bulk_replace(template_id, creates)


# ── Endpoints ─────────────────────────────────────────────


@router.post("/{template_id}/scaffold")
async def scaffold(template_id: int = PathParam(..., gt=0)):
    """Generate a skeleton tfvars.ui from the template's variables.tf and example file.

    Clones or pulls the repository, parses variable definitions and any existing
    terraform.tfvars.example annotations, produces the scaffold content, persists
    it to the database, and returns the result.
    """
    template_db, file_hash_db = _get_crud()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    # Clone / pull the repo
    git_service = GitService(settings.clone_dir)
    try:
        await git_service.clone_or_pull(template.repo_url, template.branch)
    except GitError as exc:
        raise HTTPException(status_code=502, detail=f"Git error: {exc.message}")

    template_dir = git_service.get_template_dir(template.repo_url, template.repo_path)

    # Parse variables.tf (required)
    variables_path = template_dir / "variables.tf"
    if not variables_path.is_file():
        raise HTTPException(
            status_code=422,
            detail="variables.tf not found in template directory",
        )

    variables = parse_variables(variables_path.read_text())

    # Parse terraform.tfvars.example (optional)
    example_path = template_dir / "terraform.tfvars.example"
    example_entries = None
    if example_path.is_file():
        example_entries = parse_tfvars_example(example_path.read_text())

    # Generate scaffold content
    content = generate_scaffold(variables, example_entries)

    # Persist scaffold to DB
    await template_db.update(template_id, TemplateUpdate(tfvars_ui=content))

    # Scan directory and store file hashes
    hash_service = FileHashService()
    scanned = hash_service.scan_directory(template_dir)
    await _store_hashes(file_hash_db, template_id, scanned)

    logger.info(
        "Generated scaffold for template %s (%d variables)", template.name, len(variables)
    )

    return {"scaffold": content, "variable_count": len(variables)}


@router.get("/{template_id}/export")
async def export_tfvars_ui(template_id: int = PathParam(..., gt=0)):
    """Export the current tfvars.ui content for a template."""
    template_db, _ = _get_crud()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    return {"content": template.tfvars_ui, "name": template.name}


@router.post("/{template_id}/import")
async def import_tfvars_ui(
    body: ImportRequest,
    template_id: int = PathParam(..., gt=0),
):
    """Import updated tfvars.ui content for a template.

    Replaces the stored tfvars_ui field and re-scans file hashes if the
    repository clone is available.
    """
    template_db, file_hash_db = _get_crud()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    # Update tfvars_ui in DB
    await template_db.update(template_id, TemplateUpdate(tfvars_ui=body.content))

    # Re-scan file hashes if clone exists
    git_service = GitService(settings.clone_dir)
    try:
        await git_service.clone_or_pull(template.repo_url, template.branch)
        template_dir = git_service.get_template_dir(template.repo_url, template.repo_path)
        hash_service = FileHashService()
        scanned = hash_service.scan_directory(template_dir)
        await _store_hashes(file_hash_db, template_id, scanned)
    except (GitError, FileNotFoundError) as exc:
        logger.warning("Could not re-scan hashes during import: %s", exc)

    return {"success": True, "name": template.name}


@router.get("/{template_id}/drift")
async def check_drift(template_id: int = PathParam(..., gt=0)):
    """Check for drift between stored file hashes and the current repository state.

    Clones or pulls the repository, scans the template directory, compares
    against the stored hashes, and returns a drift report.
    """
    template_db, file_hash_db = _get_crud()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    # Get stored hashes from DB
    stored_db_hashes = await file_hash_db.get_by_template(template_id)

    # Clone / pull the repo to get current state
    git_service = GitService(settings.clone_dir)
    try:
        await git_service.clone_or_pull(template.repo_url, template.branch)
    except GitError as exc:
        raise HTTPException(status_code=502, detail=f"Git error: {exc.message}")

    template_dir = git_service.get_template_dir(template.repo_url, template.repo_path)

    # Scan current files
    hash_service = FileHashService()
    current_entries = hash_service.scan_directory(template_dir)

    # Compare stored vs current
    drift_service = DriftService(hash_service)
    report = drift_service.compare(stored_db_hashes, current_entries)

    # Serialize the frozen dataclasses to dicts
    return {
        "status": report.status.value,
        "entries": [asdict(entry) for entry in report.entries],
    }
