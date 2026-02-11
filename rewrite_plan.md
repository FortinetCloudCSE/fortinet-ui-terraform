# Rewrite Plan: Template Registry Architecture

## Overview

Rewrite the Fortinet UI Terraform application from a **bundled template** model to a **template registry** model. Instead of storing Terraform templates in this repository, the app maintains a database of external GitHub repo references with corresponding annotated UI definition files (`tfvars.ui`). When a user selects a template, the app clones the repo on demand and generates the web UI from the stored `tfvars.ui`.

---

## Design Decisions

### Core Concept

| Decision | Choice |
|----------|--------|
| Template storage | External GitHub repos, cloned on demand |
| UI definition file | `tfvars.ui` (annotated file with `@ui-` tags) |
| Database | SQLite, single file |
| `tfvars.ui` storage | In the database (text column) |
| Repo references | Always pull latest from default branch |
| Existing templates | Left in repo, not used by the app |

### Storage & Paths

| Path | Purpose | Persistence |
|------|---------|-------------|
| `DB_PATH` | SQLite database (`templates.db`) | Persistent (mounted volume in containers) |
| `CLONE_DIR` | Cloned repos | Ephemeral (defaults to `/tmp/terraform-repos/`) |

### Drift Detection

Two-tier system based on per-file SHA-256 hashes stored at the time the `tfvars.ui` is saved.

**Hard Stop** (blocks execution, requires user action):
- `variables.tf` changed, added, or removed
- `terraform.tfvars.example` changed, added, or removed
- `terraform.tfvars` appeared in the repo

**Warning** (informational, does not block):
- Any other `.tf` file changed, added, or removed

**Scope:** Top-level template directory only. No recursion into subdirectories. Submodule internals are an implementation detail - the top-level `variables.tf` is the public interface.

**Diff report format:**
- Changed files (with hash before/after)
- New files (not present when `tfvars.ui` was saved)
- Removed files (present when saved, now gone)
- Each entry marked as hard-stop or warning

### Hard Stop Workflow

When drift is detected on a hard-stop file:

1. Block template execution
2. Show the user what changed (diff of `variables.tf`, new/removed variables, changed types/defaults)
3. Present the current `tfvars.ui` alongside the changes
4. Allow the user to edit the `tfvars.ui` to account for changes (add annotations for new variables, remove stale ones)
5. Save updated `tfvars.ui` and new file hashes to the database

### `tfvars.ui` Authoring Workflow

**Creating a new `tfvars.ui`:**

1. User provides a GitHub repo URL + path to template directory
2. App clones the repo
3. App parses `variables.tf` and `terraform.tfvars.example` to generate a skeleton `tfvars.ui` with as much auto-filled as possible:
   - `@description` from variable `description` fields
   - `@type` inferred from variable `type` (string -> text, bool -> checkbox, number -> number, list -> list)
   - `@default` from variable `default` values
   - `@required true` if no default is set
   - `@options` from `validation` blocks if they constrain values
   - Example values from `.tfvars.example` as additional defaults/context
4. User exports the skeleton
5. User enriches it (manually or via AI tool) - adds `@group`, `@depends`, `@source`, `@inherit`, labels, etc.
6. User re-imports the annotated `tfvars.ui` into the app
7. App saves to DB with file hashes from that moment

**Updating an existing `tfvars.ui` (after drift):**

Same export/import cycle, but guided by a diff showing what changed in the upstream template.

### Database Schema

```sql
CREATE TABLE templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,              -- Display name for dropdown
    repo_url TEXT NOT NULL,          -- e.g. github.com/org/repo
    repo_path TEXT NOT NULL,         -- Path within repo to template dir
    branch TEXT,                     -- Branch/tag (NULL = default branch)
    tfvars_ui TEXT NOT NULL,         -- The annotated tfvars.ui content
    snapshot_date TEXT NOT NULL,     -- ISO 8601 timestamp
    created_date TEXT NOT NULL,
    updated_date TEXT NOT NULL
);

CREATE TABLE file_hashes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL,
    filename TEXT NOT NULL,          -- e.g. "variables.tf"
    hash TEXT NOT NULL,              -- SHA-256 hex digest
    hard_stop BOOLEAN NOT NULL,      -- 1 for hard-stop files, 0 for warning
    FOREIGN KEY (template_id) REFERENCES templates(id) ON DELETE CASCADE
);
```

**Hard-stop logic in `file_hashes`:**
- `variables.tf` -> `hard_stop = 1`
- `terraform.tfvars.example` -> `hard_stop = 1`
- `terraform.tfvars` -> `hard_stop = 1`
- All other `.tf` files -> `hard_stop = 0`

### Terraform Execution

- `plan` and `apply` run against the cloned repo directory
- Credentials workflow unchanged (session injection via API for AWS/GCP)
- The app writes the generated `terraform.tfvars` into the cloned repo's template directory before running Terraform

### Future: Central Registry Service

Not implemented now, but the architecture supports it. A separate app or GitHub repo could serve as a curated catalog of verified `tfvars.ui` files:

```
registry/
  fortinetdev/terraform-aws-cloud-modules/
    spk_tgw_gwlb_asg_fgt_igw/
      tfvars.ui
      manifest.json    -- hashes, metadata, snapshot_date
  some-other-org/some-repo/
    tfvars.ui
    manifest.json
```

The app could pull from this registry to seed/update its local SQLite DB. This is additive - the current DB schema doesn't care where the `tfvars.ui` came from.

---

## Implementation Plan

### Phase 1: Database & Core Backend

**FOR-7: Create SQLite database layer**
- Create database module with SQLite connection management
- Implement schema creation/migration (templates + file_hashes tables)
- CRUD operations for templates (create, read, update, delete, list)
- CRUD operations for file_hashes (bulk insert, bulk compare)
- Environment variable support: `DB_PATH`, `CLONE_DIR`
- Unit tests for all DB operations

**FOR-8: Implement Git clone/pull service**
- Clone a repo given URL + optional branch
- Pull latest if repo already cloned in `CLONE_DIR`
- Return the local path to the template directory (repo_path within clone)
- Handle errors (bad URL, private repo, network failure)
- Cleanup of stale clones
- Unit tests

**FOR-9: Implement file hashing service**
- Scan top-level `.tf` files in a directory (no recursion)
- Also scan for `terraform.tfvars.example` and `terraform.tfvars`
- Compute SHA-256 per file
- Classify each file as hard-stop or warning
- Return structured manifest (filename -> hash -> classification)
- Unit tests

**FOR-10: Implement drift detection service**
- Compare stored file_hashes against current repo state
- Produce diff report: changed, new, removed files
- Each entry classified as hard-stop or warning
- Overall status: clean / warning / hard-stop
- Unit tests

### Phase 2: `tfvars.ui` Authoring

**FOR-11: Implement `variables.tf` parser**
- Parse HCL variable blocks: name, type, default, description, validation
- Extract validation constraints (e.g., allowed values for `@options`)
- Handle complex types (map, list, object) gracefully
- Unit tests with sample `variables.tf` files

**FOR-12: Implement `terraform.tfvars.example` parser**
- Parse example values and comments
- Map values to corresponding variables
- Preserve comments as potential description/context
- Unit tests (can reuse/adapt existing tfvars parser)

**FOR-13: Implement skeleton `tfvars.ui` generator**
- Combine parsed `variables.tf` + `.tfvars.example` data
- Auto-fill annotations:
  - `@description` from variable description
  - `@type` inferred from HCL type
  - `@default` from variable default or example value
  - `@required` if no default
  - `@options` from validation constraints
- Output well-formatted `tfvars.ui` text
- Unit tests

### Phase 3: Backend API

**FOR-14: Template registry API endpoints**
- `GET /api/templates` - List all registered templates (for dropdown)
- `GET /api/templates/{id}` - Get template details
- `POST /api/templates` - Register new template (repo_url + repo_path)
- `PUT /api/templates/{id}` - Update template (e.g., updated tfvars.ui)
- `DELETE /api/templates/{id}` - Remove template from registry

**FOR-15: `tfvars.ui` management API endpoints**
- `POST /api/templates/{id}/scaffold` - Clone repo, generate skeleton tfvars.ui
- `GET /api/templates/{id}/export` - Export current tfvars.ui
- `POST /api/templates/{id}/import` - Import updated tfvars.ui, re-hash files, save
- `GET /api/templates/{id}/drift` - Check for drift, return diff report

**FOR-16: Adapt Terraform execution endpoints**
- Modify `plan` endpoint to work against cloned repo directory
- Modify `apply` endpoint to work against cloned repo directory
- Write generated `terraform.tfvars` into cloned template dir
- Inject credentials (AWS/GCP) same as today
- Drift check before plan/apply (block on hard-stop)

### Phase 4: Frontend

**FOR-17: Template selector redesign**
- Replace hardcoded template dropdown with DB-driven list from `GET /api/templates`
- Show template name, repo URL, last snapshot date
- Visual indicator for drift status (clean / warning / hard-stop)

**FOR-18: Template registration UI**
- Form to add new template: repo URL, path, name
- Trigger scaffold generation
- Display skeleton tfvars.ui for review
- Export button (download as file)
- Import button (upload enriched file)
- Save to DB

**FOR-19: Drift resolution UI**
- When hard-stop drift detected, show diff view
- Side-by-side: what changed in the template vs current tfvars.ui
- Highlight new variables (need annotations), removed variables (stale)
- Inline editing of tfvars.ui
- Save and re-hash

**FOR-20: Warning display**
- When warning-level drift detected, show non-blocking banner
- List changed/new/removed .tf files
- Dismissible, does not block plan/apply

### Phase 5: Cleanup & Container Support

**FOR-21: Dockerfile and container configuration**
- Update Dockerfile for new architecture
- `DB_PATH` env var for persistent volume mount
- `CLONE_DIR` env var for ephemeral clone directory
- Ensure git is available in container image
- Health check endpoint

**FOR-22: Remove old template coupling**
- Remove backend code that reads templates from local `terraform/` directory
- Remove `get_terraform_dir()` and related path resolution
- Remove template inheritance logic (was specific to bundled templates)
- Update any imports/references
- Existing `terraform/` directory left untouched but unused

**FOR-23: Documentation**
- Update CLAUDE.md to reflect new architecture
- Update user-facing docs for new workflow
- Document `tfvars.ui` annotation format
- Document template registration process

---

## Linear.app Tasks

The following tasks map to the implementation plan above. Suggested labels: `backend`, `frontend`, `infra`, `docs`.

| Linear | Title | Phase | Labels | Dependencies |
|--------|-------|-------|--------|--------------|
| FOR-7 | Create SQLite database layer with schema and CRUD operations | Phase 1 | backend | - |
| FOR-8 | Implement Git clone/pull service | Phase 1 | backend | - |
| FOR-9 | Implement file hashing service | Phase 1 | backend | - |
| FOR-10 | Implement drift detection service | Phase 1 | backend | FOR-7, FOR-9 |
| FOR-11 | Implement `variables.tf` HCL parser | Phase 2 | backend | - |
| FOR-12 | Implement `terraform.tfvars.example` parser | Phase 2 | backend | - |
| FOR-13 | Implement skeleton `tfvars.ui` generator | Phase 2 | backend | FOR-11, FOR-12 |
| FOR-14 | Build template registry API endpoints | Phase 3 | backend | FOR-7, FOR-8 |
| FOR-15 | Build `tfvars.ui` management API endpoints (scaffold, export, import, drift) | Phase 3 | backend | FOR-8, FOR-10, FOR-13 |
| FOR-16 | Adapt Terraform execution endpoints for cloned repos | Phase 3 | backend | FOR-8, FOR-10, FOR-14 |
| FOR-17 | Redesign template selector (DB-driven dropdown with drift indicators) | Phase 4 | frontend | FOR-14 |
| FOR-18 | Build template registration UI (add repo, scaffold, export/import) | Phase 4 | frontend | FOR-15 |
| FOR-19 | Build drift resolution UI (diff view, inline editing) | Phase 4 | frontend | FOR-15, FOR-17 |
| FOR-20 | Build warning display (non-blocking banner for .tf changes) | Phase 4 | frontend | FOR-10, FOR-17 |
| FOR-21 | Dockerfile and container configuration | Phase 5 | infra | FOR-14, FOR-16 |
| FOR-22 | Remove old template coupling from backend | Phase 5 | backend | FOR-14, FOR-15, FOR-16 |
| FOR-23 | Update documentation (CLAUDE.md, user docs, annotation format) | Phase 5 | docs | FOR-22 |

### Suggested Priority Order

**Start parallel:** FOR-7, FOR-8, FOR-9, FOR-11, FOR-12 have no dependencies and can be built simultaneously.

**Second wave:** FOR-10, FOR-13, FOR-14 once their dependencies land.

**Third wave:** FOR-15, FOR-16, FOR-17 build the integrated experience.

**Fourth wave:** FOR-18, FOR-19, FOR-20 complete the frontend.

**Final:** FOR-21, FOR-22, FOR-23 clean up and ship.
