---
title: "Getting Started"
chapter: false
menuTitle: "Getting Started"
weight: 20
description: "Set up the Terraform Web UI and configure AWS credentials"
summary: "Set up the Terraform Web UI and configure AWS credentials"
---

Set up the Terraform Web UI and configure AWS credentials for resource discovery.

<!--more-->

## Overview

The Terraform Web UI provides a graphical interface for configuring **any Terraform template** with a properly annotated `terraform.tfvars.example` file. Instead of manually editing variable files, you configure deployments through dynamically generated forms.

**Key Features:**
- **Form-based configuration** - Fill out forms instead of editing text files
- **Dynamic form generation** - Forms built automatically from annotated example files
- **AWS integration** - Automatically discovers regions, availability zones, and key pairs
- **Field validation** - Real-time validation prevents configuration errors
- **Smart dependencies** - Fields update automatically based on your selections

**Included Example Templates:**
| Template | Description |
|----------|-------------|
| **existing_vpc_resources** | Base AWS infrastructure: Management VPC, Transit Gateway, spoke VPCs |
| **autoscale_template** | Elastic FortiGate cluster with Gateway Load Balancer |
| **ha_pair** | Fixed Active-Passive FortiGate cluster with FGCP |

See the [Annotation Reference](../6_templates/5_5_annotations/) to learn how to add UI support to your own templates.

---

## Prerequisites

Before using the UI:

1. **Python 3.11+** installed
2. **Node.js 18+** installed
3. **AWS credentials** - Required for resource discovery (see [AWS Credentials](#aws-credentials) below)
4. **Repository cloned**:
   ```bash
   git clone https://github.com/FortinetCloudCSE/fortinet-ui-terraform.git
   cd fortinet-ui-terraform
   ```

---

## Starting the UI

### Quick Start (Recommended)

Use the automated restart script that handles both backend and frontend:

```bash
cd ui
./RESTART.sh
```

Expected output:
```
Restarting Terraform Configuration UI...

Cleaning up old processes...
Verifying backend...
Starting backend (FastAPI)...
   Backend started (PID: 12345)
   Waiting for backend to be ready...
   Backend is healthy
Verifying frontend...
Starting frontend (Vite)...
   Frontend started (PID: 12346)
   Waiting for frontend to be ready...
   Frontend is ready

============================================
Services started successfully!
============================================

URLs:
   Frontend: http://localhost:3000
   Backend:  http://127.0.0.1:8000
   API Docs: http://127.0.0.1:8000/docs
```

{{% notice tip %}}
**First Time Setup**

If this is your first time running the UI, run the setup script first:
```bash
cd ui
./SETUP.sh
```
This installs Python and Node.js dependencies automatically.
{{% /notice %}}

### Manual Start (Alternative)

If you prefer to start services manually in separate terminals:

**Terminal 1 - Backend:**
```bash
cd ui/backend
.venv/bin/uvicorn app.main:app --reload --port 8000
```

**Terminal 2 - Frontend:**
```bash
cd ui/frontend
npm run dev
```

### Access the UI

Open your browser and navigate to:

```
http://localhost:3000
```

You should see the Terraform Configuration UI.

---

## AWS Credentials

The UI requires AWS credentials to discover AWS resources (regions, AZs, key pairs). See **[AWS Credentials](2_0_aws_credentials/)** for detailed setup instructions.

**Quick options:**
- **SSO users**: Use the `aws_login.sh` script
- **IAM users**: Use the `aws_static_login.sh` script
- **Automatic**: Credentials in `~/.aws/credentials` are picked up automatically

---

## Using the UI

The UI workflow consists of three main steps:

1. **Configure** - Fill out the form fields
2. **Generate** - Generate the terraform.tfvars file
3. **Deploy** - Download or save directly to the template directory

The following sections provide detailed instructions for configuring each template.

---

## Documentation Sections

- **[AWS Credentials](2_0_aws_credentials/)** - Configure AWS credentials for resource discovery
- **[Configuring existing_vpc_resources](2_1_existing_vpc_resources/)** - Step-by-step guide for base infrastructure
- **[Configuring autoscale_template](2_2_autoscale_template/)** - Step-by-step guide for AutoScale deployment
- **[Configuring ha_pair](2_3_ha_pair/)** - Step-by-step guide for HA Pair deployment

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
    "http://localhost:3000",  # <-- Must match frontend URL
    "http://localhost:3000"
]
```

---

### AWS Credentials Not Working

**Symptom:** Dropdowns for regions, AZs, and key pairs are empty or show errors

See **[AWS Credentials Troubleshooting](2_0_aws_credentials/#troubleshooting)** for solutions.

---

## Next Steps

Choose the template you want to configure:

1. **Start with [existing_vpc_resources](2_1_existing_vpc_resources/)** - Required first step for all deployments
2. Then configure either:
   - **[autoscale_template](2_2_autoscale_template/)** - For elastic autoscaling with GWLB
   - **[ha_pair](2_3_ha_pair/)** - For fixed Active-Passive HA deployment
