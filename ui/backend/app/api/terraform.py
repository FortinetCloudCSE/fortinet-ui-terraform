"""Shared Terraform utilities.

This module provides shared helper functions used by template_terraform.py
for running terraform commands and building environment variables.

The old legacy endpoints (schema, config, build, etc.) that read from the
local terraform/ directory have been removed as part of the template registry
rewrite (FOR-22). All template operations now go through the registry
endpoints in templates.py, tfvars_ui.py, and template_terraform.py.
"""
import asyncio
import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)


def _get_env_for_template(template: str) -> dict:
    """Build environment variables for running terraform commands.

    For GCP templates, injects GOOGLE_CREDENTIALS from session credentials
    so the Terraform google provider can authenticate.
    """
    env = os.environ.copy()

    if template.startswith('gcp/'):
        try:
            from app.api.gcp import _session_credentials
            if _session_credentials:
                import json
                env['GOOGLE_CREDENTIALS'] = json.dumps(_session_credentials)
        except ImportError:
            pass

    return env


async def run_command_stream(command: list, cwd: Path, env: dict = None):
    """
    Run a command and stream output line by line.

    Args:
        command: Command and arguments as list
        cwd: Working directory
        env: Optional environment variables dict

    Yields:
        Tuple of (line, exit_code) where exit_code is None until process completes
    """
    try:
        # Start the process
        process = await asyncio.create_subprocess_exec(
            *command,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            cwd=str(cwd),
            env=env
        )

        # Stream output line by line
        while True:
            line = await process.stdout.readline()
            if not line:
                break
            yield (line.decode('utf-8', errors='replace'), None)

        # Wait for process to complete
        await process.wait()

        # Yield exit code
        yield (f"\n[Exit code: {process.returncode}]\n", process.returncode)

    except Exception as e:
        yield (f"\n[Error: {str(e)}]\n", 1)
