"""Skeleton tfvars.ui generator.

Combines parsed ``variables.tf`` data (from :mod:`hcl_parser`) with
``terraform.tfvars.example`` data (from :mod:`tfvars_example_parser`) to
produce a skeleton ``tfvars.ui`` file with auto-filled ``@ui-`` annotations.
"""

from __future__ import annotations

from app.services.hcl_parser import HCLVariable, extract_options_from_validation
from app.services.tfvars_example_parser import TfvarsEntry

# Map HCL types to UI widget types
_TYPE_MAP: dict[str, str] = {
    "string": "text",
    "number": "number",
    "bool": "checkbox",
}


def _infer_ui_type(hcl_type: str) -> str:
    """Infer a ``@ui-type`` from an HCL type string."""
    if not hcl_type:
        return "text"
    # Check exact matches first
    if hcl_type in _TYPE_MAP:
        return _TYPE_MAP[hcl_type]
    # Parameterized types
    if hcl_type.startswith("list(") or hcl_type.startswith("set("):
        return "list"
    if hcl_type.startswith("map(") or hcl_type.startswith("object("):
        return "text"
    return "text"


def _format_default(value: str | None) -> str | None:
    """Format a default value for the ``@ui-default`` annotation.

    Returns ``None`` when there is no meaningful default to show.
    """
    if value is None:
        return None
    return value


def generate_scaffold(
    variables: list[HCLVariable],
    example_entries: list[TfvarsEntry] | None = None,
) -> str:
    """Generate a skeleton ``tfvars.ui`` from parsed template data.

    Args:
        variables: Parsed variable blocks from ``variables.tf``.
        example_entries: Parsed entries from ``terraform.tfvars.example``.
            If provided, existing ``@ui-`` annotations and example values are
            preserved. If ``None``, annotations are auto-generated from the
            HCL variable metadata alone.

    Returns:
        A string containing the generated ``tfvars.ui`` content.
    """
    # Index example entries by name for fast lookup
    example_map: dict[str, TfvarsEntry] = {}
    if example_entries:
        for entry in example_entries:
            example_map[entry.name] = entry

    lines: list[str] = []
    current_group = ""

    for var in variables:
        example = example_map.get(var.name)

        # Determine annotations — prefer existing example annotations, fill gaps
        annotations = _build_annotations(var, example)

        # Emit group header if group changed
        group = annotations.get("group", "")
        if group and group != current_group:
            if lines:
                lines.append("")
            lines.append(f"# @ui-group: {group}")
            current_group = group

        # Emit annotations as comments
        for key, value in annotations.items():
            if key == "group":
                continue  # already emitted as group header
            lines.append(f"# @ui-{key}: {value}")

        # Emit the variable assignment
        assign_value = _get_assignment_value(var, example)
        lines.append(f"{var.name} = {assign_value}")
        lines.append("")

    return "\n".join(lines)


def _build_annotations(
    var: HCLVariable,
    example: TfvarsEntry | None,
) -> dict[str, str]:
    """Build the merged annotation dict for a variable.

    Existing annotations from the ``.tfvars.example`` are preserved. Missing
    annotations are auto-generated from the HCL variable metadata.
    """
    annotations: dict[str, str] = {}

    # Start with existing annotations if available
    if example and example.ui_annotations:
        annotations.update(example.ui_annotations)

    # Auto-fill missing annotations from HCL metadata
    if "type" not in annotations:
        ui_type = _infer_ui_type(var.type)
        annotations["type"] = ui_type

    if "label" not in annotations:
        # Convert variable name to a human-readable label
        annotations["label"] = _name_to_label(var.name)

    if "description" not in annotations and var.description:
        annotations["description"] = var.description

    if "required" not in annotations:
        if var.default is None:
            annotations["required"] = "true"

    if "default" not in annotations:
        default_val = _format_default(var.default)
        if default_val is not None:
            annotations["default"] = default_val

    # Auto-generate @options from validation constraints
    if "options" not in annotations and "source" not in annotations:
        options = extract_options_from_validation(var)
        if options:
            annotations["options"] = ", ".join(options)

    if "sensitive" not in annotations and var.sensitive:
        annotations["type"] = "password"

    return annotations


def _name_to_label(name: str) -> str:
    """Convert a snake_case variable name to a Title Case label."""
    return name.replace("_", " ").title()


def _get_assignment_value(
    var: HCLVariable,
    example: TfvarsEntry | None,
) -> str:
    """Determine the value to use in the variable assignment line.

    Prefers the example value if available, otherwise uses the HCL default,
    otherwise uses a type-appropriate placeholder.
    """
    # Use example value if available
    if example:
        return example.value

    # Use HCL default
    if var.default is not None:
        return _format_hcl_value(var.default, var.type)

    # Type-appropriate empty placeholder
    return _empty_placeholder(var.type)


def _format_hcl_value(value: str, hcl_type: str) -> str:
    """Format an HCL default value for use in a tfvars assignment."""
    # If value is already a valid literal (bool, number, list, map), use as-is
    if value in ("true", "false", "null"):
        return value
    if value.startswith("[") or value.startswith("{"):
        return value
    # Numbers
    try:
        float(value)
        return value
    except ValueError:
        pass
    # String — ensure it's quoted
    if not value.startswith('"'):
        return f'"{value}"'
    return f'"{value}"'


def _empty_placeholder(hcl_type: str) -> str:
    """Return a type-appropriate empty placeholder value."""
    if hcl_type == "bool":
        return "false"
    if hcl_type == "number":
        return "0"
    if hcl_type.startswith("list(") or hcl_type.startswith("set("):
        return "[]"
    if hcl_type.startswith("map(") or hcl_type.startswith("object("):
        return "{}"
    return '""'
