# Resume Session After Reboot

## Quick Start

After rebooting, run this from the `ui/` directory:

```bash
./RESTART.sh
```

This will:
- Kill any stale processes
- Start the backend (FastAPI on port 8000)
- Start the frontend (Vite on port 3000)
- Show you the URLs and process IDs

## URLs After Restart

- **Frontend**: http://localhost:3000
- **Backend API Docs**: http://127.0.0.1:8000/docs
- **Backend API**: http://127.0.0.1:8000

## Full Session Context

See `SESSION_STATE.md` for complete details including:
- What was fixed in the last session
- Current file states
- Troubleshooting steps
- All process information

## If Page is Blank

1. Hard refresh browser: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows/Linux)
2. Check browser console (F12) for errors
3. Check logs:
   ```bash
   tail -f backend/backend.log
   tail -f frontend/frontend.log
   ```

## Manual Restart (if script doesn't work)

### Backend
```bash
cd backend
.venv/bin/python -m uvicorn app.main:app --reload --port 8000 &
```

### Frontend
```bash
cd frontend
npm run dev &
```

## Stop Services

```bash
pkill -f "vite|npm run dev"
pkill -f "uvicorn"
```

## Files Created for Resume

1. **SESSION_STATE.md** - Complete session context and troubleshooting
2. **RESTART.sh** - Quick restart script (this runs both services)
3. **RESUME_SESSION.md** - This file (quick reference)

## Last Session Summary

We fixed 4 issues:
1. ✅ Package name updated to terraform-ui
2. ✅ UI annotations (verified 405 annotations present, parsing to 12 groups/49 fields)
3. ✅ AWS SSO session (expired, user refreshed)
4. ✅ Browser cache (cleared Vite cache)

**Result**: Terraform Configuration UI now working, making successful API calls.

## Verification

After restart, you should see:
- Backend logs showing "Parsed schema: 12 groups, 49 fields"
- Frontend showing form with all terraform variables
- AWS API calls returning data (regions, AZs, keypairs)
- No errors in browser console

Good luck! 🚀
