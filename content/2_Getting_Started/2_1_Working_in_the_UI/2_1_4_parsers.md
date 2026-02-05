---
title: "Writing Parsers"
menuTitle: "Parsers"
weight: 4
---

Template parsing and annotation extraction.

## Template Parser

The parser reads `terraform.tfvars.example` and extracts annotated variables.

Location: `backend/parsers/tfvars.py`

Key functions:

```python
def parse_tfvars_example(template_path: str) -> List[Variable]:
    """Parse a terraform.tfvars.example file and return variables."""
    # Read file
    # Extract annotations
    # Return structured variable list

def extract_annotations(lines: List[str]) -> dict:
    """Extract @annotation tags from comment lines."""
    annotations = {}
    for line in lines:
        if line.strip().startswith("# @"):
            key, value = parse_annotation(line)
            annotations[key] = value
    return annotations
```

---

## Adding New Annotation Types

To support a new annotation like `@min` and `@max` for number fields:

1. Update the parser to extract the annotation:

```python
# In extract_annotations()
if key == "min":
    annotations["min"] = int(value)
if key == "max":
    annotations["max"] = int(value)
```

2. Update the frontend component to use the new metadata:

```jsx
// In NumberInput component
<input
  type="number"
  min={field.min}
  max={field.max}
  ...
/>
```

