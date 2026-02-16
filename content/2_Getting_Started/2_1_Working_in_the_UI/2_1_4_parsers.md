---
title: "Parsers & Services"
menuTitle: "Parsers & Services"
weight: 4
---

The backend uses a service layer for parsing, hashing, scaffolding, and drift detection.

## Service Layer

```
app/services/
├── __init__.py                 # Central exports
├── hcl_parser.py               # Parse variables.tf
├── tfvars_example_parser.py    # Parse terraform.tfvars.example annotations
├── scaffold_generator.py       # Generate tfvars.ui from parsed data
├── git_service.py              # Clone/pull git repositories
├── file_hash_service.py        # SHA-256 file scanning
└── drift_service.py            # Drift detection between stored and current hashes
```

---

## HCL Parser (`hcl_parser.py`)

Parses `variables.tf` to extract variable definitions.

```python
from app.services import parse_variables, HCLVariable

variables: list[HCLVariable] = parse_variables(content)
```

Each `HCLVariable` contains:
- `name` — Variable name
- `type` — HCL type string (e.g., `string`, `number`, `bool`, `list(string)`)
- `description` — Variable description
- `default` — Default value (if any)
- `validation` — Validation rules (condition + error_message)

---

## Terraform.tfvars.example Parser (`tfvars_example_parser.py`)

Parses `terraform.tfvars.example` files to extract annotations and variable assignments.

```python
from app.services import parse_tfvars_example, TfvarsEntry

entries: list[TfvarsEntry] = parse_tfvars_example(content)
```

Each `TfvarsEntry` contains:
- `name` — Variable name
- `value` — Assigned value (string)
- `hcl_type` — Inferred type
- `comments` — Plain comments above the variable
- `annotations` — Dict of `@ui-` annotations (e.g., `{"ui-label": "AWS Region", "ui-type": "select"}`)
- `group` — Group name from `@ui-group`

---

## Scaffold Generator (`scaffold_generator.py`)

Merges HCL variable definitions with existing annotations to produce a `tfvars.ui` file.

```python
from app.services import generate_scaffold

content: str = generate_scaffold(variables, example_entries)
```

The generator:
1. Auto-infers `@ui-type` from HCL type (`string` → `text`, `bool` → `checkbox`, etc.)
2. Converts variable names to labels (`enable_jump_box` → `Enable Jump Box`)
3. Extracts `@ui-options` from HCL validation rules
4. Preserves existing `@ui-` annotations from `terraform.tfvars.example`
5. Groups variables by common prefix when `@ui-group` is present in example

---

## Git Service (`git_service.py`)

Manages cloned template repositories.

```python
from app.services import GitService

git = GitService(clone_dir=Path("data/clones"))

# Clone or update a repository
clone_path = await git.clone_or_pull("https://github.com/org/repo.git", branch="main")

# Get template subdirectory within clone
template_dir = git.get_template_dir("https://github.com/org/repo.git", "terraform/aws/template")

# Clean up
removed = await git.cleanup_clone("https://github.com/org/repo.git")
count = await git.cleanup_stale(max_age_days=30)
```

Clone directories are named by first 12 chars of SHA-256 hash of the repo URL.

---

## File Hash Service (`file_hash_service.py`)

Scans directories and computes SHA-256 hashes for drift detection.

```python
from app.services import FileHashService, FileHashEntry

service = FileHashService()

# Scan a directory
entries: list[FileHashEntry] = service.scan_directory(template_dir)
```

Each `FileHashEntry` contains:
- `filename` — Relative file path
- `hash` — SHA-256 hex digest
- `hard_stop` — Whether changes to this file block terraform execution

**Hard-stop file patterns:** `*.tf`, `*.cfg`, `*.tpl`, `*.tftpl`, `terraform.tfvars`, `terraform.tfvars.example`

---

## Drift Service (`drift_service.py`)

Compares stored file hashes against current filesystem state.

```python
from app.services import DriftService, DriftStatus, DriftType

drift = DriftService(file_hash_service=FileHashService())
report = drift.compare(stored_hashes, current_entries)

# report.status: DriftStatus.CLEAN | .WARNING | .HARD_STOP
# report.entries: list[DriftEntry] with filename, drift_type, hard_stop, old_hash, new_hash
```

**Drift types:**
- `CHANGED` — File exists but hash differs
- `ADDED` — New file appeared
- `REMOVED` — File was deleted

**Status logic:**
- `CLEAN` — No drift entries
- `WARNING` — Drift entries exist but none are hard-stop
- `HARD_STOP` — At least one hard-stop file changed

---

## Adding a New Annotation Type

1. Update `tfvars_example_parser.py` to extract the new annotation
2. Update `scaffold_generator.py` to emit it during scaffold generation
3. Update the frontend `FormField.jsx` to handle the new annotation
4. Add tests in `tests/test_tfvars_example_parser.py`
