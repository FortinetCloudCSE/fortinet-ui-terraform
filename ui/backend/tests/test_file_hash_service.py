"""Tests for FileHashService."""

from pathlib import Path

from app.services.file_hash_service import FileHashEntry, FileHashService


# ---------------------------------------------------------------------------
# Fixtures (inline — service needs no special setup)
# ---------------------------------------------------------------------------

def _svc() -> FileHashService:
    return FileHashService()


# ---------------------------------------------------------------------------
# compute_file_hash tests
# ---------------------------------------------------------------------------

class TestComputeFileHash:
    def test_compute_file_hash_deterministic(self, tmp_path: Path):
        """Same content always produces the same hash."""
        svc = _svc()
        f = tmp_path / "a.tf"
        f.write_text("resource {}")
        assert svc.compute_file_hash(f) == svc.compute_file_hash(f)

    def test_compute_file_hash_different_content(self, tmp_path: Path):
        """Different content produces different hashes."""
        svc = _svc()
        f1 = tmp_path / "a.tf"
        f2 = tmp_path / "b.tf"
        f1.write_text("resource {}")
        f2.write_text("variable {}")
        assert svc.compute_file_hash(f1) != svc.compute_file_hash(f2)


# ---------------------------------------------------------------------------
# is_hard_stop tests
# ---------------------------------------------------------------------------

class TestIsHardStop:
    def test_is_hard_stop_variables_tf(self):
        assert FileHashService.is_hard_stop("variables.tf") is True

    def test_is_hard_stop_tfvars_example(self):
        assert FileHashService.is_hard_stop("terraform.tfvars.example") is True

    def test_is_hard_stop_tfvars(self):
        assert FileHashService.is_hard_stop("terraform.tfvars") is True

    def test_is_hard_stop_other_tf(self):
        assert FileHashService.is_hard_stop("main.tf") is False


# ---------------------------------------------------------------------------
# scan_directory tests
# ---------------------------------------------------------------------------

class TestScanDirectory:
    def test_scan_directory_basic(self, tmp_path: Path):
        """Directory with a few .tf files returns correct entries."""
        svc = _svc()
        (tmp_path / "main.tf").write_text("resource {}")
        (tmp_path / "variables.tf").write_text("variable {}")
        (tmp_path / "outputs.tf").write_text("output {}")

        entries = svc.scan_directory(tmp_path)
        assert len(entries) == 3
        names = [e.filename for e in entries]
        assert "main.tf" in names
        assert "variables.tf" in names
        assert "outputs.tf" in names

    def test_scan_directory_includes_tfvars_example(self, tmp_path: Path):
        """terraform.tfvars.example is included in scan results."""
        svc = _svc()
        (tmp_path / "terraform.tfvars.example").write_text('cp = "acme"')

        entries = svc.scan_directory(tmp_path)
        assert len(entries) == 1
        assert entries[0].filename == "terraform.tfvars.example"

    def test_scan_directory_includes_tfvars(self, tmp_path: Path):
        """terraform.tfvars is included in scan results."""
        svc = _svc()
        (tmp_path / "terraform.tfvars").write_text('cp = "acme"')

        entries = svc.scan_directory(tmp_path)
        assert len(entries) == 1
        assert entries[0].filename == "terraform.tfvars"

    def test_scan_directory_excludes_non_tf(self, tmp_path: Path):
        """Non-terraform files (.py, .md, .json) are ignored."""
        svc = _svc()
        (tmp_path / "main.tf").write_text("resource {}")
        (tmp_path / "README.md").write_text("# README")
        (tmp_path / "helper.py").write_text("print('hi')")
        (tmp_path / "config.json").write_text("{}")

        entries = svc.scan_directory(tmp_path)
        assert len(entries) == 1
        assert entries[0].filename == "main.tf"

    def test_scan_directory_no_recursion(self, tmp_path: Path):
        """Files inside subdirectories are NOT included."""
        svc = _svc()
        (tmp_path / "main.tf").write_text("resource {}")
        subdir = tmp_path / "modules"
        subdir.mkdir()
        (subdir / "nested.tf").write_text("module {}")

        entries = svc.scan_directory(tmp_path)
        assert len(entries) == 1
        assert entries[0].filename == "main.tf"

    def test_scan_directory_empty(self, tmp_path: Path):
        """Empty directory returns an empty list."""
        svc = _svc()
        entries = svc.scan_directory(tmp_path)
        assert entries == []

    def test_scan_directory_sorted(self, tmp_path: Path):
        """Results are sorted alphabetically by filename."""
        svc = _svc()
        (tmp_path / "z_last.tf").write_text("")
        (tmp_path / "a_first.tf").write_text("")
        (tmp_path / "m_middle.tf").write_text("")

        entries = svc.scan_directory(tmp_path)
        names = [e.filename for e in entries]
        assert names == ["a_first.tf", "m_middle.tf", "z_last.tf"]

    def test_scan_directory_classification(self, tmp_path: Path):
        """Hard-stop flags are set correctly for each file type."""
        svc = _svc()
        (tmp_path / "main.tf").write_text("resource {}")
        (tmp_path / "variables.tf").write_text("variable {}")
        (tmp_path / "terraform.tfvars.example").write_text('cp = "acme"')
        (tmp_path / "terraform.tfvars").write_text('cp = "acme"')
        (tmp_path / "outputs.tf").write_text("output {}")

        entries = svc.scan_directory(tmp_path)
        by_name = {e.filename: e for e in entries}

        # Hard-stop files
        assert by_name["variables.tf"].hard_stop is True
        assert by_name["terraform.tfvars.example"].hard_stop is True
        assert by_name["terraform.tfvars"].hard_stop is True

        # Warning files
        assert by_name["main.tf"].hard_stop is False
        assert by_name["outputs.tf"].hard_stop is False
