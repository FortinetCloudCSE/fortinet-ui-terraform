---
title: "Terraform Web UI"
chapter: false
menuTitle: "Web UI"
weight: 60
---

## Overview

The Terraform Web UI provides a graphical interface for configuring FortiGate Autoscale deployments without manually editing terraform.tfvars files. The UI offers:

- **Form-based configuration** - Fill out forms instead of editing text files
- **AWS integration** - Automatically discovers regions, availability zones, and key pairs
- **Field validation** - Real-time validation prevents configuration errors
- **Smart dependencies** - Fields update automatically based on your selections
- **Preview and download** - Generate and review terraform.tfvars before deployment

---

## Prerequisites

Before using the UI:

1. **Python 3.11+** installed
2. **Node.js 18+** installed
3. **AWS credentials configured** (optional - UI works without it, but you'll need to manually type AWS values)
4. **Repository cloned**:
   ```bash
   git clone https://github.com/FortinetCloudCSE/Autoscale-Simplified-Template.git
   cd Autoscale-Simplified-Template
   ```

---

## Starting the UI

### Step 1: Start the Backend

Open a terminal and start the Python backend:

```bash
cd ui/backend
uv run uvicorn app.main:app --reload
```

Expected output:
```
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

**Keep this terminal open** - the backend must stay running.

### Step 2: Start the Frontend

Open a **second terminal** and start the React frontend:

```bash
cd ui/frontend
npm run dev
```

Expected output:
```
  VITE v5.0.0  ready in 500 ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
  ➜  press h + enter to show help
```

**Keep this terminal open** - the frontend must stay running.

### Step 3: Open the UI

Open your browser and navigate to:

```
http://localhost:5173
```

You should see the Terraform Configuration UI.

---

## Using the UI

The UI workflow consists of three main steps:

1. **Configure** - Fill out the form fields
2. **Generate** - Generate the terraform.tfvars file
3. **Deploy** - Download or save directly to the template directory

The following sections provide detailed instructions for configuring each template.

---

## Documentation Sections

- **[Configuring existing_vpc_resources](6_1_existing_vpc_resources/)** - Step-by-step guide for base infrastructure
- **[Configuring autoscale_template](6_2_autoscale_template/)** - Step-by-step guide for AutoScale deployment
- **[Configuring ha_pair](6_3_ha_pair/)** - Step-by-step guide for HA Pair deployment

---

## Troubleshooting

### Backend Won't Start

**Error:** `command not found: uv`

**Solution:** Install uv package manager:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

**Error:** `ModuleNotFoundError`

**Solution:** Sync dependencies:
```bash
cd ui/backend
uv sync
```

---

### Frontend Won't Start

**Error:** `command not found: npm`

**Solution:** Install Node.js from https://nodejs.org/

**Error:** `Cannot find module`

**Solution:** Install dependencies:
```bash
cd ui/frontend
npm install
```

---

### CORS Errors

**Error:** Browser console shows CORS policy errors

**Solution:** Verify backend CORS configuration includes frontend URL:

Edit `ui/backend/app/config.py`:
```python
cors_origins: List[str] = [
    "http://localhost:5173",  # ← Must match frontend URL
    "http://localhost:3000"
]
```

---

### AWS Credentials Not Working

**Symptom:** Dropdowns for regions, AZs, and key pairs are empty or show errors

**Solution:** Configure AWS credentials:

```bash
aws configure
```

Or set environment variables:
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-2"
```

{{% notice info %}}
**AWS Credentials are Optional**

The UI works without AWS credentials. If not configured, you'll need to manually type AWS resource names instead of selecting from dropdowns.
{{% /notice %}}

---

## Next Steps

Choose the template you want to configure:

1. **Start with [existing_vpc_resources](6_1_existing_vpc_resources/)** - Required first step for all deployments
2. Then configure either:
   - **[autoscale_template](6_2_autoscale_template/)** - For elastic autoscaling with GWLB
   - **[ha_pair](6_3_ha_pair/)** - For fixed Active-Passive HA deployment
