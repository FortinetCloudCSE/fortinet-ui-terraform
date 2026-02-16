"""Regex-based HCL variables.tf parser.

Parses Terraform variable blocks from variables.tf files without any external
HCL parsing library. Extracts variable name, description, type, default value,
and validation blocks.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field


@dataclass
class HCLVariable:
    """Represents a single parsed Terraform variable block."""

    name: str
    description: str = ""
    type: str = ""  # raw HCL type string e.g. "string", "bool", "list(string)"
    default: str | None = None  # None = no default (required). "" = empty string default.
    sensitive: bool = False
    validation: list[dict] | None = None  # list of {"condition": str, "error_message": str}


def _find_block_end(content: str, start: int) -> int:
    """Find the closing brace that matches the opening brace at *start*.

    Uses a depth counter and skips braces inside double-quoted strings.
    ``start`` must point to the opening ``{``.

    Returns the index of the matching closing ``}``.
    Raises ``ValueError`` if no matching brace is found.
    """
    depth = 0
    i = start
    in_string = False
    while i < len(content):
        ch = content[i]
        if ch == "\\" and in_string:
            # Skip escaped character inside a string
            i += 2
            continue
        if ch == '"':
            in_string = not in_string
        elif not in_string:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return i
        i += 1
    raise ValueError(f"Unmatched brace starting at position {start}")


def _extract_string_value(text: str) -> str:
    """Extract a double-quoted string value, handling escaped quotes."""
    m = re.match(r'"((?:[^"\\]|\\.)*)"', text.strip())
    if m:
        return m.group(1).replace('\\"', '"')
    return text.strip()


def _extract_description(block: str) -> str:
    """Extract the description field from a variable block."""
    # Match description = "..." potentially spanning multiple lines
    m = re.search(r'description\s*=\s*"((?:[^"\\]|\\.)*)"', block)
    if m:
        return m.group(1).replace('\\"', '"')
    return ""


def _extract_type(block: str) -> str:
    """Extract the type field from a variable block.

    Handles simple types (``string``), parameterized types (``list(string)``),
    and complex types (``object({...})``).
    """
    # Find `type = ` or `type=`
    m = re.search(r'\btype\s*=\s*', block)
    if not m:
        return ""

    rest = block[m.end():]
    rest = rest.lstrip()

    # Simple type: string, number, bool, any
    simple_m = re.match(r'(string|number|bool|any)\b', rest)
    if simple_m:
        return simple_m.group(1)

    # Parameterized or complex type: starts with identifier then '('
    # e.g., list(string), map(string), set(number), object({...}), optional(...)
    ident_m = re.match(r'([a-zA-Z_][a-zA-Z0-9_]*)\s*\(', rest)
    if ident_m:
        # Find the matching closing paren using depth counting
        paren_start = ident_m.start() + len(ident_m.group(0)) - 1  # index of '('
        depth = 0
        in_str = False
        i = paren_start
        while i < len(rest):
            ch = rest[i]
            if ch == "\\" and in_str:
                i += 2
                continue
            if ch == '"':
                in_str = not in_str
            elif not in_str:
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        return rest[: i + 1].strip()
            i += 1
        # If we couldn't match parens, return what we have
        return rest.split("\n")[0].strip()

    return ""


def _extract_default(block: str) -> str | None:
    """Extract the default value from a variable block.

    Returns ``None`` if no default is specified. Returns the raw string
    representation for complex defaults (lists, maps).
    """
    # We need to find `default = ...` but NOT inside a validation block.
    # Strategy: find all `default = ` occurrences and pick the one that's
    # at the top level of the variable block (not inside a nested block).

    # First, strip out validation blocks to avoid false matches
    cleaned = _strip_nested_blocks(block, "validation")
    # Also strip out any lifecycle or other nested blocks
    cleaned = _strip_nested_blocks(cleaned, "lifecycle")

    m = re.search(r'\bdefault\s*=\s*', cleaned)
    if not m:
        return None

    rest = cleaned[m.end():]
    rest = rest.lstrip()

    if not rest:
        return None

    # String value: "..."
    if rest[0] == '"':
        str_m = re.match(r'"((?:[^"\\]|\\.)*)"', rest)
        if str_m:
            return str_m.group(1).replace('\\"', '"')
        return None

    # Boolean or null
    bool_m = re.match(r'(true|false|null)\b', rest)
    if bool_m:
        return bool_m.group(1)

    # Number (int or float, possibly negative)
    num_m = re.match(r'(-?[0-9]+(?:\.[0-9]+)?)\b', rest)
    if num_m:
        return num_m.group(1)

    # List: [...]
    if rest[0] == '[':
        depth = 0
        in_str = False
        for i, ch in enumerate(rest):
            if ch == "\\" and in_str:
                continue
            if ch == '"':
                in_str = not in_str
            elif not in_str:
                if ch == '[':
                    depth += 1
                elif ch == ']':
                    depth -= 1
                    if depth == 0:
                        return rest[: i + 1].strip()

    # Map/object: {...}
    if rest[0] == '{':
        depth = 0
        in_str = False
        for i, ch in enumerate(rest):
            if ch == "\\" and in_str:
                continue
            if ch == '"':
                in_str = not in_str
            elif not in_str:
                if ch == '{':
                    depth += 1
                elif ch == '}':
                    depth -= 1
                    if depth == 0:
                        return rest[: i + 1].strip()

    return None


def _strip_nested_blocks(block: str, block_name: str) -> str:
    """Remove all named nested blocks (e.g. ``validation { ... }``) from text."""
    result = block
    while True:
        m = re.search(rf'\b{block_name}\s*\{{', result)
        if not m:
            break
        brace_pos = result.index("{", m.start())
        try:
            end_pos = _find_block_end(result, brace_pos)
            result = result[:m.start()] + result[end_pos + 1:]
        except ValueError:
            break
    return result


def _extract_sensitive(block: str) -> bool:
    """Extract the sensitive field from a variable block."""
    m = re.search(r'\bsensitive\s*=\s*(true|false)\b', block)
    if m:
        return m.group(1) == "true"
    return False


def _extract_validations(block: str) -> list[dict] | None:
    """Extract all validation blocks from a variable block.

    Returns a list of dicts with ``condition`` and ``error_message`` keys,
    or ``None`` if no validation blocks are present.
    """
    validations: list[dict] = []

    search_from = 0
    while True:
        m = re.search(r'\bvalidation\s*\{', block[search_from:])
        if not m:
            break

        brace_pos = block.index("{", search_from + m.start())
        try:
            end_pos = _find_block_end(block, brace_pos)
        except ValueError:
            break

        validation_body = block[brace_pos + 1: end_pos]

        # Extract condition: everything after `condition = ` up to the next
        # top-level attribute or end of block. The condition can span multiple
        # lines.
        cond_m = re.search(r'\bcondition\s*=\s*', validation_body)
        error_m = re.search(r'\berror_message\s*=\s*', validation_body)

        condition = ""
        error_message = ""

        if cond_m:
            cond_rest = validation_body[cond_m.end():]
            # Condition ends at the next top-level attribute (error_message)
            # or at the end of the block
            # Find where the condition value ends
            if error_m and error_m.start() > cond_m.start():
                # condition is before error_message
                cond_text = validation_body[cond_m.end(): error_m.start()]
            else:
                cond_text = cond_rest
            condition = cond_text.strip().rstrip("\n").strip()

        if error_m:
            err_rest = validation_body[error_m.end():]
            err_str_m = re.match(r'\s*"((?:[^"\\]|\\.)*)"', err_rest)
            if err_str_m:
                error_message = err_str_m.group(1).replace('\\"', '"')

        if condition or error_message:
            validations.append({
                "condition": condition,
                "error_message": error_message,
            })

        search_from = end_pos + 1

    return validations if validations else None


def parse_variables(content: str) -> list[HCLVariable]:
    """Parse all variable blocks from a variables.tf file.

    Args:
        content: Full text content of a variables.tf file.

    Returns:
        List of ``HCLVariable`` objects, one per variable block found.
    """
    variables: list[HCLVariable] = []

    # Match `variable "name" {` or `variable name {` (optional quotes)
    pattern = re.compile(r'\bvariable\s+"?([a-zA-Z_][a-zA-Z0-9_]*)"?\s*\{')

    for m in pattern.finditer(content):
        var_name = m.group(1)
        brace_pos = content.index("{", m.start())
        try:
            end_pos = _find_block_end(content, brace_pos)
        except ValueError:
            continue

        block = content[brace_pos + 1: end_pos]

        description = _extract_description(block)
        var_type = _extract_type(block)
        default = _extract_default(block)
        sensitive = _extract_sensitive(block)
        validation = _extract_validations(block)

        variables.append(HCLVariable(
            name=var_name,
            description=description,
            type=var_type,
            default=default,
            sensitive=sensitive,
            validation=validation,
        ))

    return variables


def extract_options_from_validation(variable: HCLVariable) -> list[str] | None:
    """Try to extract allowed values from a variable's validation conditions.

    Recognizes patterns like ``contains(["a", "b", "c"], var.x)`` and
    returns ``["a", "b", "c"]``. Returns ``None`` if the pattern is not
    recognized.
    """
    if not variable.validation:
        return None

    for v in variable.validation:
        condition = v.get("condition", "")
        # Match: contains(["val1", "val2", ...], var.name)
        contains_m = re.search(
            r'contains\s*\(\s*\[([^\]]*)\]\s*,\s*var\.\w+\s*\)',
            condition,
        )
        if contains_m:
            raw_list = contains_m.group(1)
            # Extract quoted strings from the list
            options = re.findall(r'"([^"]*)"', raw_list)
            if options:
                return options

    return None
