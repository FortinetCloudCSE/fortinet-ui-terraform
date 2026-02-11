---
title: "Backend APIs"
menuTitle: "Backend APIs"
weight: 3
---

The backend provides three API routers for template management, configuration, and terraform execution.

## API Structure

```
app/api/
├── templates.py           # Template registry CRUD
├── tfvars_ui.py           # Scaffold, export/import, drift detection
├── template_terraform.py  # Plan/apply/destroy against cloned repos
├── terraform.py           # Shared utilities (run_command_stream)
├── aws.py                 # AWS resource discovery
└── gcp.py                 # GCP resource discovery
```

---

## Template Registry (`/api/templates/`)

CRUD operations for registered templates.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/templates/` | GET | List all registered templates |
| `/api/templates/{id}` | GET | Get single template by ID |
| `/api/templates/` | POST | Register new template (clones repo, scans files) |
| `/api/templates/{id}` | PUT | Update template (re-clones if URL/branch changes) |
| `/api/templates/{id}` | DELETE | Delete template and clean up clone |

### Register a Template

```bash
curl -X POST http://127.0.0.1:8000/api/templates/ \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Template",
    "repo_url": "https://github.com/org/repo.git",
    "branch": "main",
    "repo_path": "terraform/aws/my_template"
  }'
```

**Response:** Template object with `id`, `name`, `repo_url`, `branch`, `repo_path`, `created_date`, `updated_date`.

---

## tfvars.ui Management (`/api/templates/{id}/...`)

Scaffold generation, export/import, and drift detection.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/templates/{id}/scaffold` | POST | Generate skeleton tfvars.ui from variables.tf + example |
| `/api/templates/{id}/export` | GET | Export current tfvars.ui content |
| `/api/templates/{id}/import` | POST | Import updated tfvars.ui content (re-hashes files) |
| `/api/templates/{id}/drift` | GET | Check drift status against stored file hashes |

### Scaffold Response

```json
{
  "content": "# @ui-label AWS Region\n# @ui-type select\naws_region = \"us-west-2\"\n...",
  "variable_count": 42
}
```

### Drift Response

```json
{
  "status": "warning",
  "entries": [
    {"filename": "main.tf", "type": "changed", "hard_stop": false},
    {"filename": "variables.tf", "type": "changed", "hard_stop": true}
  ]
}
```

**Drift statuses:** `clean` (no changes), `warning` (non-critical files changed), `hard_stop` (critical files changed — blocks terraform execution).

**Hard-stop files:** `*.tf`, `terraform.tfvars.example`, `terraform.tfvars`, `*.cfg`, `*.tpl`, `*.tftpl`

---

## Terraform Execution (`/api/templates/{id}/terraform/...`)

Run terraform commands against cloned template directories with drift guards.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/templates/{id}/terraform/write-tfvars` | POST | Write terraform.tfvars to cloned directory |
| `/api/templates/{id}/terraform/plan` | GET | Run init + plan (streaming) |
| `/api/templates/{id}/terraform/apply` | GET | Run init + apply -auto-approve (streaming) |
| `/api/templates/{id}/terraform/destroy` | GET | Run init + destroy -auto-approve (streaming) |

All plan/apply/destroy endpoints:
- Perform a **drift check** before execution
- Return **HTTP 409 Conflict** if hard-stop drift is detected
- **Stream output** in real-time (text/plain)
- Inject cloud credentials (AWS env vars, GCP `GOOGLE_CREDENTIALS`)

### Write terraform.tfvars

```bash
curl -X POST http://127.0.0.1:8000/api/templates/1/terraform/write-tfvars \
  -H "Content-Type: application/json" \
  -d '{"content": "aws_region = \"us-west-2\"\ncp = \"acme\"\n..."}'
```

---

## Adding a New API Endpoint

Create a new router file in `app/api/`:

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/api/my-feature", tags=["my-feature"])

class MyRequest(BaseModel):
    name: str
    enabled: bool = False

@router.post("/action")
async def perform_action(request: MyRequest):
    if not request.name:
        raise HTTPException(status_code=400, detail="Name required")
    return {"success": True, "message": f"Action on {request.name}"}
```

Register in `app/main.py`:

```python
from app.api import my_feature
app.include_router(my_feature.router)
```
