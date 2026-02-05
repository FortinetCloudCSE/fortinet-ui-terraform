---
title: "Getting Started"
chapter: false
menuTitle: "Getting Started"
weight: 20
---

Get the Terraform Web UI running and configure AWS credentials.

<!--more-->

## Prerequisites

Before using the UI:

1. **Python 3.11+** installed
2. **Node.js 18+** installed
3. **AWS CLI** installed and configured with at least one profile
4. **Repository cloned**:
   ```bash
   git clone https://github.com/FortinetCloudCSE/fortinet-ui-terraform.git
   cd fortinet-ui-terraform
   ```

---

## Quick Start

### First Time Setup

Run the setup script to install Python and Node.js dependencies:

```bash
cd ui
./SETUP.sh
```

### Start the UI

Use the restart script to start both backend and frontend:

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

Open http://localhost:3000 in your browser.

---

## AWS Credentials

The UI requires AWS credentials to discover resources (regions, availability zones, key pairs, VPCs, Transit Gateways). Without credentials, you'll need to manually type these values.

### SSO Users (Recommended)

Use the `aws_login.sh` script in the `sso_login/` directory:

```bash
source sso_login/aws_login.sh [profile] [backend_url]
```

**Examples:**
```bash
# Login with default profile (40netse) to default backend (http://127.0.0.1:8001)
source sso_login/aws_login.sh

# Login with specific profile
source sso_login/aws_login.sh my-aws-profile

# Login with specific profile and custom backend URL
source sso_login/aws_login.sh my-aws-profile http://localhost:8000
```

The script:
1. Authenticates via AWS SSO
2. Exports credentials to your shell environment
3. Sends credentials to the UI backend

{{% notice tip %}}
Use `source` (not just `./`) so credentials are exported to your current shell.
{{% /notice %}}

### IAM Users (Static Credentials)

Use the `aws_static_login.sh` script for IAM users with access keys:

```bash
source sso_login/aws_static_login.sh [profile] [backend_url]
```

**Examples:**
```bash
# Load default profile
source sso_login/aws_static_login.sh

# Load specific profile
source sso_login/aws_static_login.sh my-profile
```

### Verify Credentials

Check that credentials are working:

```bash
curl http://localhost:8000/api/aws/credentials/status
```

Response:
```json
{
  "valid": true,
  "account": "123456789012",
  "arn": "arn:aws:iam::123456789012:user/example",
  "source": "session",
  "message": "AWS credentials are valid"
}
```

---

## Using the UI

The UI workflow consists of three steps:

### 1. Select Template

Choose a template from the dropdown:
- **existing_vpc_resources** - Base infrastructure (deploy first)
- **autoscale_template** - Elastic FortiGate cluster with GWLB
- **ha_pair** - Fixed Active-Passive FortiGate cluster

### 2. Configure

Fill out the form fields. The UI provides:
- **Dynamic dropdowns** - AWS regions, AZs, and key pairs populated from your account
- **Field validation** - Real-time validation prevents configuration errors
- **Smart dependencies** - Fields update automatically based on your selections
- **Grouped sections** - Related options organized into collapsible sections

### 3. Generate and Deploy

Click **Generate** to create the `terraform.tfvars` file, then either:
- **Download** - Save the file locally
- **Save to Template** - Write directly to the template directory

---

## Docker Containers (Alternative)

Run the UI and Hugo documentation server in Docker containers instead of locally.

### Start Containers

```bash
cd ui/docker-containers
docker-compose up -d
```

### Services

| Service | Port | URL |
|---------|------|-----|
| Frontend | 3001 | http://localhost:3001 |
| Backend | 8001 | http://localhost:8001 |
| Hugo Docs | 1313 | http://localhost:1313/fortinet-ui-terraform/ |

### AWS Credentials for Containers

Send credentials to the containerized backend (note port 8001):

```bash
source sso_login/aws_login.sh my-profile http://localhost:8001
```

### Container Commands

```bash
# Start all services
docker-compose up -d

# Start only UI (no Hugo)
docker-compose up -d backend frontend

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Rebuild after code changes
docker-compose up -d --build
```

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

### Frontend Won't Start

**Error:** `command not found: npm`

**Solution:** Install Node.js from https://nodejs.org/

**Error:** `Cannot find module`

**Solution:** Install dependencies:
```bash
cd ui/frontend
npm install
```

### AWS Dropdowns Empty

**Symptom:** Region, AZ, and key pair dropdowns are empty or show errors.

**Solutions:**

1. Check credential status:
   ```bash
   curl http://localhost:8000/api/aws/credentials/status
   ```

2. If using SSO, ensure session is active:
   ```bash
   source sso_login/aws_login.sh your-profile
   ```

3. If credentials expired, re-run the login script.

---

## Next Steps

See **[Example Templates](../3_example_templates/)** for step-by-step configuration guides for each template.
