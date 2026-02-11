"""Drift detection service for comparing stored file hashes against the filesystem."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from app.db.models import FileHash
from app.services.file_hash_service import FileHashEntry, FileHashService


class DriftStatus(str, Enum):
    """Overall drift status for a template directory."""

    CLEAN = "clean"
    WARNING = "warning"
    HARD_STOP = "hard_stop"


class DriftType(str, Enum):
    """Classification of how a single file has drifted."""

    CHANGED = "changed"
    ADDED = "added"
    REMOVED = "removed"


@dataclass(frozen=True)
class DriftEntry:
    """A single file that has drifted from its stored hash."""

    filename: str
    drift_type: DriftType
    hard_stop: bool
    old_hash: str | None = None
    new_hash: str | None = None


@dataclass(frozen=True)
class DriftReport:
    """Aggregated drift report for a template directory."""

    status: DriftStatus
    entries: list[DriftEntry]


class DriftService:
    """Compares stored file hashes (from DB) against the current filesystem state."""

    def __init__(self, file_hash_service: FileHashService) -> None:
        self._file_hash_service = file_hash_service

    def compare(
        self,
        stored_hashes: list[FileHash],
        current_entries: list[FileHashEntry],
    ) -> DriftReport:
        """Compare stored hashes against current scan results and produce a drift report.

        Parameters
        ----------
        stored_hashes:
            File hash records previously persisted in the database.
        current_entries:
            File hash entries from a fresh ``FileHashService.scan_directory()`` call.

        Returns
        -------
        DriftReport
            A report with individual :class:`DriftEntry` items and an overall status.
        """
        stored_map: dict[str, FileHash] = {fh.filename: fh for fh in stored_hashes}
        current_map: dict[str, FileHashEntry] = {fe.filename: fe for fe in current_entries}

        entries: list[DriftEntry] = []

        # Files in stored but not in current -> REMOVED
        for filename, stored_fh in stored_map.items():
            if filename not in current_map:
                entries.append(
                    DriftEntry(
                        filename=filename,
                        drift_type=DriftType.REMOVED,
                        hard_stop=stored_fh.hard_stop,
                        old_hash=stored_fh.hash,
                        new_hash=None,
                    )
                )

        # Files in current but not in stored -> ADDED
        for filename, current_fe in current_map.items():
            if filename not in stored_map:
                entries.append(
                    DriftEntry(
                        filename=filename,
                        drift_type=DriftType.ADDED,
                        hard_stop=FileHashService.is_hard_stop(filename),
                        old_hash=None,
                        new_hash=current_fe.hash,
                    )
                )

        # Files in both where hash differs -> CHANGED
        for filename in stored_map:
            if filename in current_map and stored_map[filename].hash != current_map[filename].hash:
                entries.append(
                    DriftEntry(
                        filename=filename,
                        drift_type=DriftType.CHANGED,
                        hard_stop=FileHashService.is_hard_stop(filename),
                        old_hash=stored_map[filename].hash,
                        new_hash=current_map[filename].hash,
                    )
                )

        # Sort entries by filename for deterministic output
        entries.sort(key=lambda e: e.filename)

        # Determine overall status
        if any(e.hard_stop for e in entries):
            status = DriftStatus.HARD_STOP
        elif entries:
            status = DriftStatus.WARNING
        else:
            status = DriftStatus.CLEAN

        return DriftReport(status=status, entries=entries)

    def check_directory(
        self,
        stored_hashes: list[FileHash],
        directory: Path,
    ) -> DriftReport:
        """Scan a directory and compare against stored hashes.

        Convenience method that calls :meth:`FileHashService.scan_directory` and
        then delegates to :meth:`compare`.

        Parameters
        ----------
        stored_hashes:
            File hash records previously persisted in the database.
        directory:
            Path to the terraform template directory to scan.

        Returns
        -------
        DriftReport
            The drift comparison result.
        """
        current_entries = self._file_hash_service.scan_directory(directory)
        return self.compare(stored_hashes, current_entries)
