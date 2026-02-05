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

---

## Frontend Issues

### Cannot Find Module

```bash
cd ui/frontend
npm install
```

### API Calls Failing

Check that backend is running and CORS is configured in `main.py`:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)
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
   source sso_login/aws_login.sh your-profile
   ```

3. If credentials expired, re-run the login script.

