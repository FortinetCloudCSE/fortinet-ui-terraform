"""Tests for DriftService."""

from pathlib import Path

from app.db.models import FileHash
from app.services.drift_service import (
    DriftEntry,
    DriftReport,
    DriftService,
    DriftStatus,
    DriftType,
)
from app.services.file_hash_service import FileHashEntry, FileHashService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _svc() -> DriftService:
    return DriftService(file_hash_service=FileHashService())


def _stored(
    filename: str, hash: str, hard_stop: bool, *, id: int = 1, template_id: int = 1
) -> FileHash:
    return FileHash(
        id=id, template_id=template_id, filename=filename, hash=hash, hard_stop=hard_stop
    )


def _current(filename: str, hash: str, hard_stop: bool) -> FileHashEntry:
    return FileHashEntry(filename=filename, hash=hash, hard_stop=hard_stop)


# ---------------------------------------------------------------------------
# Core comparison tests
# ---------------------------------------------------------------------------


class TestCompareClean:
    def test_compare_clean(self):
        """Stored matches current exactly -> CLEAN status with no entries."""
        svc = _svc()
        stored = [
            _stored("main.tf", "aaa", False),
            _stored("variables.tf", "bbb", True),
        ]
        current = [
            _current("main.tf", "aaa", False),
            _current("variables.tf", "bbb", True),
        ]
        report = svc.compare(stored, current)
        assert report.status == DriftStatus.CLEAN
        assert report.entries == []


class TestCompareChangedFile:
    def test_compare_changed_file(self):
        """Same files but different hash -> CHANGED entry."""
        svc = _svc()
        stored = [_stored("main.tf", "aaa", False)]
        current = [_current("main.tf", "zzz", False)]
        report = svc.compare(stored, current)
        assert len(report.entries) == 1
        entry = report.entries[0]
        assert entry.filename == "main.tf"
        assert entry.drift_type == DriftType.CHANGED
        assert entry.old_hash == "aaa"
        assert entry.new_hash == "zzz"


class TestCompareAddedFile:
    def test_compare_added_file(self):
        """New file in current not in stored -> ADDED entry."""
        svc = _svc()
        stored = [_stored("main.tf", "aaa", False)]
        current = [
            _current("main.tf", "aaa", False),
            _current("outputs.tf", "ccc", False),
        ]
        report = svc.compare(stored, current)
        assert len(report.entries) == 1
        entry = report.entries[0]
        assert entry.filename == "outputs.tf"
        assert entry.drift_type == DriftType.ADDED
        assert entry.old_hash is None
        assert entry.new_hash == "ccc"


class TestCompareRemovedFile:
    def test_compare_removed_file(self):
        """File in stored not in current -> REMOVED entry."""
        svc = _svc()
        stored = [
            _stored("main.tf", "aaa", False),
            _stored("outputs.tf", "ccc", False, id=2),
        ]
        current = [_current("main.tf", "aaa", False)]
        report = svc.compare(stored, current)
        assert len(report.entries) == 1
        entry = report.entries[0]
        assert entry.filename == "outputs.tf"
        assert entry.drift_type == DriftType.REMOVED
        assert entry.old_hash == "ccc"
        assert entry.new_hash is None


class TestCompareMixedChanges:
    def test_compare_mixed_changes(self):
        """Combination of changed, added, removed in one report."""
        svc = _svc()
        stored = [
            _stored("main.tf", "aaa", False, id=1),
            _stored("old_file.tf", "bbb", False, id=2),
            _stored("outputs.tf", "ccc", False, id=3),
        ]
        current = [
            _current("main.tf", "changed_hash", False),
            _current("new_file.tf", "ddd", False),
            _current("outputs.tf", "ccc", False),
        ]
        report = svc.compare(stored, current)
        by_name = {e.filename: e for e in report.entries}
        assert len(by_name) == 3
        assert by_name["main.tf"].drift_type == DriftType.CHANGED
        assert by_name["old_file.tf"].drift_type == DriftType.REMOVED
        assert by_name["new_file.tf"].drift_type == DriftType.ADDED


# ---------------------------------------------------------------------------
# Status classification tests
# ---------------------------------------------------------------------------


class TestStatusHardStopVariablesTfChanged:
    def test_status_hard_stop_if_variables_tf_changed(self):
        """Changing variables.tf triggers HARD_STOP status."""
        svc = _svc()
        stored = [_stored("variables.tf", "old", True)]
        current = [_current("variables.tf", "new", True)]
        report = svc.compare(stored, current)
        assert report.status == DriftStatus.HARD_STOP
        assert report.entries[0].hard_stop is True


class TestStatusHardStopTfvarsExampleAdded:
    def test_status_hard_stop_if_tfvars_example_added(self):
        """Adding terraform.tfvars.example triggers HARD_STOP status."""
        svc = _svc()
        stored: list[FileHash] = []
        current = [_current("terraform.tfvars.example", "abc", True)]
        report = svc.compare(stored, current)
        assert report.status == DriftStatus.HARD_STOP
        assert report.entries[0].hard_stop is True
        assert report.entries[0].drift_type == DriftType.ADDED


class TestStatusHardStopTfvarsAppeared:
    def test_status_hard_stop_if_tfvars_appeared(self):
        """terraform.tfvars appearing (added) triggers HARD_STOP -- someone committed a tfvars."""
        svc = _svc()
        stored = [_stored("main.tf", "aaa", False)]
        current = [
            _current("main.tf", "aaa", False),
            _current("terraform.tfvars", "secret_stuff", True),
        ]
        report = svc.compare(stored, current)
        assert report.status == DriftStatus.HARD_STOP
        assert len(report.entries) == 1
        entry = report.entries[0]
        assert entry.filename == "terraform.tfvars"
        assert entry.drift_type == DriftType.ADDED
        assert entry.hard_stop is True


class TestStatusWarningOnlyTfChanged:
    def test_status_warning_if_only_tf_changed(self):
        """Changing main.tf (not hard stop) results in WARNING status."""
        svc = _svc()
        stored = [_stored("main.tf", "old", False)]
        current = [_current("main.tf", "new", False)]
        report = svc.compare(stored, current)
        assert report.status == DriftStatus.WARNING
        assert report.entries[0].hard_stop is False


class TestStatusCleanNoChanges:
    def test_status_clean_if_no_changes(self):
        """Identical hashes -> CLEAN status."""
        svc = _svc()
        stored = [
            _stored("main.tf", "aaa", False, id=1),
            _stored("variables.tf", "bbb", True, id=2),
            _stored("outputs.tf", "ccc", False, id=3),
        ]
        current = [
            _current("main.tf", "aaa", False),
            _current("variables.tf", "bbb", True),
            _current("outputs.tf", "ccc", False),
        ]
        report = svc.compare(stored, current)
        assert report.status == DriftStatus.CLEAN
        assert report.entries == []


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------


class TestCompareEmptyStoredAllNew:
    def test_compare_empty_stored_all_new(self):
        """Stored is empty, current has files -> all ADDED."""
        svc = _svc()
        stored: list[FileHash] = []
        current = [
            _current("main.tf", "aaa", False),
            _current("outputs.tf", "bbb", False),
        ]
        report = svc.compare(stored, current)
        assert len(report.entries) == 2
        assert all(e.drift_type == DriftType.ADDED for e in report.entries)


class TestCompareEmptyCurrentAllRemoved:
    def test_compare_empty_current_all_removed(self):
        """Current is empty, stored has files -> all REMOVED."""
        svc = _svc()
        stored = [
            _stored("main.tf", "aaa", False, id=1),
            _stored("outputs.tf", "bbb", False, id=2),
        ]
        current: list[FileHashEntry] = []
        report = svc.compare(stored, current)
        assert len(report.entries) == 2
        assert all(e.drift_type == DriftType.REMOVED for e in report.entries)


# ---------------------------------------------------------------------------
# Integration test with real filesystem
# ---------------------------------------------------------------------------


class TestCheckDirectoryIntegration:
    def test_check_directory_integration(self, tmp_path: Path):
        """Creates real files, builds stored hashes, modifies a file, verifies drift."""
        fhs = FileHashService()
        svc = DriftService(file_hash_service=fhs)

        # Create initial files
        (tmp_path / "main.tf").write_text("resource {}")
        (tmp_path / "variables.tf").write_text("variable {}")

        # Scan to get baseline hashes
        baseline = fhs.scan_directory(tmp_path)
        assert len(baseline) == 2

        # Convert baseline to stored FileHash objects (simulating DB records)
        stored = [
            FileHash(
                id=i + 1,
                template_id=1,
                filename=entry.filename,
                hash=entry.hash,
                hard_stop=entry.hard_stop,
            )
            for i, entry in enumerate(baseline)
        ]

        # Modify main.tf
        (tmp_path / "main.tf").write_text("resource { changed = true }")

        # Check drift
        report = svc.check_directory(stored, tmp_path)
        assert report.status == DriftStatus.WARNING
        assert len(report.entries) == 1
        entry = report.entries[0]
        assert entry.filename == "main.tf"
        assert entry.drift_type == DriftType.CHANGED
        assert entry.hard_stop is False
        assert entry.old_hash is not None
        assert entry.new_hash is not None
        assert entry.old_hash != entry.new_hash


# ---------------------------------------------------------------------------
# Hash verification
# ---------------------------------------------------------------------------


class TestDriftEntryHashes:
    def test_drift_entry_hashes(self):
        """Verify old_hash/new_hash are correctly set for each drift type."""
        svc = _svc()
        stored = [
            _stored("changed.tf", "old_hash", False, id=1),
            _stored("removed.tf", "rem_hash", False, id=2),
        ]
        current = [
            _current("changed.tf", "new_hash", False),
            _current("added.tf", "add_hash", False),
        ]
        report = svc.compare(stored, current)
        by_name = {e.filename: e for e in report.entries}

        # CHANGED: both hashes present
        assert by_name["changed.tf"].old_hash == "old_hash"
        assert by_name["changed.tf"].new_hash == "new_hash"

        # REMOVED: only old_hash
        assert by_name["removed.tf"].old_hash == "rem_hash"
        assert by_name["removed.tf"].new_hash is None

        # ADDED: only new_hash
        assert by_name["added.tf"].old_hash is None
        assert by_name["added.tf"].new_hash == "add_hash"


# ---------------------------------------------------------------------------
# Sorting
# ---------------------------------------------------------------------------


class TestEntriesSortedByFilename:
    def test_entries_sorted_by_filename(self):
        """Drift entries are sorted by filename for deterministic output."""
        svc = _svc()
        stored = [
            _stored("z_last.tf", "aaa", False, id=1),
            _stored("a_first.tf", "bbb", False, id=2),
            _stored("m_middle.tf", "ccc", False, id=3),
        ]
        current = [
            _current("z_last.tf", "xxx", False),
            _current("a_first.tf", "yyy", False),
            _current("m_middle.tf", "zzz", False),
        ]
        report = svc.compare(stored, current)
        filenames = [e.filename for e in report.entries]
        assert filenames == ["a_first.tf", "m_middle.tf", "z_last.tf"]
