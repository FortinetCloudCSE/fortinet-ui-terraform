---
title: "Working in the UI"
chapter: false
menuTitle: "Working in the UI"
weight: 21
---

Developer guide for extending and customizing the Terraform Configuration Web UI.

<!--more-->

## Architecture Overview

The UI uses a **template registry** architecture. Templates are registered from external git repositories, cloned on demand, and managed through a SQLite database with drift detection.

```
ui/
├── backend/                    # FastAPI Python backend
│   ├── app/
│   │   ├── api/                # API routers
│   │   │   ├── templates.py    # Template registry CRUD
│   │   │   ├── tfvars_ui.py    # Scaffold, export/import, drift
│   │   │   ├── template_terraform.py  # Plan/apply/destroy
│   │   │   ├── aws.py          # AWS resource discovery
│   │   │   └── gcp.py          # GCP resource discovery
│   │   ├── services/           # Business logic
│   │   │   ├── git_service.py         # Git clone/pull
│   │   │   ├── drift_service.py       # Drift detection
│   │   │   ├── file_hash_service.py   # SHA-256 file scanning
│   │   │   ├── scaffold_generator.py  # tfvars.ui generation
│   │   │   ├── hcl_parser.py          # variables.tf parser
│   │   │   └── tfvars_example_parser.py  # Annotation parser
│   │   ├── db/                 # Database layer (SQLite)
│   │   │   ├── crud.py         # TemplateDB, FileHashDB
│   │   │   └── models.py       # Pydantic models
│   │   └── config.py           # App settings
│   └── tests/                  # 250+ pytest tests
├── frontend/                   # React/Vite frontend
│   ├── src/
│   │   ├── components/
│   │   │   ├── TerraformConfig.jsx       # Main UI
│   │   │   ├── TemplateRegistration.jsx  # Register templates
│   │   │   └── DriftResolution.jsx       # Resolve drift
│   │   └── services/api.js     # API client
│   └── nginx.conf              # Production reverse proxy
└── docker-compose.yml          # Container deployment
```

### Data Flow

1. User registers a template (git repo URL + path)
2. Backend clones the repo, scans files, stores hashes in SQLite
3. Scaffold generator creates `tfvars.ui` from `variables.tf` + `terraform.tfvars.example`
4. User enriches annotations, imports back
5. Drift detection compares stored hashes with current repo state
6. Terraform execution streams plan/apply/destroy output (blocks on hard-stop drift)

---

## Starting the UI

### First Time Setup

Install dependencies for both backend and frontend:

```bash
cd ui
./SETUP.sh
```

This script:
1. Creates a Python virtual environment using `uv`
2. Installs Python dependencies (FastAPI, aiosqlite, boto3, etc.)
3. Installs Node.js dependencies via `npm install`

### Running the UI

Use the restart script to start both services:

```bash
cd ui
./RESTART.sh
```

**Services started:**
- **Backend (FastAPI)**: http://127.0.0.1:8000
- **Frontend (Vite)**: http://localhost:3000
- **API Docs (Swagger)**: http://127.0.0.1:8000/docs

### Manual Startup

For development, you may want to run services separately:

**Backend:**
```bash
cd ui/backend
uv run uvicorn app.main:app --reload --port 8000
```

**Frontend:**
```bash
cd ui/frontend
npm run dev
```

### Container Deployment

```bash
cd ui
docker compose up --build
```

This starts backend (port 8000) and frontend (port 3000) with a shared `registry-data` volume for the SQLite database and cloned repositories.

---

## Developer Topics

| Topic | Description |
|-------|-------------|
| [Annotation Reference](2_1_1_annotations/) | `@ui-` annotation tags for tfvars.ui and tfvars.example files |
| [Registering Templates](2_1_2_porting_templates/) | How to add templates via the registry |
| [Backend APIs](2_1_3_backend_apis/) | Template registry, tfvars.ui, and terraform execution endpoints |
| [Parsers & Services](2_1_4_parsers/) | HCL parser, annotation parser, scaffold generator, drift detection |
| [Cloud Provider APIs](2_1_5_cloud_providers/) | Integrating AWS, Azure, GCP APIs |
| [Frontend Development](2_1_6_frontend/) | React components, template selector, drift UI |
| [Testing](2_1_7_testing/) | Backend pytest suite (250+ tests) and frontend builds |
| [Troubleshooting](2_1_8_troubleshooting/) | Common issues and fixes |
