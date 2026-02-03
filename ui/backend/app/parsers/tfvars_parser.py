"""Parser for annotated Terraform tfvars.example files."""
import re
from typing import Dict, List, Any, Optional
from pathlib import Path
import logging

logger = logging.getLogger(__name__)


class TFVarsParser:
    """
    Parser for Terraform tfvars files with @ui-* annotations.

    Reads terraform.tfvars.example files and extracts UI metadata from comments
    to generate a JSON schema for dynamic form rendering.
    """

    def __init__(self, tfvars_path: str | Path):
        """
        Initialize parser with path to tfvars.example file.

        Args:
            tfvars_path: Path to terraform.tfvars.example file
        """
        self.tfvars_path = Path(tfvars_path)
        if not self.tfvars_path.exists():
            raise FileNotFoundError(f"File not found: {tfvars_path}")

        self.lines = self.tfvars_path.read_text().splitlines()
        self.current_line = 0

    def parse(self) -> Dict[str, Any]:
        """
        Parse the entire tfvars file and return schema.

        Returns:
            Schema dict with groups and fields
        """
        groups = []
        current_group = None
        current_field_annotations = {}

        i = 0
        while i < len(self.lines):
            line = self.lines[i].strip()

            # Skip empty lines and non-annotation comments
            if not line or (line.startswith('#') and not line.startswith('# @ui-')):
                # Check if this is a group separator
                if line.startswith('#==='):
                    # Look ahead for group annotations
                    group_data = self._parse_group(i)
                    if group_data:
                        # Save previous group if exists
                        if current_group:
                            groups.append(current_group)
                        current_group = group_data
                        i = group_data.get('_end_line', i)
                        # Don't increment i here, continue from _end_line
                        continue
                i += 1
                continue

            # Parse annotation
            if line.startswith('# @ui-'):
                annotation = self._parse_annotation(line)
                if annotation:
                    key, value = annotation
                    current_field_annotations[key] = value
                i += 1
                continue

            # Parse variable assignment
            if '=' in line and not line.startswith('#'):
                field = self._parse_field(line, current_field_annotations)
                if field and current_group:
                    if 'fields' not in current_group:
                        current_group['fields'] = []
                    current_group['fields'].append(field)

                # Reset annotations for next field
                current_field_annotations = {}
                i += 1
                continue

            i += 1

        # Add last group
        if current_group:
            groups.append(current_group)

        # Sort groups by order field (default to 999 if not specified)
        groups.sort(key=lambda g: g.get('order', 999))

        return {
            "groups": groups,
            "metadata": {
                "source_file": str(self.tfvars_path),
                "total_groups": len(groups),
                "total_fields": sum(len(g.get('fields', [])) for g in groups)
            }
        }

    def _parse_group(self, start_line: int) -> Optional[Dict[str, Any]]:
        """
        Parse group-level annotations.

        Args:
            start_line: Line number where group separator starts

        Returns:
            Group dict or None
        """
        group_data = {}
        i = start_line + 1

        # Parse group annotations
        while i < len(self.lines):
            line = self.lines[i].strip()

            # End of group annotations
            if line.startswith('#===') or (line and not line.startswith('#')):
                break

            if line.startswith('# @ui-'):
                annotation = self._parse_annotation(line)
                if annotation:
                    key, value = annotation

                    # Map annotation keys to group fields
                    if key == 'group':
                        group_data['name'] = value
                    elif key == 'description':
                        group_data['description'] = value
                    elif key == 'order':
                        group_data['order'] = int(value)
                    elif key == 'show-if':
                        group_data['show_if'] = value
                    else:
                        # This is a field-level annotation, not a group annotation
                        # Stop parsing group annotations here
                        break

            i += 1

        if group_data.get('name'):
            group_data['_end_line'] = i
            return group_data

        return None

    def _parse_annotation(self, line: str) -> Optional[tuple[str, str]]:
        """
        Parse a single @ui-* annotation.

        Args:
            line: Comment line with annotation

        Returns:
            Tuple of (key, value) or None
        """
        # Pattern: # @ui-key: value
        match = re.match(r'#\s*@ui-([a-z-]+):\s*(.+)', line)
        if match:
            key = match.group(1)
            value = match.group(2).strip()
            return (key, value)

        return None

    def _parse_field(self, line: str, annotations: Dict[str, str]) -> Optional[Dict[str, Any]]:
        """
        Parse variable assignment and combine with annotations.

        Args:
            line: Variable assignment line (e.g., 'aws_region = "us-west-1"')
            annotations: Dict of annotations for this field

        Returns:
            Field dict or None
        """
        # Parse variable name and default value
        match = re.match(r'(\w+)\s*=\s*(.+)', line)
        if not match:
            return None

        var_name = match.group(1)
        default_value = match.group(2).strip()

        # Remove quotes and parse value
        default_value = self._parse_value(default_value)

        # Build field dict from annotations
        field = {
            'name': var_name,
            'default_value': default_value
        }

        # Map annotations to field properties
        type_map = {
            'type': 'type',
            'source': 'source',
            'label': 'label',
            'description': 'description',
            'required': lambda v: v.lower() == 'true',
            'width': 'width',
            'help': 'help',
            'placeholder': 'placeholder',
            'pattern': 'pattern',
            'options': 'options',
            'depends-on': 'depends_on',
            'show-if': 'show_if',
            'hide-if': 'hide_if',
            'validation': lambda v: [rule.strip() for rule in v.split(',')],
            'default': 'default_override',
            'link': 'link',
            'compute': 'compute',
            'exclusive-with': 'exclusive_with',
        }

        for anno_key, anno_value in annotations.items():
            if anno_key in type_map:
                field_key = type_map[anno_key]
                if callable(field_key):
                    # Transform value
                    field[anno_key.replace('-', '_')] = field_key(anno_value)
                elif isinstance(field_key, str):
                    # Direct mapping
                    field[field_key] = anno_value

        # Use default override if specified in annotations
        if 'default_override' in field:
            field['default_value'] = self._parse_value(field['default_override'])
            del field['default_override']

        # Ensure required fields exist
        if 'type' not in field:
            logger.warning(f"Field {var_name} missing @ui-type annotation")
            return None

        return field

    def _parse_value(self, value: str) -> Any:
        """
        Parse default value from tfvars format.

        Args:
            value: Raw value string from tfvars

        Returns:
            Parsed Python value
        """
        value = value.strip()

        # Remove trailing comments
        if '#' in value:
            value = value.split('#')[0].strip()

        # Boolean
        if value.lower() in ('true', 'false'):
            return value.lower() == 'true'

        # Number
        if value.isdigit() or (value.startswith('-') and value[1:].isdigit()):
            return int(value)

        # Float
        try:
            return float(value)
        except ValueError:
            pass

        # String (remove quotes)
        if (value.startswith('"') and value.endswith('"')) or \
           (value.startswith("'") and value.endswith("'")):
            return value[1:-1]

        # List (basic parsing)
        if value.startswith('[') and value.endswith(']'):
            # Simple list parsing - just return as string for now
            return value

        # Map/object (basic parsing)
        if value.startswith('{') and value.endswith('}'):
            return value

        # Return as-is
        return value


def parse_tfvars_file(tfvars_path: str | Path) -> Dict[str, Any]:
    """
    Convenience function to parse a tfvars file.

    Args:
        tfvars_path: Path to terraform.tfvars.example file

    Returns:
        Schema dict
    """
    parser = TFVarsParser(tfvars_path)
    return parser.parse()


# Example usage
if __name__ == "__main__":
    import json
    from pathlib import Path

    # Example: Parse existing_vpc_resources tfvars
    repo_root = Path(__file__).parent.parent.parent.parent.parent
    tfvars_path = repo_root / "terraform" / "existing_vpc_resources" / "terraform.tfvars.example"

    if tfvars_path.exists():
        schema = parse_tfvars_file(tfvars_path)
        print(json.dumps(schema, indent=2))
    else:
        print(f"File not found: {tfvars_path}")
