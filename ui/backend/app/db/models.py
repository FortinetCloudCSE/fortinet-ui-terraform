"""Pydantic models for the template registry database."""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel


# ── Templates ──────────────────────────────────────────────


class TemplateCreate(BaseModel):
    """Input model for registering a new template."""
    name: str
    repo_url: str
    repo_path: str = ""
    branch: str = "main"
    tfvars_ui: str = "terraform.tfvars.example"
    snapshot_date: Optional[datetime] = None


class TemplateUpdate(BaseModel):
    """Input model for updating a template (all fields optional)."""
    name: Optional[str] = None
    repo_url: Optional[str] = None
    repo_path: Optional[str] = None
    branch: Optional[str] = None
    tfvars_ui: Optional[str] = None
    snapshot_date: Optional[datetime] = None


class Template(BaseModel):
    """Full template record returned from the database."""
    id: int
    name: str
    repo_url: str
    repo_path: str
    branch: str
    tfvars_ui: str
    snapshot_date: Optional[datetime] = None
    created_date: datetime
    updated_date: datetime


# ── File Hashes ────────────────────────────────────────────


class FileHashCreate(BaseModel):
    """Input model for inserting a file hash."""
    template_id: int
    filename: str
    hash: str
    hard_stop: bool = False


class FileHash(BaseModel):
    """Full file-hash record returned from the database."""
    id: int
    template_id: int
    filename: str
    hash: str
    hard_stop: bool
