"""Services package for the Terraform Configuration UI backend."""

from app.services.drift_service import DriftEntry, DriftReport, DriftService, DriftStatus, DriftType
from app.services.file_hash_service import FileHashEntry, FileHashService
from app.services.git_service import GitError, GitService
from app.services.hcl_parser import HCLVariable, extract_options_from_validation, parse_variables
from app.services.scaffold_generator import generate_scaffold
from app.services.tfvars_example_parser import TfvarsEntry, parse_tfvars_example

__all__ = [
    "DriftEntry",
    "DriftReport",
    "DriftService",
    "DriftStatus",
    "DriftType",
    "FileHashEntry",
    "FileHashService",
    "GitError",
    "GitService",
    "HCLVariable",
    "TfvarsEntry",
    "extract_options_from_validation",
    "generate_scaffold",
    "parse_tfvars_example",
    "parse_variables",
]
