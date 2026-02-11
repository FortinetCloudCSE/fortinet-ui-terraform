---
title: "Testing"
menuTitle: "Testing"
weight: 7
---

Backend and frontend testing.

## Backend Tests

The backend has 250+ pytest tests covering all services, database operations, and API endpoints.

```bash
cd ui/backend
uv run python -m pytest tests/ -v
```

### Test Files

| Test File | Coverage |
|-----------|----------|
| `test_db.py` | SQLite CRUD operations (TemplateDB, FileHashDB) |
| `test_git_service.py` | Git clone/pull, cleanup, error handling |
| `test_file_hash_service.py` | SHA-256 scanning, hard-stop classification |
| `test_drift_service.py` | Drift detection logic, status escalation |
| `test_hcl_parser.py` | variables.tf parsing (types, defaults, validation) |
| `test_tfvars_example_parser.py` | Annotation extraction, value parsing |
| `test_scaffold_generator.py` | tfvars.ui generation, annotation merging |
| `test_templates_api.py` | Template registry CRUD endpoints |
| `test_tfvars_ui_api.py` | Scaffold, export, import, drift endpoints |
| `test_template_terraform_api.py` | Terraform plan/apply/destroy endpoints |

### Running Specific Tests

```bash
# Run a single test file
uv run python -m pytest tests/test_drift_service.py -v

# Run tests matching a pattern
uv run python -m pytest tests/ -k "test_scaffold" -v

# Run with coverage
uv run python -m pytest tests/ --cov=app --cov-report=term-missing
```

### Test Configuration

Tests use `asyncio_mode = "auto"` in `pyproject.toml`, so no `@pytest.mark.asyncio` decorators are needed. API tests use `httpx.AsyncClient` with the FastAPI test client.

---

## Frontend Build Verification

The frontend uses Vite for building. Verify the build succeeds:

```bash
cd ui/frontend
npx vite build
```

A successful build produces output like:

```
vite v5.4.21 building for production...
✓ 47 modules transformed.
dist/index.html                   0.47 kB
dist/assets/index-*.css          17.79 kB
dist/assets/index-*.js          182.51 kB
✓ built in 274ms
```

---

## Manual Testing Checklist

When adding new features:

- [ ] Template selector populates from database
- [ ] "+" button opens registration modal
- [ ] Registration form clones repo and generates scaffold
- [ ] Export downloads tfvars.ui file
- [ ] Import uploads enriched tfvars.ui
- [ ] Drift indicator shows correct status (Clean/Warning/Hard Stop)
- [ ] Warning banner appears for non-critical drift
- [ ] Drift resolution modal opens on hard-stop click
- [ ] Conditional fields show/hide correctly (`@ui-show-if`)
- [ ] Dynamic dropdowns populate from cloud APIs (`@ui-source`)
- [ ] Plan/apply/destroy stream output in real-time
- [ ] Hard-stop drift blocks plan/apply with 409 error
- [ ] AWS/GCP credential status displays correctly
