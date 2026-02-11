"""Git clone/pull service for managing template repository clones."""

import asyncio
import hashlib
import logging
import shutil
import time
from pathlib import Path

logger = logging.getLogger(__name__)


class GitError(Exception):
    """Raised when a git command fails."""

    def __init__(self, message: str, returncode: int = 1, stderr: str = ""):
        self.message = message
        self.returncode = returncode
        self.stderr = stderr
        super().__init__(message)


class GitService:
    """Manages git clones of template repositories."""

    def __init__(self, clone_dir: Path):
        self.clone_dir = clone_dir

    @staticmethod
    def _url_hash(repo_url: str) -> str:
        """Return first 12 hex chars of SHA-256 of the repo URL."""
        return hashlib.sha256(repo_url.encode()).hexdigest()[:12]

    def _clone_path(self, repo_url: str) -> Path:
        """Return the local clone directory for a repo URL."""
        return self.clone_dir / self._url_hash(repo_url)

    @staticmethod
    def _is_git_repo(path: Path) -> bool:
        """Check whether path contains a .git directory."""
        return (path / ".git").is_dir()

    async def _run_git(self, *args: str, cwd: Path | None = None) -> str:
        """Run a git command and return stdout. Raises GitError on failure."""
        process = await asyncio.create_subprocess_exec(
            "git",
            *args,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=str(cwd) if cwd else None,
        )
        stdout_bytes, stderr_bytes = await process.communicate()
        stdout = stdout_bytes.decode().strip()
        stderr = stderr_bytes.decode().strip()

        if process.returncode != 0:
            cmd_str = f"git {' '.join(args)}"
            raise GitError(
                message=f"Command failed: {cmd_str}",
                returncode=process.returncode,
                stderr=stderr,
            )
        return stdout

    async def clone_or_pull(self, repo_url: str, branch: str = "main") -> Path:
        """Clone a repo if new, or fetch+reset if it already exists.

        Returns the path to the clone root directory.
        """
        dest = self._clone_path(repo_url)

        # Ensure clone_dir exists
        self.clone_dir.mkdir(parents=True, exist_ok=True)

        if dest.exists():
            if self._is_git_repo(dest):
                # Existing valid clone — update it
                logger.info("Updating existing clone: %s", dest)
                await self._run_git("fetch", "origin", cwd=dest)
                await self._run_git("checkout", branch, cwd=dest)
                await self._run_git("reset", "--hard", f"origin/{branch}", cwd=dest)
                return dest
            else:
                # Directory exists but not a git repo — remove and re-clone
                logger.warning("Corrupted clone at %s, removing", dest)
                shutil.rmtree(dest)

        # Fresh clone
        logger.info("Cloning %s (branch=%s) into %s", repo_url, branch, dest)
        await self._run_git(
            "clone", "--branch", branch, "--single-branch", repo_url, str(dest)
        )
        return dest

    def get_template_dir(self, repo_url: str, repo_path: str = "") -> Path:
        """Return the full path to a template directory within a clone.

        Args:
            repo_url: The repository URL (used to locate the clone).
            repo_path: Relative path within the repo to the template directory.

        Returns:
            Path to the template directory.

        Raises:
            FileNotFoundError: If the clone doesn't exist or repo_path is invalid.
        """
        clone_root = self._clone_path(repo_url)
        if not clone_root.exists():
            raise FileNotFoundError(f"Clone not found for {repo_url}")

        if not repo_path:
            return clone_root

        template_dir = clone_root / repo_path
        if not template_dir.is_dir():
            raise FileNotFoundError(
                f"Template path '{repo_path}' not found in clone of {repo_url}"
            )
        return template_dir

    def cleanup_clone(self, repo_url: str) -> bool:
        """Remove a clone directory. Returns True if removed, False if not found."""
        dest = self._clone_path(repo_url)
        if dest.exists():
            shutil.rmtree(dest)
            logger.info("Removed clone: %s", dest)
            return True
        return False

    def cleanup_stale(self, max_age_days: int = 30) -> int:
        """Remove clone directories older than max_age_days. Returns count removed."""
        if not self.clone_dir.exists():
            return 0

        cutoff = time.time() - (max_age_days * 86400)
        removed = 0

        for entry in self.clone_dir.iterdir():
            if entry.is_dir() and entry.stat().st_mtime < cutoff:
                shutil.rmtree(entry)
                logger.info("Removed stale clone: %s", entry)
                removed += 1

        return removed
