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


class ResolveRequest(BaseModel):
    """Request body for the scaffold conflict resolve endpoint."""

    choice: str  # "repo" or "db"


async def _scan_and_store_hashes(file_hash_db, template_id, template_dir):
    """Scan template directory and persist file hashes."""
    hash_service = FileHashService()
    scanned = hash_service.scan_directory(template_dir)
    await _store_hashes(file_hash_db, template_id, scanned)


@router.post("/{template_id}/scaffold")
async def scaffold(template_id: int = PathParam(..., gt=0)):
    """Generate or discover a tfvars.ui for the template.

    Priority order:
    1. ``tfvars.ui`` file in the repo (always overrides annotated example).
       If the DB already has a tfvars_ui, returns a conflict so the user
       can choose which to keep.
    2. ``terraform.tfvars.example`` with ``@ui-`` annotations — preserves them.
    3. Bare scaffold generated from ``variables.tf`` metadata alone.
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

    # Always update file hashes
    await _scan_and_store_hashes(file_hash_db, template_id, template_dir)

    # ── Check for tfvars.ui in the repo ──────────────────────
    tfvars_ui_path = template_dir / "tfvars.ui"
    repo_has_tfvars_ui = tfvars_ui_path.is_file()
    db_has_tfvars_ui = bool(template.tfvars_ui)

    if repo_has_tfvars_ui:
        repo_content = tfvars_ui_path.read_text()
        repo_entries = parse_tfvars_example(repo_content)

        # Conflict: both DB and repo have tfvars.ui — let user choose
        if db_has_tfvars_ui:
            db_entries = parse_tfvars_example(template.tfvars_ui)
            logger.info(
                "Scaffold conflict for template %s: repo=%d vars, db=%d vars",
                template.name,
                len(repo_entries),
                len(db_entries),
            )
            return {
                "conflict": True,
                "repo_scaffold": repo_content,
                "repo_variable_count": len(repo_entries),
                "db_scaffold": template.tfvars_ui,
                "db_variable_count": len(db_entries),
            }

        # No conflict — repo tfvars.ui wins, save to DB
        await template_db.update(template_id, TemplateUpdate(tfvars_ui=repo_content))
        logger.info(
            "Used existing tfvars.ui for template %s (%d variables)",
            template.name,
            len(repo_entries),
        )
        return {
            "scaffold": repo_content,
            "variable_count": len(repo_entries),
            "source": "existing_tfvars_ui",
        }

    # ── No tfvars.ui in repo — generate from variables.tf ────
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
    annotation_count = 0
    if example_path.is_file():
        example_entries = parse_tfvars_example(example_path.read_text())
        for entry in example_entries:
            if entry.ui_annotations:
                annotation_count += len(entry.ui_annotations)

    content = generate_scaffold(variables, example_entries)
    source = "annotated_example" if annotation_count > 0 else "generated"

    await template_db.update(template_id, TemplateUpdate(tfvars_ui=content))

    logger.info(
        "Generated scaffold for template %s (%d variables, source=%s, annotations=%d)",
        template.name,
        len(variables),
        source,
        annotation_count,
    )

    return {
        "scaffold": content,
        "variable_count": len(variables),
        "source": source,
        "annotation_count": annotation_count,
    }


@router.post("/{template_id}/scaffold/resolve")
async def resolve_scaffold(
    body: ResolveRequest,
    template_id: int = PathParam(..., gt=0),
):
    """Resolve a scaffold conflict by choosing the repo or DB version.

    Called by the frontend after a scaffold response with ``conflict: true``.
    Persists the chosen content to the database.
    """
    if body.choice not in ("repo", "db"):
        raise HTTPException(status_code=400, detail="choice must be 'repo' or 'db'")

    template_db, _ = _get_crud()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    if body.choice == "repo":
        # Fetch repo content again
        git_service = GitService(settings.clone_dir)
        template_dir = git_service.get_template_dir(template.repo_url, template.repo_path)
        tfvars_ui_path = template_dir / "tfvars.ui"
        if not tfvars_ui_path.is_file():
            raise HTTPException(status_code=422, detail="tfvars.ui no longer found in repo")
        content = tfvars_ui_path.read_text()
        await template_db.update(template_id, TemplateUpdate(tfvars_ui=content))
        source = "repo"
    else:
        # Keep DB version — nothing to update
        content = template.tfvars_ui
        source = "db"

    entries = parse_tfvars_example(content)
    logger.info("Resolved scaffold conflict for template %s: chose %s", template.name, source)

    return {
        "scaffold": content,
        "variable_count": len(entries),
        "source": source,
    }


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


# ── Schema endpoint ──────────────────────────────────────


def _parse_default_value(raw: str, ui_type: str):
    """Parse a raw tfvars value string into a JSON-friendly Python value."""
    if not raw:
        if ui_type == "list":
            return []
        return ""
    # Strip surrounding quotes for strings
    if raw.startswith('"') and raw.endswith('"') and len(raw) >= 2:
        return raw[1:-1]
    if raw == "true":
        return True
    if raw == "false":
        return False
    if ui_type in ("number", "slider", "range"):
        try:
            return int(raw)
        except ValueError:
            try:
                return float(raw)
            except ValueError:
                return raw
    # Parse HCL list literals into Python lists
    if ui_type == "list" and raw.startswith("[") and raw.endswith("]"):
        inner = raw[1:-1].strip()
        if not inner:
            return []
        # Split on commas, strip whitespace and quotes from each item
        items = []
        for item in inner.split(","):
            item = item.strip()
            if item.startswith('"') and item.endswith('"') and len(item) >= 2:
                item = item[1:-1]
            if item:
                items.append(item)
        return items
    return raw


# Annotation keys (with hyphens) → field property names (with underscores)
_ANNOTATION_TO_FIELD = {
    "description": "description",
    "source": "source",
    "options": "options",
    "depends-on": "depends_on",
    "show-if": "show_if",
    "hide-if": "hide_if",
    "tag-key": "tag_key",
    "tag-pattern": "tag_pattern",
    "tag-resource-type": "tag_resource_type",
    "label-key": "label_key",
    "label-pattern": "label_pattern",
    "label-resource-type": "label_resource_type",
    "width": "width",
    "placeholder": "placeholder",
    "help": "help",
    "pattern": "pattern",
    "compute": "compute",
    "tfvars-exclude": "tfvars_exclude",
    "exclusive-with": "exclusive_with",
    "file-count": "file_count",
    "file-directory": "file_directory",
}


def _entries_to_schema(entries) -> list[dict]:
    """Convert TfvarsEntry list to frontend-compatible schema with groups and fields."""
    groups_dict: dict[str, list[dict]] = {}
    group_order: list[str] = []

    for entry in entries:
        ann = entry.ui_annotations
        group_name = ann.get("group", "General")

        if group_name not in groups_dict:
            groups_dict[group_name] = []
            group_order.append(group_name)

        ui_type = ann.get("type", "text")
        default_raw = ann.get("default", entry.value)
        default_value = _parse_default_value(default_raw, ui_type)

        field = {
            "name": entry.name,
            "type": ui_type,
            "label": ann.get("label", entry.name.replace("_", " ").title()),
            "default_value": default_value,
            "required": ann.get("required", "").lower() == "true",
        }

        for ann_key, field_key in _ANNOTATION_TO_FIELD.items():
            if ann_key in ann:
                field[field_key] = ann[ann_key]

        groups_dict[group_name].append(field)

    return [
        {"name": name, "label": name, "fields": groups_dict[name]}
        for name in group_order
    ]


@router.get("/{template_id}/schema")
async def get_schema(template_id: int = PathParam(..., gt=0)):
    """Return a JSON form schema derived from the template's tfvars.ui content.

    Parses the stored tfvars.ui text into groups and fields suitable for
    rendering a dynamic configuration form in the frontend.
    """
    template_db, _ = _get_crud()

    template = await template_db.get(template_id)
    if template is None:
        raise HTTPException(status_code=404, detail="Template not found")

    content = template.tfvars_ui
    if not content:
        return {"groups": []}

    entries = parse_tfvars_example(content)
    groups = _entries_to_schema(entries)
    return {"groups": groups}


@router.post("/preview-schema")
async def preview_schema(body: ImportRequest):
    """Parse raw tfvars.ui content into a form schema without requiring a template.

    Used by the live preview editor to render a form preview as the user
    edits annotation content.
    """
    if not body.content.strip():
        return {"groups": []}

    entries = parse_tfvars_example(body.content)
    groups = _entries_to_schema(entries)
    return {"groups": groups}
