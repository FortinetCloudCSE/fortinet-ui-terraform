---
title: "Getting Started"
chapter: false
menuTitle: "Getting Started"
weight: 20
---

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
🔄 Restarting Terraform Configuration UI...

📋 Cleaning up old processes...
🔍 Verifying backend...
🚀 Starting backend (FastAPI)...
   Backend started (PID: 12345)
   Waiting for backend to be ready...
   ✅ Backend is healthy
🔍 Verifying frontend...
🎨 Starting frontend (Vite)...
   Frontend started (PID: 12346)
   Waiting for frontend to be ready...
   ✅ Frontend is ready

============================================
✅ Services started successfully!
============================================

📊 URLs:
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

The UI requires AWS credentials to discover resources (regions, availability zones, key pairs, VPCs, Transit Gateways). Without credentials, you'll need to manually type these values.

### Method 1: AWS Login Script (Recommended for SSO)

Create an `aws_login.sh` script that handles SSO authentication and sends credentials to the UI backend.

**Create the script:**

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/aws_login.sh << 'EOF'
#!/bin/bash
# AWS SSO Login Script with UI Backend Integration
# Usage: source aws_login.sh [profile] [backend_url]

DEFAULT_PROFILE="default"
DEFAULT_BACKEND_URL="http://127.0.0.1:8000"

PROFILE_NAME="${1:-$DEFAULT_PROFILE}"
BACKEND_URL="${2:-$DEFAULT_BACKEND_URL}"

echo "🔐 Logging in to AWS SSO with profile: $PROFILE_NAME"

if aws sso login --profile "$PROFILE_NAME"; then
    echo "✅ SSO login successful."

    # Export credentials to local environment
    if CREDENTIALS=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env); then
        eval "$CREDENTIALS"
        echo "✅ Credentials exported to local environment"

        # Get credentials for posting to backend
        ACCESS_KEY=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_ACCESS_KEY_ID | cut -d= -f2)
        SECRET_KEY=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_SECRET_ACCESS_KEY | cut -d= -f2)
        SESSION_TOKEN=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_SESSION_TOKEN | cut -d= -f2)

        # POST credentials to UI backend
        echo "📤 Sending credentials to UI backend at $BACKEND_URL..."
        RESPONSE=$(curl -s -m 5 -X POST "${BACKEND_URL}/api/aws/credentials/set" \
            -H "Content-Type: application/json" \
            -d "{\"access_key\": \"$ACCESS_KEY\", \"secret_key\": \"$SECRET_KEY\", \"session_token\": \"$SESSION_TOKEN\"}" 2>&1)

        if echo "$RESPONSE" | grep -q '"valid".*true'; then
            echo "✅ Credentials sent to UI backend"
        else
            echo "⚠️  UI backend not reachable (credentials set locally only)"
        fi
        echo "✅ Ready to use AWS CLI and UI"
    fi
else
    echo "❌ AWS SSO login failed"
    exit 1
fi
EOF
chmod +x ~/.local/bin/aws_login.sh
```

**Add to your PATH** (add to `~/.zshrc` or `~/.bashrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Usage:**

```bash
# Login with default profile
source aws_login.sh

# Login with specific profile
source aws_login.sh my-aws-profile

# Login with specific profile and remote backend
source aws_login.sh my-aws-profile http://remote-host:8000
```

{{% notice tip %}}
Use `source` (not just `./`) so credentials are exported to your current shell.
{{% /notice %}}

### Method 2: Environment Variables

If you have AWS credentials already, export them before starting the UI:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # If using temporary credentials
```

The UI backend automatically uses these environment variables.

### Method 3: Direct API (Remote/Container Deployments)

POST credentials directly to the backend API:

```bash
curl -X POST http://localhost:8000/api/aws/credentials/set \
  -H "Content-Type: application/json" \
  -d '{
    "access_key": "AKIAIOSFODNN7EXAMPLE",
    "secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "session_token": "optional-session-token"
  }'
```

### Checking Credential Status

Verify credentials are working:

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

The `source` field indicates where credentials came from:
- `"session"` - Posted via API or `aws_login.sh`
- `"environment/default"` - From environment variables or AWS credential chain

### Clearing Credentials

To clear stored credentials and fall back to environment variables:

```bash
curl -X DELETE http://localhost:8000/api/aws/credentials/clear
```

---

## Using the UI

The UI workflow consists of three main steps:

1. **Configure** - Fill out the form fields
2. **Generate** - Generate the terraform.tfvars file
3. **Deploy** - Download or save directly to the template directory

The following sections provide detailed instructions for configuring each template.

---

## Documentation Sections

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
    "http://localhost:3000",  # ← Must match frontend URL
    "http://localhost:3000"
]
```

---

### AWS Credentials Not Working

**Symptom:** Dropdowns for regions, AZs, and key pairs are empty or show errors

**Solution 1:** Use the aws_login.sh script (recommended):
```bash
source aws_login.sh
```

**Solution 2:** Check credential status:
```bash
curl http://localhost:8000/api/aws/credentials/status
```

If credentials are expired or invalid, re-run the login script.

**Solution 3:** For SSO users, ensure your SSO session is active:
```bash
aws sso login --profile your-profile
```

{{% notice warning %}}
**AWS Credentials are Required**

The UI requires valid AWS credentials to discover resources. Without credentials, region/AZ/keypair dropdowns will be empty or show errors.
{{% /notice %}}

---

## Next Steps

Choose the template you want to configure:

1. **Start with [existing_vpc_resources](2_1_existing_vpc_resources/)** - Required first step for all deployments
2. Then configure either:
   - **[autoscale_template](2_2_autoscale_template/)** - For elastic autoscaling with GWLB
   - **[ha_pair](2_3_ha_pair/)** - For fixed Active-Passive HA deployment
