"""Template registry CRUD endpoints."""
import logging

from fastapi import APIRouter, HTTPException

from app.config import settings
from app.db import (
    FileHashCreate,
    FileHashDB,
    TemplateCreate,
    TemplateDB,
    TemplateUpdate,
    get_db,
)
from app.services import FileHashService, GitError, GitService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/templates", tags=["templates"])


def _git_service() -> GitService:
    return GitService(settings.clone_dir)


def _hash_service() -> FileHashService:
    return FileHashService()


@router.get("/")
async def list_templates():
    """List all registered templates."""
    db = get_db()
    template_db = TemplateDB(db)
    return await template_db.list()


@router.get("/{template_id}")
async def get_template(template_id: int):
    """Get a single template by ID."""
    db = get_db()
    template_db = TemplateDB(db)
    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")
    return template


@router.post("/", status_code=201)
async def create_template(data: TemplateCreate):
    """Register a new template.

    Clones the repository, verifies the repo_path exists, scans for file
    hashes, and persists everything to the database.
    """
    db = get_db()
    template_db = TemplateDB(db)
    file_hash_db = FileHashDB(db)
    git_service = _git_service()
    hash_service = _hash_service()

    # Check for duplicate name
    existing = await template_db.get_by_name(data.name)
    if existing is not None:
        raise HTTPException(
            status_code=400,
            detail=f"Template with name '{data.name}' already exists",
        )

    # Clone the repo
    try:
        await git_service.clone_or_pull(data.repo_url, data.branch)
    except GitError as exc:
        logger.error("Git clone failed for %s: %s", data.repo_url, exc.message)
        raise HTTPException(
            status_code=400,
            detail=f"Failed to clone repository: {exc.message}",
        )

    # Verify repo_path exists in the clone
    try:
        template_dir = git_service.get_template_dir(data.repo_url, data.repo_path)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    # Scan for file hashes
    entries = hash_service.scan_directory(template_dir)

    # Persist template
    template = await template_db.create(data)

    # Persist file hashes
    if entries:
        hash_creates = [
            FileHashCreate(
                template_id=template.id,
                filename=entry.filename,
                hash=entry.hash,
                hard_stop=entry.hard_stop,
            )
            for entry in entries
        ]
        await file_hash_db.bulk_insert(hash_creates)

    logger.info("Created template %s (id=%s) with %d file hashes", template.name, template.id, len(entries))
    return template


@router.put("/{template_id}")
async def update_template(template_id: int, data: TemplateUpdate):
    """Update an existing template.

    If repo_url or branch changes, re-clones and re-hashes the template
    directory.
    """
    db = get_db()
    template_db = TemplateDB(db)
    file_hash_db = FileHashDB(db)
    git_service = _git_service()
    hash_service = _hash_service()

    existing = await template_db.get(template_id)
    if existing is None:
        raise HTTPException(status_code=404, detail="Template not found")

    updates = data.model_dump(exclude_unset=True)

    # Determine if we need to re-clone
    new_repo_url = updates.get("repo_url", existing.repo_url)
    new_branch = updates.get("branch", existing.branch)
    new_repo_path = updates.get("repo_path", existing.repo_path)
    needs_rehash = "repo_url" in updates or "branch" in updates or "repo_path" in updates

    if needs_rehash:
        try:
            await git_service.clone_or_pull(new_repo_url, new_branch)
        except GitError as exc:
            logger.error("Git clone failed during update: %s", exc.message)
            raise HTTPException(
                status_code=400,
                detail=f"Failed to clone repository: {exc.message}",
            )

        try:
            template_dir = git_service.get_template_dir(new_repo_url, new_repo_path)
        except FileNotFoundError as exc:
            raise HTTPException(status_code=400, detail=str(exc))

        entries = hash_service.scan_directory(template_dir)
        hash_creates = [
            FileHashCreate(
                template_id=template_id,
                filename=entry.filename,
                hash=entry.hash,
                hard_stop=entry.hard_stop,
            )
            for entry in entries
        ]
        await file_hash_db.bulk_replace(template_id, hash_creates)

    template = await template_db.update(template_id, data)
    logger.info("Updated template %s (id=%s)", template.name, template_id)
    return template


@router.delete("/{template_id}")
async def delete_template(template_id: int):
    """Delete a template and clean up its clone directory."""
    db = get_db()
    template_db = TemplateDB(db)
    git_service = _git_service()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    # Delete from DB (cascade deletes file_hashes)
    await template_db.delete(template_id)

    # Clean up clone directory
    git_service.cleanup_clone(template.repo_url)

    logger.info("Deleted template %s (id=%s)", template.name, template_id)
    return {"success": True}


@router.delete("/{template_id}/clone")
async def clear_clone(template_id: int):
    """Remove the local git clone for a template without deleting the DB record."""
    db = get_db()
    template_db = TemplateDB(db)
    git_service = _git_service()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    removed = git_service.cleanup_clone(template.repo_url)
    logger.info("Cleared clone for template %s (id=%s, removed=%s)", template.name, template_id, removed)
    return {"success": True, "removed": removed}
