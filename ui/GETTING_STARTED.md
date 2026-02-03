# Getting Started: React + FastAPI Terraform Configuration UI

This guide walks you through setting up and running your Terraform Configuration UI with a React frontend and FastAPI backend.

## 🚀 Quick Start (5 Minutes)

### Prerequisites Check

```bash
# Check Python version (need 3.11+)
python3 --version

# Check Node.js (need 18+)
node --version
npm --version

# Install uv if not already installed
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Step 1: Start the Backend

```bash
# Navigate to backend directory
cd /Users/mwooten/github/react_fastapi/backend

# Install dependencies with uv
uv sync

# Start the FastAPI server
uv run uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

You should see:

```
INFO:     Uvicorn running on http://127.0.0.1:8000 (Press CTRL+C to quit)
INFO:     Started reloader process
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Starting Terraform Configuration UI v1.0.0
INFO:     Application startup complete.
```

**Test it:** Visit http://127.0.0.1:8000/docs to see the interactive API documentation.

### Step 2: Start the Frontend

Open a **new terminal window**:

```bash
# Navigate to frontend directory
cd /Users/mwooten/github/react_fastapi/frontend

# Install dependencies (first time only)
npm install

# Start the React dev server
npm run dev
```

You should see:

```
  VITE v5.x.x  ready in XXX ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
  ➜  press h + enter to show help
```

**Test it:** Visit http://localhost:5173 to see your React app!

## ✅ What You'll See

Right now, your app is running with **mock data** because the database isn't connected. You'll see:

- ✅ Fortinet Terraform Configuration Tool (e.g., "Fortinet Logo - Terraform Configuration Tool")
- ✅ Terraform Template Dropdown
- ✅ Terraform input display
- This is **perfect for frontend development** - you can build and test your React components without needing the database!

## 🔍 Understanding the Architecture

### Backend (FastAPI)

```
backend/
├── app/
│   ├── main.py              # FastAPI app creation, middleware
│   ├── config.py            # Settings (from .env)
│   ├── schemas.py           # Pydantic models for validation
│   ├── mock_data.py         # Temporary mock data
│   └── api/
│       └── root.py          # Root endpoint handler
└── pyproject.toml           # Python dependencies
```

**Key Files:**

1. **`main.py`**: Creates the FastAPI app, configures CORS, includes routers
2. **`api/root.py`**: Handles the `/` endpoint, returns JSON instead of HTML
3. **`schemas.py`**: Defines the data structures for API responses
4. **`mock_data.py`**: Provides fake data until database is connected

### Frontend (React)

```
frontend/
├── src/
│   ├── main.jsx             # Entry point
│   ├── App.jsx              # Main app component
│   ├── components/          # Reusable UI components
│   │   └── TerraformConfig.jsx  # Terraform configuration form
│   └── services/
│       └── api.js           # Backend API client
├── package.json             # Node dependencies
└── vite.config.js           # Vite configuration
```

**Key Files:**

1. **`App.jsx`**: Main component, fetches data and renders UI
2. **`services/api.js`**: All backend communication goes through here
3. **`components/TerraformConfig.jsx`**: Main configuration form component

## 📊 Data Flow

Here's how data flows from backend to frontend:

```
User clicks "Next Week" 
    ↓
Frontend calls api.getRoot(weekId)
    ↓
HTTP GET to http://127.0.0.1:8000/?season_week_id=202422012
    ↓
Backend root.py endpoint
    ↓
Returns JSON: { template, groups, fields }
    ↓
Frontend receives JSON
    ↓
React re-renders with new data
```

## 🔧 Common Tasks

### View API Documentation

Visit http://127.0.0.1:8000/docs to see:

- All available endpoints
- Request/response schemas
- Try out API calls directly

### Check API Status

```bash
curl http://127.0.0.1:8000/api/status
```

Returns:

```json
{
  "status": "healthy",
  "database_connected": false,
  "mode": "mock_data"
}
```

### Test Backend Without Frontend

```bash
# Get root data
curl http://127.0.0.1:8000/

# Get specific week
curl http://127.0.0.1:8000/?season_week_id=202422012

# Health check
curl http://127.0.0.1:8000/health
```

### Modify Configuration Schema

Edit the template configuration files in `terraform/` to modify:

- Variable definitions
- Default values
- UI annotations

After editing, restart the backend to see changes!

### Change Frontend Styling

Edit `frontend/src/App.css` or component CSS files. Changes appear instantly thanks to Vite's hot module replacement.

## 🔌 Connecting to Database (Later)

When you're ready to connect to MySQL:

1. **Copy database configuration from sag_fastapi_app:**

```bash
cp /Users/mwooten/github/sag_fastapi_app/app/db.py \
   /Users/mwooten/github/react_fastapi/backend/app/db.py

cp /Users/mwooten/github/sag_fastapi_app/app/repositories.py \
   /Users/mwooten/github/react_fastapi/backend/app/repositories.py
```

2. **Create `.env` file:**

```bash
cd backend
cat > .env << EOF
# Application
APP_NAME="Terraform Configuration UI API"

# Server
HOST=127.0.0.1
PORT=8000

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:5173

# JWT (if authentication is added)
SECRET_KEY=your-secret-key-change-in-production
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24
EOF
```

3. **Add SQLAlchemy dependencies:**

```bash
uv add sqlalchemy aiomysql
```

4. **Restart backend** - it will auto-detect the database!

## 🐛 Troubleshooting

### Backend Won't Start

**Error:** `ModuleNotFoundError: No module named 'fastapi'`

```bash
cd backend
uv sync  # Reinstall dependencies
```

**Error:** `Address already in use`

```bash
# Port 8000 is busy, use different port:
uv run uvicorn app.main:app --reload --port 8001
```

### Frontend Won't Start

**Error:** `npm: command not found`

```bash
# Install Node.js from https://nodejs.org/
# Or use nvm: https://github.com/nvm-sh/nvm
```

**Error:** Dependencies missing

```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
```

### CORS Errors in Browser

**Error:** `Access to fetch at 'http://127.0.0.1:8000/' from origin 'http://localhost:5173' has been blocked by CORS`

1. Check backend logs - you should see CORS middleware active
2. Verify `CORS_ORIGINS` in backend config.py includes your frontend URL
3. Clear browser cache
4. Restart both servers

### Changes Not Appearing

**Backend:**

- Check terminal - should see "Reloading" message
- If not, stop (Ctrl+C) and restart

**Frontend:**

- Should auto-reload
- If not, hard refresh browser (Cmd+Shift+R on Mac)
- Check terminal for errors

## 📝 Next Steps

Now that your app is running:

### 1. Explore the Code (Today)

- Open `backend/app/api/root.py` - see how endpoints work
- Open `frontend/src/App.jsx` - see how React components work
- Open `backend/app/schemas.py` - see Pydantic models
- Modify mock data and see changes live!

### 2. Add a New Component (This Week)

Try creating a `SagarinTable` component:

```jsx
// frontend/src/components/SagarinTable.jsx
function SagarinTable({ homeSagarin, awaySagarin, advantages }) {
  return (
    <div className="sagarin-table">
      {/* Display Sagarin ratings in a nice table */}
    </div>
  );
}
```

### 3. Connect Database (When Ready)

- Follow database connection steps above
- Test with existing sag_fastapi_app data
- Gradually replace mock data with real queries

### 4. Add More Endpoints

- `/api/terraform/validate` - Validate configuration
- `/api/terraform/generate` - Generate tfvars file
- `/api/aws/vpcs` - List existing VPCs

## 💡 Tips for React Beginners

### Component Basics

Components are JavaScript functions that return JSX (HTML-like syntax):

```jsx
function MyComponent({ title, data }) {
  return (
    <div>
      <h1>{title}</h1>
      <p>Data: {data}</p>
    </div>
  );
}
```

### State Management

Use `useState` to store data that changes:

```jsx
import { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);
  
  return (
    <button onClick={() => setCount(count + 1)}>
      Clicked {count} times
    </button>
  );
}
```

### Fetching Data

Use `useEffect` to fetch data when component loads:

```jsx
import { useState, useEffect } from 'react';

function ConfigFields() {
  const [fields, setFields] = useState([]);

  useEffect(() => {
    async function fetchSchema() {
      const data = await api.getSchema();
      setFields(data.fields);
    }
    fetchSchema();
  }, []); // Empty array = run once on mount

  return (
    <div>
      {fields.map(field => <FieldInput key={field.name} field={field} />)}
    </div>
  );
}
```

## 📚 Resources

- **FastAPI Tutorial**: https://fastapi.tiangolo.com/tutorial/
- **React Tutorial**: https://react.dev/learn
- **Pydantic Guide**: https://docs.pydantic.dev/latest/
- **uv Documentation**: https://docs.astral.sh/uv/

## 🆘 Getting Help

If you get stuck:

1. Check the browser console (F12) for frontend errors
2. Check the backend terminal for API errors
3. Look at the `/docs` endpoint for API examples
4. Review the mock_data.py to understand data structure
5. Check MIGRATION_GUIDE.md for more detailed info

## ✨ What Makes This Different?

### vs. Original sag_fastapi_app


| Old                    | New                        |
| ---------------------- | -------------------------- |
| HTML strings in Python | React components           |
| Full page reloads      | Instant updates            |
| Backend rendering      | Client-side rendering      |
| Mixed concerns         | Separated frontend/backend |

### Benefits

- **Better UX**: No page reloads, instant feedback
- **Easier Development**: Work on frontend/backend separately
- **Modern Stack**: Industry-standard tools
- **Scalability**: Easy to add features, mobile apps, etc.
- **Testability**: Test frontend and backend independently

---

**You're all set!** Your backend is at http://127.0.0.1:8000 and frontend at http://localhost:5173. Start coding! 🚀
