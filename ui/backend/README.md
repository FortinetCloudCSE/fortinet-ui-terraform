# Terraform Configuration UI - Backend API

FastAPI backend for the Terraform Configuration UI application.

## Setup

### Prerequisites
- Python 3.11+
- uv (Python package manager)

### Installation

1. Install dependencies using uv:
```bash
uv sync
```

2. Create `.env` file from example:
```bash
cp .env.example .env
```

3. Edit `.env` with your configuration (if needed)

### Running the API

Development mode with auto-reload:
```bash
uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Or using the main module:
```bash
uv run python -m app.main
```

The API will be available at: http://127.0.0.1:8000

## API Documentation

Once running, visit:
- **Interactive API docs (Swagger UI)**: http://127.0.0.1:8000/docs
- **Alternative docs (ReDoc)**: http://127.0.0.1:8000/redoc

## Endpoints

### Health Check
```
GET /health
```
Returns API health status and version info.

### Terraform Schema
```
GET /api/terraform/schema?template={template_name}
```
Returns the schema for a Terraform template.

Query Parameters:
- `template` (optional): Template name. Defaults to "existing_vpc_resources".

Response includes:
- Template name
- Field groups
- Field definitions with types and defaults

### AWS Credentials

The API supports two credential sources:
1. **Environment variables** - Standard AWS credential chain (env vars, instance profile, etc.)
2. **Session credentials** - Posted via API for remote/container deployments

```
POST /api/aws/credentials/set
```
Set AWS credentials for the session. Useful when the backend runs in a container and can't access local AWS CLI credentials.

Request body:
```json
{
  "access_key": "AKIAIOSFODNN7EXAMPLE",
  "secret_key": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "session_token": "optional-session-token-for-temporary-credentials"
}
```

Response (success):
```json
{
  "valid": true,
  "account": "123456789012",
  "arn": "arn:aws:iam::123456789012:user/example",
  "message": "AWS credentials set successfully"
}
```

```
DELETE /api/aws/credentials/clear
```
Clear stored session credentials. The API will fall back to environment variables.

```
GET /api/aws/credentials/status
```
Check if AWS credentials are valid and their source.

Response:
```json
{
  "valid": true,
  "account": "123456789012",
  "arn": "arn:aws:iam::123456789012:user/example",
  "user_id": "AIDAEXAMPLEUSERID",
  "source": "session",
  "message": "AWS credentials are valid"
}
```

The `source` field indicates where credentials came from:
- `"session"` - Credentials were posted via `/api/aws/credentials/set`
- `"environment/default"` - Using environment variables or default credential chain

### AWS Resources
```
GET /api/aws/regions
GET /api/aws/availability-zones?region={region}
GET /api/aws/keypairs?region={region}
```
Returns AWS resource information for configuration.

## Project Structure

```
backend/
├── app/
│   ├── api/
│   │   ├── __init__.py
│   │   └── root.py          # Root endpoint router
│   ├── __init__.py
│   ├── config.py            # Settings & configuration
│   ├── main.py              # FastAPI application
│   ├── schemas.py           # Pydantic models
│   └── mock_data.py         # Mock data (temporary)
├── .env.example
├── pyproject.toml
└── README.md
```

## Development Notes

### Schema Parsing
The backend parses Terraform variable files to extract field definitions and UI annotations. See the `terraform.py` API module for details.

### Next Steps
1. Add configuration validation
2. Implement tfvars generation
3. Add more AWS resource discovery endpoints
4. Add authentication if needed
5. Add tests

## CORS Configuration

The API is configured to accept requests from the React frontend running on:
- http://localhost:3000 (Create React App default)
- http://localhost:5173 (Vite default)

Update `CORS_ORIGINS` in `.env` if your frontend runs on a different port.
