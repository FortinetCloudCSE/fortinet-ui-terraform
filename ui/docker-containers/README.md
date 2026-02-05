# Docker Containers

Run the UI backend, frontend, and Hugo documentation server in Docker containers.

## Quick Start

```bash
cd ui/docker-containers
docker-compose up -d
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| backend | 8001 | FastAPI backend (proxied to 8000 internally) |
| frontend | 3001 | Vite React frontend (proxied to 3000 internally) |
| hugo | 1313 | Hugo documentation server |

## URLs

- **Frontend**: http://localhost:3001
- **Backend API**: http://localhost:8001
- **API Docs**: http://localhost:8001/docs
- **Hugo Docs**: http://localhost:1313/fortinet-ui-terraform/

## Commands

```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d backend frontend
docker-compose up -d hugo

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Rebuild after code changes
docker-compose up -d --build
```

## AWS Credentials

Use the login script to send credentials to the containerized backend:

```bash
source ../sso_login/aws_login.sh my-profile http://localhost:8001
```
