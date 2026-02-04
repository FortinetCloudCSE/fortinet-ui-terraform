---
title: "AWS Credentials"
menuTitle: "AWS Credentials"
weight: 0
description: "Configure AWS credentials for the Terraform Web UI"
summary: "Configure AWS credentials for the Terraform Web UI"
---

Configure AWS credentials for the Terraform Web UI.

<!--more-->

The UI requires AWS credentials to discover resources (regions, availability zones, key pairs, VPCs, Transit Gateways). Without credentials, you'll need to manually type these values.

Choose the method that matches your AWS setup:

| Method | Best For |
|--------|----------|
| [SSO Login Script](#method-1-sso-login-script) | AWS SSO / Identity Center users |
| [Static Credentials Script](#method-2-static-credentials-script) | IAM users with access keys |
| [AWS Credentials File](#method-3-aws-credentials-file) | Automatic pickup from `~/.aws/credentials` |
| [Environment Variables](#method-4-environment-variables) | CI/CD pipelines, containers |
| [Direct API](#method-5-direct-api) | Remote/container deployments |

---

## Method 1: SSO Login Script

For AWS SSO (Identity Center) users. Creates a script that handles SSO authentication and sends credentials to the UI backend.

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

echo "Logging in to AWS SSO with profile: $PROFILE_NAME"

if aws sso login --profile "$PROFILE_NAME"; then
    echo "SSO login successful."

    # Export credentials to local environment
    if CREDENTIALS=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env); then
        eval "$CREDENTIALS"
        echo "Credentials exported to local environment"

        # Get credentials for posting to backend
        ACCESS_KEY=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_ACCESS_KEY_ID | cut -d= -f2)
        SECRET_KEY=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_SECRET_ACCESS_KEY | cut -d= -f2)
        SESSION_TOKEN=$(aws configure export-credentials --profile "$PROFILE_NAME" --format env-no-export | grep AWS_SESSION_TOKEN | cut -d= -f2)

        # POST credentials to UI backend
        echo "Sending credentials to UI backend at $BACKEND_URL..."
        RESPONSE=$(curl -s -m 5 -X POST "${BACKEND_URL}/api/aws/credentials/set" \
            -H "Content-Type: application/json" \
            -d "{\"access_key\": \"$ACCESS_KEY\", \"secret_key\": \"$SECRET_KEY\", \"session_token\": \"$SESSION_TOKEN\"}" 2>&1)

        if echo "$RESPONSE" | grep -q '"valid".*true'; then
            echo "Credentials sent to UI backend"
        else
            echo "WARNING: UI backend not reachable (credentials set locally only)"
        fi
        echo "Ready to use AWS CLI and UI"
    fi
else
    echo "ERROR: AWS SSO login failed"
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

---

## Method 2: Static Credentials Script

For IAM users with static access keys (not SSO). Creates a script that reads from `~/.aws/credentials` and sends to the UI backend.

**Create the script:**

```bash
cat > ~/.local/bin/aws_static_login.sh << 'EOF'
#!/bin/bash
# AWS Static Credentials Script for UI Backend
# Usage: source aws_static_login.sh [profile] [backend_url]

PROFILE="${1:-default}"
BACKEND_URL="${2:-http://127.0.0.1:8000}"

echo "Loading static credentials for profile: $PROFILE"

ACCESS_KEY=$(aws configure get aws_access_key_id --profile "$PROFILE")
SECRET_KEY=$(aws configure get aws_secret_access_key --profile "$PROFILE")

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo "ERROR: No credentials found for profile: $PROFILE"
    exit 1
fi

# Export to local environment
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
echo "Credentials exported to local environment"

# POST to UI backend
echo "Sending credentials to UI backend at $BACKEND_URL..."
RESPONSE=$(curl -s -m 5 -X POST "${BACKEND_URL}/api/aws/credentials/set" \
    -H "Content-Type: application/json" \
    -d "{\"access_key\": \"$ACCESS_KEY\", \"secret_key\": \"$SECRET_KEY\"}" 2>&1)

if echo "$RESPONSE" | grep -q '"valid".*true'; then
    echo "Credentials sent to UI backend"
else
    echo "WARNING: UI backend not reachable (credentials set locally only)"
fi

echo "Ready to use AWS CLI and UI"
EOF
chmod +x ~/.local/bin/aws_static_login.sh
```

**Usage:**

```bash
# Load default profile
source aws_static_login.sh

# Load specific profile
source aws_static_login.sh my-profile
```

{{% notice info %}}
Static credentials don't expire, so you only need to run this once per session (or when switching profiles).
{{% /notice %}}

---

## Method 3: AWS Credentials File

If you have credentials in `~/.aws/credentials`, the UI backend picks them up automatically via boto3's credential chain.

```ini
# ~/.aws/credentials
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[my-profile]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
```

To use a non-default profile, set `AWS_PROFILE` before starting the backend:

```bash
export AWS_PROFILE=my-profile
```

{{% notice note %}}
This method doesn't explicitly send credentials to the UI backend API. The backend uses boto3's default credential chain, which reads from environment variables, credentials file, and instance metadata.
{{% /notice %}}

---

## Method 4: Environment Variables

Export credentials directly in your shell before starting the UI:

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_SESSION_TOKEN="your-session-token"  # Only if using temporary credentials
```

The UI backend automatically uses these environment variables.

---

## Method 5: Direct API

POST credentials directly to the backend API. Useful for remote deployments, containers, or automation.

```bash
curl -X POST http://localhost:8000/api/aws/credentials/set \
  -H "Content-Type: application/json" \
  -d '{
    "access_key": "AKIAIOSFODNN7EXAMPLE",
    "secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
    "session_token": "optional-session-token"
  }'
```

For remote backends, change the URL:

```bash
curl -X POST http://remote-host:8000/api/aws/credentials/set ...
```

---

## Checking Credential Status

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
- `"session"` - Posted via API or login scripts
- `"environment/default"` - From environment variables or AWS credential chain

---

## Clearing Credentials

To clear stored session credentials and fall back to environment variables:

```bash
curl -X DELETE http://localhost:8000/api/aws/credentials/clear
```

---

## Troubleshooting

### Dropdowns Empty or Show Errors

**Symptom:** Region, AZ, and key pair dropdowns are empty or show errors.

**Solutions:**

1. Check credential status:
   ```bash
   curl http://localhost:8000/api/aws/credentials/status
   ```

2. If using SSO, ensure session is active:
   ```bash
   aws sso login --profile your-profile
   source aws_login.sh your-profile
   ```

3. If using static credentials, verify they're valid:
   ```bash
   aws sts get-caller-identity --profile your-profile
   ```

### Credentials Expired

SSO credentials expire (typically after 1-12 hours). Re-run the login script:

```bash
source aws_login.sh your-profile
```

### Wrong Account

If the UI shows resources from the wrong AWS account, clear and re-set credentials:

```bash
curl -X DELETE http://localhost:8000/api/aws/credentials/clear
source aws_login.sh correct-profile
```
