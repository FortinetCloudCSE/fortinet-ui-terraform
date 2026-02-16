"""License file management endpoints for cloned template repositories.

Upload, list, and delete .lic files within a template's clone directory
(e.g. licenses/ or asg_license/).  Files are ephemeral — they only exist
in the clone and are never persisted to a database.
"""

import logging
from pathlib import Path

from fastapi import APIRouter, HTTPException, UploadFile, File, Form

from app.config import settings
from app.db import TemplateDB, get_db
from app.services import GitError, GitService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/templates", tags=["template-files"])

MAX_FILE_SIZE = 1 * 1024 * 1024  # 1 MB


def _git_service() -> GitService:
    return GitService(settings.clone_dir)


async def _get_template(template_id: int):
    """Look up a template by ID or raise 404."""
    db = get_db()
    template_db = TemplateDB(db)
    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    return template


async def _clone_and_get_dir(template) -> Path:
    """Clone/pull the template repo and return the template directory path."""
    git_service = _git_service()
    try:
        await git_service.clone_or_pull(template.repo_url, template.branch)
    except GitError as exc:
        logger.error("Git clone failed for %s: %s", template.repo_url, exc.message)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to clone repository: {exc.message}",
        )
    return git_service.get_template_dir(template.repo_url, template.repo_path)


def _validate_directory(directory: str) -> str:
    """Validate that the directory name is safe (no path traversal)."""
    # Normalise and reject anything that escapes the clone dir
    clean = Path(directory)
    if clean.is_absolute() or ".." in clean.parts:
        raise HTTPException(
            status_code=400,
            detail="Directory must be a relative path without '..' components",
        )
    return str(clean)


@router.post("/{template_id}/files/upload")
async def upload_license_file(
    template_id: int,
    file: UploadFile = File(...),
    directory: str = Form("licenses"),
):
    """Upload a .lic file into a subdirectory of the cloned template.

    Args:
        template_id: ID of the registered template.
        file: The license file (must have .lic extension, max 1 MB).
        directory: Target subdirectory inside the clone (e.g. "licenses", "asg_license").
    """
    # Validate extension
    if not file.filename or not file.filename.endswith(".lic"):
        raise HTTPException(status_code=400, detail="Only .lic files are allowed")

    # Validate filename safety
    safe_name = Path(file.filename).name
    if safe_name != file.filename:
        raise HTTPException(status_code=400, detail="Filename must not contain path separators")

    directory = _validate_directory(directory)

    # Read and validate size
    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(status_code=400, detail=f"File exceeds maximum size of {MAX_FILE_SIZE // 1024} KB")

    template = await _get_template(template_id)
    template_dir = await _clone_and_get_dir(template)

    target_dir = template_dir / directory
    target_dir.mkdir(parents=True, exist_ok=True)
    target_path = target_dir / safe_name
    target_path.write_bytes(content)

    logger.info("Uploaded license file %s to %s", safe_name, target_dir)
    return {
        "filename": safe_name,
        "directory": directory,
        "size": len(content),
    }


@router.get("/{template_id}/files/licenses")
async def list_license_files(
    template_id: int,
    directory: str = "licenses",
):
    """List .lic files in a subdirectory of the cloned template.

    Returns a list of {value, label} objects suitable for a select dropdown.
    The value is the relative path (e.g. "./licenses/foo.lic").
    """
    directory = _validate_directory(directory)

    template = await _get_template(template_id)
    template_dir = await _clone_and_get_dir(template)

    target_dir = template_dir / directory
    if not target_dir.is_dir():
        return []

    files = sorted(p.name for p in target_dir.iterdir() if p.suffix == ".lic" and p.is_file())
    return [
        {"value": f"./{directory}/{name}", "label": name}
        for name in files
    ]


@router.delete("/{template_id}/files/{filename}")
async def delete_license_file(
    template_id: int,
    filename: str,
    directory: str = "licenses",
):
    """Delete a .lic file from a subdirectory of the cloned template."""
    directory = _validate_directory(directory)

    # Validate filename safety
    safe_name = Path(filename).name
    if safe_name != filename:
        raise HTTPException(status_code=400, detail="Filename must not contain path separators")

    if not safe_name.endswith(".lic"):
        raise HTTPException(status_code=400, detail="Only .lic files can be deleted")

    template = await _get_template(template_id)
    template_dir = await _clone_and_get_dir(template)

    target_path = template_dir / directory / safe_name
    if not target_path.is_file():
        raise HTTPException(status_code=404, detail="File not found")

    target_path.unlink()
    logger.info("Deleted license file %s from %s/%s", safe_name, template_dir, directory)
    return {"success": True}
