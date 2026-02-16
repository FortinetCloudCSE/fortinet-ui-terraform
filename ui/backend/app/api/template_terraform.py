"""Terraform execution endpoints for cloned template repositories.

These endpoints run terraform plan/apply/destroy against cloned repo directories
from the template registry, with drift checking before execution.
"""
import logging
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from app.api.terraform import run_command_stream, _get_env_for_template
from app.config import settings
from app.db import FileHashDB, TemplateDB, get_db
from app.services import (
    DriftService,
    DriftStatus,
    FileHashEntry,
    FileHashService,
    GitError,
    GitService,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/templates", tags=["template-terraform"])


class WriteTfvarsRequest(BaseModel):
    """Request body for writing terraform.tfvars content."""
    content: str


def _git_service() -> GitService:
    return GitService(settings.clone_dir)


def _hash_service() -> FileHashService:
    return FileHashService()


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


async def _run_drift_check(template_id: int, template_dir: Path):
    """Run drift check and raise 409 if hard-stop drift is detected.

    Returns the DriftReport for informational purposes.
    """
    db = get_db()
    file_hash_db = FileHashDB(db)
    stored_db_hashes = await file_hash_db.get_by_template(template_id)
    stored_entries = [
        FileHashEntry(filename=h.filename, hash=h.hash, hard_stop=h.hard_stop)
        for h in stored_db_hashes
    ]

    hash_service = _hash_service()
    current_entries = hash_service.scan_directory(template_dir)

    drift_service = DriftService(file_hash_service=hash_service)
    report = drift_service.compare(stored_db_hashes, current_entries)

    if report.status == DriftStatus.HARD_STOP:
        raise HTTPException(
            status_code=409,
            detail={
                "error": "Hard-stop drift detected",
                "drift_entries": [
                    {
                        "filename": e.filename,
                        "type": e.drift_type.value,
                        "hard_stop": e.hard_stop,
                    }
                    for e in report.entries
                ],
            },
        )

    return report


def _template_name_for_env(template) -> str:
    """Derive the template name string used by _get_env_for_template.

    If repo_path starts with 'gcp/', return it as-is so GCP credentials
    are injected. Otherwise return the repo_path or template name.
    """
    return template.repo_path if template.repo_path else template.name


@router.post("/{template_id}/terraform/write-tfvars")
async def write_tfvars(template_id: int, request: WriteTfvarsRequest):
    """Write terraform.tfvars content to the cloned template directory.

    Args:
        template_id: ID of the registered template.
        request: Body containing the tfvars content string.

    Returns:
        JSON with success status and path to the written file.
    """
    template = await _get_template(template_id)
    template_dir = await _clone_and_get_dir(template)

    tfvars_path = template_dir / "terraform.tfvars"
    tfvars_path.write_text(request.content)

    logger.info("Wrote terraform.tfvars to %s", tfvars_path)
    return {"success": True, "path": str(tfvars_path)}


@router.get("/{template_id}/terraform/plan")
async def run_plan(template_id: int):
    """Run terraform init + plan against the cloned template directory.

    Performs a drift check before execution. If hard-stop drift is detected,
    returns a 409 Conflict response instead of streaming.
    """
    template = await _get_template(template_id)
    template_dir = await _clone_and_get_dir(template)

    # Drift check (raises 409 on hard stop)
    await _run_drift_check(template_id, template_dir)

    template_name = _template_name_for_env(template)
    cmd_env = _get_env_for_template(template_name)

    async def generate():
        yield f"=== Starting Terraform Plan for {template.name} ===\n"
        yield f"Working directory: {template_dir}\n\n"

        # terraform init
        yield "=" * 80 + "\n"
        yield "terraform init\n"
        yield "=" * 80 + "\n"
        init_failed = False
        async for line, exit_code in run_command_stream(
            ["terraform", "init"], template_dir, env=cmd_env
        ):
            yield line
            if exit_code is not None and exit_code != 0:
                init_failed = True

        if init_failed:
            yield "\nERROR: terraform init failed.\n"
            return

        # terraform plan
        yield "\n" + "=" * 80 + "\n"
        yield "terraform plan\n"
        yield "=" * 80 + "\n"
        async for line, exit_code in run_command_stream(
            ["terraform", "plan"], template_dir, env=cmd_env
        ):
            yield line

        yield "\n=== Plan Complete ===\n"

    return StreamingResponse(generate(), media_type="text/plain")


@router.get("/{template_id}/terraform/apply")
async def run_apply(template_id: int):
    """Run terraform init + apply against the cloned template directory.

    Performs a drift check before execution. If hard-stop drift is detected,
    returns a 409 Conflict response instead of streaming.
    """
    template = await _get_template(template_id)
    template_dir = await _clone_and_get_dir(template)

    # Drift check (raises 409 on hard stop)
    await _run_drift_check(template_id, template_dir)

    template_name = _template_name_for_env(template)
    cmd_env = _get_env_for_template(template_name)

    async def generate():
        yield f"=== Starting Terraform Apply for {template.name} ===\n"
        yield f"Working directory: {template_dir}\n\n"

        # terraform init
        yield "=" * 80 + "\n"
        yield "terraform init\n"
        yield "=" * 80 + "\n"
        init_failed = False
        async for line, exit_code in run_command_stream(
            ["terraform", "init"], template_dir, env=cmd_env
        ):
            yield line
            if exit_code is not None and exit_code != 0:
                init_failed = True

        if init_failed:
            yield "\nERROR: terraform init failed.\n"
            return

        # terraform apply -auto-approve
        yield "\n" + "=" * 80 + "\n"
        yield "terraform apply -auto-approve\n"
        yield "=" * 80 + "\n"
        async for line, exit_code in run_command_stream(
            ["terraform", "apply", "-auto-approve"], template_dir, env=cmd_env
        ):
            yield line

        yield "\n=== Apply Complete ===\n"

    return StreamingResponse(generate(), media_type="text/plain")


@router.get("/{template_id}/terraform/destroy")
async def run_destroy(template_id: int):
    """Run terraform init + destroy against the cloned template directory.

    Performs a drift check before execution. If hard-stop drift is detected,
    returns a 409 Conflict response instead of streaming.
    """
    template = await _get_template(template_id)
    template_dir = await _clone_and_get_dir(template)

    # Drift check (raises 409 on hard stop)
    await _run_drift_check(template_id, template_dir)

    template_name = _template_name_for_env(template)
    cmd_env = _get_env_for_template(template_name)

    async def generate():
        yield f"=== Starting Terraform Destroy for {template.name} ===\n"
        yield f"Working directory: {template_dir}\n\n"

        # terraform init
        yield "=" * 80 + "\n"
        yield "terraform init\n"
        yield "=" * 80 + "\n"
        init_failed = False
        async for line, exit_code in run_command_stream(
            ["terraform", "init"], template_dir, env=cmd_env
        ):
            yield line
            if exit_code is not None and exit_code != 0:
                init_failed = True

        if init_failed:
            yield "\nERROR: terraform init failed.\n"
            return

        # terraform destroy -auto-approve
        yield "\n" + "=" * 80 + "\n"
        yield "terraform destroy -auto-approve\n"
        yield "=" * 80 + "\n"
        async for line, exit_code in run_command_stream(
            ["terraform", "destroy", "-auto-approve"], template_dir, env=cmd_env
        ):
            yield line

        yield "\n=== Destroy Complete ===\n"

    return StreamingResponse(generate(), media_type="text/plain")
