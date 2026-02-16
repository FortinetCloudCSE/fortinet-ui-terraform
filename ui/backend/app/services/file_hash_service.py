"""File hashing service for tracking terraform template file changes."""

import hashlib
import logging
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)

HARD_STOP_FILES = {"variables.tf", "terraform.tfvars.example"}


@dataclass(frozen=True)
class FileHashEntry:
    """A single file's hash and classification."""

    filename: str
    hash: str
    hard_stop: bool


class FileHashService:
    """Scans terraform template directories and computes file hashes."""

    @staticmethod
    def compute_file_hash(file_path: Path) -> str:
        """Return the SHA-256 hex digest of a file."""
        sha256 = hashlib.sha256()
        with open(file_path, "rb") as fh:
            for chunk in iter(lambda: fh.read(8192), b""):
                sha256.update(chunk)
        return sha256.hexdigest()

    @staticmethod
    def is_hard_stop(filename: str) -> bool:
        """Return True if changes to this file should be treated as a hard stop."""
        return filename in HARD_STOP_FILES

    def scan_directory(self, directory: Path) -> list[FileHashEntry]:
        """Scan top-level terraform files in *directory* and return hash entries.

        Includes ``*.tf``, ``terraform.tfvars.example``, and ``terraform.tfvars``.
        Does **not** recurse into subdirectories.

        Returns a list of :class:`FileHashEntry` sorted by filename.
        """
        if not directory.is_dir():
            logger.warning("scan_directory called on non-directory: %s", directory)
            return []

        entries: list[FileHashEntry] = []
        for item in directory.iterdir():
            if not item.is_file():
                continue
            name = item.name
            if name.endswith(".tf") or name == "terraform.tfvars.example":
                file_hash = self.compute_file_hash(item)
                entries.append(
                    FileHashEntry(
                        filename=name,
                        hash=file_hash,
                        hard_stop=self.is_hard_stop(name),
                    )
                )

        entries.sort(key=lambda e: e.filename)
        return entries
