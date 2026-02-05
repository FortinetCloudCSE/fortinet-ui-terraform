---
title: "Working in the UI"
chapter: false
menuTitle: "Working in the UI"
weight: 21
---

Developer guide for extending and customizing the Terraform Configuration Web UI.

<!--more-->

## Architecture Overview

The UI consists of two main components:

```
ui/
├── backend/          # FastAPI Python backend
│   ├── main.py       # API endpoints
│   ├── parsers/      # Template parsers
│   └── providers/    # Cloud provider integrations
└── frontend/         # React/Vite frontend
    ├── src/
    │   ├── components/   # React components
    │   └── services/     # API client services
    └── package.json
```

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
2. Installs Python dependencies (FastAPI, boto3, etc.)
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
uv run uvicorn main:app --reload --port 8000
```

**Frontend:**
```bash
cd ui/frontend
npm run dev
```

---

## Developer Topics

| Topic | Description |
|-------|-------------|
| [Annotation Reference](2_1_1_annotations/) | UI annotation tags for terraform.tfvars.example files |
| [Porting New Templates](2_1_2_porting_templates/) | How to add new Terraform templates to the UI |
| [Writing Backend APIs](2_1_3_backend_apis/) | Adding FastAPI endpoints and Pydantic models |
| [Writing Parsers](2_1_4_parsers/) | Template parsing and annotation extraction |
| [Cloud Provider APIs](2_1_5_cloud_providers/) | Integrating AWS, Azure, GCP APIs |
| [Frontend Development](2_1_6_frontend/) | React components and API client |
| [Testing](2_1_7_testing/) | Backend and frontend testing |
| [Troubleshooting](2_1_8_troubleshooting/) | Common issues and fixes |

