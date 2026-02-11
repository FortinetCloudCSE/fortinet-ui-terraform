"""Parser for terraform.tfvars.example files.

Extracts variable assignments, UI annotation comments (``# @ui-*`` tags),
section/group comments, and plain comments associated with each variable.
Designed for the template registry system to produce ``TfvarsEntry`` objects
that can be combined with ``HCLVariable`` data to generate skeleton
``tfvars.ui`` files.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field


@dataclass
class TfvarsEntry:
    """Represents a single variable assignment parsed from a tfvars.example file."""

    name: str  # Variable name
    value: str  # Raw value string as written in file (e.g. '"us-west-1"', 'true', '8')
    comments: list[str] = field(default_factory=list)  # Plain (non-annotation) comment lines
    ui_annotations: dict[str, str] = field(default_factory=dict)  # @ui-key -> value


# Regex for a variable assignment line.  Captures:
#   group 1: variable name
#   group 2: everything after '=' up to an optional inline comment
_ASSIGNMENT_RE = re.compile(
    r"^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+?)$"
)

# Regex for a UI annotation comment: ``# @ui-<key>: <value>``
_UI_ANNOTATION_RE = re.compile(
    r"^#\s*@ui-([a-zA-Z_][a-zA-Z0-9_-]*)\s*:\s*(.*)$"
)


def _extract_value(raw: str) -> str:
    """Extract the variable value, stripping any trailing inline comment.

    Handles quoted strings (preserving the content between quotes), booleans,
    numbers, and list/map literals.
    """
    raw = raw.strip()

    # Quoted string: find the closing quote, ignoring escaped quotes
    if raw.startswith('"'):
        i = 1
        while i < len(raw):
            ch = raw[i]
            if ch == "\\" and i + 1 < len(raw):
                i += 2
                continue
            if ch == '"':
                # Return the full quoted value including quotes
                return raw[: i + 1]
            i += 1
        # No closing quote found — return as-is
        return raw

    # List literal: find matching ']'
    if raw.startswith("["):
        depth = 0
        in_str = False
        for i, ch in enumerate(raw):
            if ch == "\\" and in_str:
                continue
            if ch == '"':
                in_str = not in_str
            elif not in_str:
                if ch == "[":
                    depth += 1
                elif ch == "]":
                    depth -= 1
                    if depth == 0:
                        return raw[: i + 1]
        return raw

    # Map/object literal: find matching '}'
    if raw.startswith("{"):
        depth = 0
        in_str = False
        for i, ch in enumerate(raw):
            if ch == "\\" and in_str:
                continue
            if ch == '"':
                in_str = not in_str
            elif not in_str:
                if ch == "{":
                    depth += 1
                elif ch == "}":
                    depth -= 1
                    if depth == 0:
                        return raw[: i + 1]
        return raw

    # Unquoted value (bool, number, identifier): take the first token,
    # stripping any trailing inline comment.
    token_match = re.match(r"(\S+)", raw)
    if token_match:
        return token_match.group(1)

    return raw


def parse_tfvars_example(content: str) -> list[TfvarsEntry]:
    """Parse a ``terraform.tfvars.example`` file into a list of ``TfvarsEntry``.

    Args:
        content: Full text content of a terraform.tfvars.example file.

    Returns:
        List of ``TfvarsEntry`` objects, one per variable assignment found.
    """
    entries: list[TfvarsEntry] = []
    comment_buffer: list[str] = []
    current_group: str = ""

    for line in content.splitlines():
        stripped = line.strip()

        # Blank line: check accumulated comments for group-level annotations,
        # then clear the buffer.
        if not stripped:
            for cline in comment_buffer:
                m = _UI_ANNOTATION_RE.match(cline.strip())
                if m and m.group(1) == "group":
                    current_group = m.group(2).strip()
            comment_buffer.clear()
            continue

        # Comment line: accumulate
        if stripped.startswith("#"):
            comment_buffer.append(stripped)
            continue

        # Try to match a variable assignment
        m = _ASSIGNMENT_RE.match(stripped)
        if m:
            var_name = m.group(1)
            raw_value = m.group(2)
            value = _extract_value(raw_value)

            # Extract UI annotations and plain comments from the buffer
            ui_annotations: dict[str, str] = {}
            plain_comments: list[str] = []

            for cline in comment_buffer:
                ann = _UI_ANNOTATION_RE.match(cline.strip())
                if ann:
                    key = ann.group(1).strip()
                    val = ann.group(2).strip()
                    ui_annotations[key] = val
                else:
                    plain_comments.append(cline)

            # Attach current group if not already specified in annotations
            if current_group and "group" not in ui_annotations:
                ui_annotations["group"] = current_group

            entries.append(TfvarsEntry(
                name=var_name,
                value=value,
                comments=plain_comments,
                ui_annotations=ui_annotations,
            ))

            comment_buffer.clear()
            continue

        # Any other non-blank, non-comment line: treat as unknown, clear buffer
        comment_buffer.clear()

    return entries
