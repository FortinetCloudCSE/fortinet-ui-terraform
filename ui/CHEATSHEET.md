# Development Cheat Sheet

## Useful Commands

### Backend (from `backend/` directory)

```bash
# Start server with auto-reload
uv run uvicorn app.main:app --reload

# Start server on specific host/port
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8080

# Run Python shell with app context
uv run python

# Add new dependency
uv add package-name

# Remove dependency
uv remove package-name

# Show dependency tree
uv tree

# Run tests (when added)
uv run pytest

# Format code (when black is added)
uv run black app/

# Lint code (when ruff is added)
uv run ruff check app/
```

### Frontend (from `frontend/` directory)

```bash
# Start development server
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview

# Install new package
npm install package-name

# Install dev dependency
npm install --save-dev package-name

# Remove package
npm uninstall package-name

# Check for outdated packages
npm outdated

# Update all packages
npm update
```

## Project URLs

### Development
- **Frontend:** http://localhost:3000
- **Backend API:** http://127.0.0.1:8000
- **API Docs:** http://127.0.0.1:8000/docs
- **API Redoc:** http://127.0.0.1:8000/redoc
- **Health Check:** http://127.0.0.1:8000/health

## File Structure Quick Reference

### Backend Files
```
backend/
├── app/
│   ├── api/
│   │   └── root.py          # Root endpoint
│   ├── config.py            # Settings & env vars
│   ├── schemas.py           # Pydantic models
│   ├── main.py              # FastAPI app
│   └── mock_data.py         # Temporary mock data
├── .env                     # Environment variables (git-ignored)
├── .env.example             # Environment template
├── pyproject.toml           # Python dependencies
└── README.md
```

### Frontend Files
```
frontend/
├── src/
│   ├── components/
│   │   ├── TerraformConfig.jsx  # Main configuration form
│   │   └── TerraformConfig.css
│   ├── services/
│   │   └── api.js            # Backend API calls
│   ├── App.jsx               # Main app component
│   ├── App.css
│   ├── main.jsx              # Entry point
│   └── index.css
├── index.html                # HTML template
├── package.json              # NPM dependencies
└── vite.config.js            # Vite configuration
```

## Code Snippets

### Adding a New Backend Endpoint

**1. Define Pydantic Schema (schemas.py):**
```python
class NewResponse(BaseModel):
    """Response model."""
    data: str
    count: int
```

**2. Create Router (api/new_endpoint.py):**
```python
from fastapi import APIRouter
from app.schemas import NewResponse

router = APIRouter()

@router.get("/new", response_model=NewResponse)
async def get_new_data():
    return NewResponse(data="example", count=5)
```

**3. Include in Main (main.py):**
```python
from app.api import new_endpoint
app.include_router(new_endpoint.router, tags=["new"])
```

### Adding a New React Component

**1. Create Component (components/MyComponent.jsx):**
```jsx
import React from 'react';
import './MyComponent.css';

const MyComponent = ({ data }) => {
  return (
    <div className="my-component">
      <h2>{data.title}</h2>
      <p>{data.content}</p>
    </div>
  );
};

export default MyComponent;
```

**2. Create Styles (components/MyComponent.css):**
```css
.my-component {
  padding: 20px;
  background: white;
  border-radius: 8px;
}

.my-component h2 {
  color: #013369;
}
```

**3. Use in App.jsx:**
```jsx
import MyComponent from './components/MyComponent';

// In component:
<MyComponent data={{ title: "Test", content: "Hello" }} />
```

### Adding New API Call (services/api.js)

```javascript
export const api = {
  // ... existing methods ...
  
  getNewData: async () => {
    return apiFetch('/new');
  },
  
  postNewData: async (data) => {
    return apiFetch('/new', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },
};
```

## Environment Variables

### Backend (.env)
```bash
APP_NAME="Terraform Configuration UI API"
HOST=127.0.0.1
PORT=8000
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000

# AWS Configuration (optional - uses default credentials if not set)
AWS_PROFILE=your_profile
AWS_REGION=us-west-2
```

### Frontend
No .env needed currently. API URL is hardcoded in `api.js`.

For production, you'd add:
```bash
VITE_API_URL=https://api.example.com
```

## Debugging Tips

### Backend Debugging
```python
# Add print statements (they show in terminal)
print(f"Debug: {variable}")

# Use logging
import logging
logger = logging.getLogger(__name__)
logger.info(f"Info: {variable}")
logger.error(f"Error: {error}")

# Interactive debugging (ipdb)
# uv add --dev ipdb
import ipdb; ipdb.set_trace()
```

### Frontend Debugging
```javascript
// Console logging
console.log('Debug:', data);
console.error('Error:', error);

// React DevTools (install browser extension)
// Inspect component props and state

// Network tab (F12)
// View API requests and responses
```

## Common Patterns

### Backend: Async Endpoint with Error Handling
```python
@router.get("/example/{id}")
async def get_example(id: int):
    try:
        result = await some_async_function(id)
        if not result:
            raise HTTPException(status_code=404, detail="Not found")
        return result
    except Exception as e:
        logger.error(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

### Frontend: Fetch Data on Mount
```jsx
const [data, setData] = useState(null);
const [loading, setLoading] = useState(true);
const [error, setError] = useState(null);

useEffect(() => {
  const fetchData = async () => {
    try {
      const result = await api.getData();
      setData(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };
  
  fetchData();
}, []);
```

## Performance Tips

### Backend
- Use async/await for I/O operations
- Use dependency injection for shared resources
- Add proper indexes to database queries (future)
- Use connection pooling for database (future)

### Frontend
- Keep components small and focused
- Use React.memo for expensive components
- Avoid unnecessary re-renders
- Lazy load routes and components (future)

## Testing (Future)

### Backend Tests
```bash
# Run all tests
uv run pytest

# Run with coverage
uv run pytest --cov=app

# Run specific test file
uv run pytest tests/test_api.py

# Run specific test
uv run pytest tests/test_api.py::test_root
```

### Frontend Tests
```bash
# Install testing libraries first
npm install --save-dev @testing-library/react @testing-library/jest-dom vitest

# Run tests
npm test
```
