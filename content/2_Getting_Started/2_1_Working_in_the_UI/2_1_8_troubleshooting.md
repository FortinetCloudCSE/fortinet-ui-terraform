---
title: "Troubleshooting"
menuTitle: "Troubleshooting"
weight: 8
---

Common issues and fixes for UI development.

## Backend Issues

### ModuleNotFoundError

```bash
cd ui/backend
uv sync
```

### Port Already in Use

```bash
lsof -i :8000
kill -9 <PID>
```

### Database Errors

If the SQLite database is corrupted or schema is outdated:

```bash
# Delete and recreate (data will be lost)
rm -f ui/backend/data/registry.db
# Restart backend — tables are auto-created on startup
```

### Git Clone Failures

If template registration fails with a git error:

1. Verify the repo URL is accessible: `git ls-remote <url>`
2. Check the branch exists: `git ls-remote --heads <url> <branch>`
3. Check clone directory permissions: `ls -la ui/backend/data/clones/`
4. Clean up stale clones: `rm -rf ui/backend/data/clones/*`

---

## Frontend Issues

### Cannot Find Module

```bash
cd ui/frontend
npm install
```

### Vite Build Fails

Always run the build from the `ui/frontend/` directory:

```bash
cd ui/frontend
npx vite build
```

Running `npx vite build` from the repo root will pick up a global Vite version and fail with "Could not resolve entry module index.html".

### API Calls Failing

Check that backend is running and CORS is configured. The CORS origins are set in `.env`:

```
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173
```

---

## AWS Credential Issues

### Dropdowns Empty

1. Check credential status:
   ```bash
   curl http://localhost:8000/api/aws/credentials/status
   ```

2. If using SSO, ensure session is active:
   ```bash
   source ~/.local/bin/aws_login.sh your-profile
   ```

3. If credentials expired, re-run the login script.

## GCP Credential Issues

### GCP Dropdowns Empty

1. Check credential status:
   ```bash
   curl http://localhost:8000/api/gcp/credentials/status
   ```

2. Inject service account credentials:
   ```bash
   curl -X POST http://127.0.0.1:8000/api/gcp/credentials/set \
     -H "Content-Type: application/json" \
     -d @/path/to/service-account-key.json
   ```

---

## Drift Issues

### "Hard-stop drift detected" Error (409)

This means critical template files changed since last registration/import. To resolve:

1. Click the drift indicator in the UI to open the resolution modal
2. Review changed files
3. Re-scaffold if `variables.tf` changed
4. Save & re-hash to clear drift

Or via API:

```bash
# Check what drifted
curl http://127.0.0.1:8000/api/templates/1/drift

# Re-scaffold to pick up variable changes
curl -X POST http://127.0.0.1:8000/api/templates/1/scaffold

# Re-import to update hashes
curl -X POST http://127.0.0.1:8000/api/templates/1/import \
  -H "Content-Type: application/json" \
  -d '{"content": "<updated tfvars.ui content>"}'
```

### Template Shows "Warning" Drift

Warning drift means non-critical files changed (e.g., a `.tf` file that isn't `variables.tf`). This does **not** block plan/apply. The warning banner is dismissible.

---

## Container Issues

### Backend Not Starting in Docker

Check logs:
```bash
docker compose logs backend
```

Common causes:
- Missing `data/` volume mount
- Port conflict on 8000
- Git not available in container (should be installed by Dockerfile)

### Frontend Can't Reach Backend

In container deployment, the frontend nginx proxies `/api/` requests to the `backend` service. Ensure:
- Backend healthcheck passes: `docker compose ps`
- Frontend depends on backend: check `docker-compose.yml` `depends_on` condition
