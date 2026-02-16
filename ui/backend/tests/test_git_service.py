"""Tests for GitService."""

import os
import time
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest

from app.services.git_service import GitError, GitService


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def clone_dir(tmp_path: Path) -> Path:
    """Provide a temporary clone directory."""
    return tmp_path / "clones"


@pytest.fixture
def svc(clone_dir: Path) -> GitService:
    """Provide a GitService instance backed by tmp_path."""
    return GitService(clone_dir=clone_dir)


REPO_URL = "https://github.com/example/templates.git"
OTHER_URL = "https://github.com/other/repo.git"


def _mock_process(stdout: str = "", stderr: str = "", returncode: int = 0):
    """Create a mock process that returns the given stdout/stderr/rc."""
    proc = AsyncMock()
    proc.communicate.return_value = (
        stdout.encode(),
        stderr.encode(),
    )
    proc.returncode = returncode
    return proc


# ---------------------------------------------------------------------------
# _url_hash tests
# ---------------------------------------------------------------------------

class TestUrlHash:
    def test_deterministic(self, svc: GitService):
        assert svc._url_hash(REPO_URL) == svc._url_hash(REPO_URL)

    def test_different_urls(self, svc: GitService):
        assert svc._url_hash(REPO_URL) != svc._url_hash(OTHER_URL)

    def test_length(self, svc: GitService):
        assert len(svc._url_hash(REPO_URL)) == 12


# ---------------------------------------------------------------------------
# _run_git tests
# ---------------------------------------------------------------------------

class TestRunGit:
    async def test_success(self, svc: GitService):
        proc = _mock_process(stdout="ok\n")
        with patch("asyncio.create_subprocess_exec", return_value=proc):
            result = await svc._run_git("status")
        assert result == "ok"

    async def test_failure(self, svc: GitService):
        proc = _mock_process(stderr="fatal: not a repo", returncode=128)
        with patch("asyncio.create_subprocess_exec", return_value=proc):
            with pytest.raises(GitError) as exc_info:
                await svc._run_git("status")
            assert exc_info.value.returncode == 128
            assert "fatal: not a repo" in exc_info.value.stderr


# ---------------------------------------------------------------------------
# clone_or_pull tests
# ---------------------------------------------------------------------------

class TestCloneOrPull:
    async def test_clone_fresh(self, svc: GitService, clone_dir: Path):
        """Fresh clone runs git clone with correct args."""
        proc = _mock_process()
        with patch("asyncio.create_subprocess_exec", return_value=proc) as mock_exec:
            result = await svc.clone_or_pull(REPO_URL)

        assert result == svc._clone_path(REPO_URL)
        # Verify git clone was called
        mock_exec.assert_called_once()
        call_args = mock_exec.call_args[0]
        assert call_args[0] == "git"
        assert call_args[1] == "clone"
        assert "--single-branch" in call_args
        assert REPO_URL in call_args

    async def test_clone_creates_clone_dir(self, svc: GitService, clone_dir: Path):
        """clone_dir is created if it doesn't exist."""
        assert not clone_dir.exists()
        proc = _mock_process()
        with patch("asyncio.create_subprocess_exec", return_value=proc):
            await svc.clone_or_pull(REPO_URL)
        assert clone_dir.exists()

    async def test_clone_custom_branch(self, svc: GitService):
        """Uses specified branch in clone command."""
        proc = _mock_process()
        with patch("asyncio.create_subprocess_exec", return_value=proc) as mock_exec:
            await svc.clone_or_pull(REPO_URL, branch="develop")

        call_args = mock_exec.call_args[0]
        assert "--branch" in call_args
        branch_idx = list(call_args).index("--branch")
        assert call_args[branch_idx + 1] == "develop"

    async def test_pull_existing(self, svc: GitService):
        """Runs fetch → checkout → reset when .git/ exists."""
        dest = svc._clone_path(REPO_URL)
        dest.mkdir(parents=True)
        (dest / ".git").mkdir()

        calls = []
        async def fake_exec(*args, **kwargs):
            calls.append(args)
            return _mock_process()

        with patch("asyncio.create_subprocess_exec", side_effect=fake_exec):
            result = await svc.clone_or_pull(REPO_URL)

        assert result == dest
        # Should be 3 calls: fetch, checkout, reset
        assert len(calls) == 3
        assert calls[0][1] == "fetch"
        assert calls[1][1] == "checkout"
        assert calls[2][1] == "reset"

    async def test_pull_corrupted_clone(self, svc: GitService):
        """Removes dir and re-clones if no .git/."""
        dest = svc._clone_path(REPO_URL)
        dest.mkdir(parents=True)
        # No .git directory — corrupted

        proc = _mock_process()
        with patch("asyncio.create_subprocess_exec", return_value=proc) as mock_exec:
            await svc.clone_or_pull(REPO_URL)

        # Should have called git clone (not fetch)
        call_args = mock_exec.call_args[0]
        assert call_args[1] == "clone"

    async def test_clone_bad_url(self, svc: GitService):
        """Raises GitError on clone failure."""
        proc = _mock_process(stderr="fatal: repo not found", returncode=128)
        with patch("asyncio.create_subprocess_exec", return_value=proc):
            with pytest.raises(GitError) as exc_info:
                await svc.clone_or_pull("https://bad.url/repo.git")
            assert exc_info.value.returncode == 128

    async def test_clone_network_error(self, svc: GitService):
        """Raises GitError on network failure."""
        proc = _mock_process(
            stderr="fatal: unable to access", returncode=128
        )
        with patch("asyncio.create_subprocess_exec", return_value=proc):
            with pytest.raises(GitError) as exc_info:
                await svc.clone_or_pull(REPO_URL)
            assert "unable to access" in exc_info.value.stderr

    async def test_pull_fetch_fails(self, svc: GitService):
        """Raises GitError when fetch fails on existing clone."""
        dest = svc._clone_path(REPO_URL)
        dest.mkdir(parents=True)
        (dest / ".git").mkdir()

        proc = _mock_process(stderr="fatal: could not read from remote", returncode=128)
        with patch("asyncio.create_subprocess_exec", return_value=proc):
            with pytest.raises(GitError):
                await svc.clone_or_pull(REPO_URL)


# ---------------------------------------------------------------------------
# get_template_dir tests
# ---------------------------------------------------------------------------

class TestGetTemplateDir:
    def test_success(self, svc: GitService):
        dest = svc._clone_path(REPO_URL)
        dest.mkdir(parents=True)
        subdir = dest / "templates" / "vpc"
        subdir.mkdir(parents=True)

        result = svc.get_template_dir(REPO_URL, "templates/vpc")
        assert result == subdir

    def test_empty_repo_path(self, svc: GitService):
        """Returns clone root when repo_path is empty."""
        dest = svc._clone_path(REPO_URL)
        dest.mkdir(parents=True)

        result = svc.get_template_dir(REPO_URL, "")
        assert result == dest

    def test_not_cloned(self, svc: GitService):
        """Raises FileNotFoundError if clone doesn't exist."""
        with pytest.raises(FileNotFoundError, match="Clone not found"):
            svc.get_template_dir(REPO_URL, "some/path")

    def test_bad_repo_path(self, svc: GitService):
        """Raises FileNotFoundError for invalid path within clone."""
        dest = svc._clone_path(REPO_URL)
        dest.mkdir(parents=True)

        with pytest.raises(FileNotFoundError, match="not found in clone"):
            svc.get_template_dir(REPO_URL, "nonexistent/path")


# ---------------------------------------------------------------------------
# cleanup_clone tests
# ---------------------------------------------------------------------------

class TestCleanupClone:
    def test_exists(self, svc: GitService):
        dest = svc._clone_path(REPO_URL)
        dest.mkdir(parents=True)
        (dest / "somefile").touch()

        assert svc.cleanup_clone(REPO_URL) is True
        assert not dest.exists()

    def test_not_exists(self, svc: GitService):
        assert svc.cleanup_clone(REPO_URL) is False


# ---------------------------------------------------------------------------
# cleanup_stale tests
# ---------------------------------------------------------------------------

class TestCleanupStale:
    def test_removes_old(self, svc: GitService, clone_dir: Path):
        clone_dir.mkdir(parents=True)
        old_dir = clone_dir / "oldrepo"
        old_dir.mkdir()
        # Set mtime to 60 days ago
        old_time = time.time() - (60 * 86400)
        os.utime(old_dir, (old_time, old_time))

        assert svc.cleanup_stale(max_age_days=30) == 1
        assert not old_dir.exists()

    def test_keeps_recent(self, svc: GitService, clone_dir: Path):
        clone_dir.mkdir(parents=True)
        recent_dir = clone_dir / "recentrepo"
        recent_dir.mkdir()

        assert svc.cleanup_stale(max_age_days=30) == 0
        assert recent_dir.exists()

    def test_no_clone_dir(self, svc: GitService):
        """Returns 0 when clone_dir doesn't exist."""
        assert svc.cleanup_stale() == 0
