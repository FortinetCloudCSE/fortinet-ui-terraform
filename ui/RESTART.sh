#!/bin/bash

# Terraform UI - Quick Restart Script
# Can be run from any directory
# Will run setup if needed

echo "🔄 Restarting Terraform Configuration UI..."
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
LOGS_DIR="$ROOT_DIR/logs"

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Check if setup is needed
NEEDS_SETUP=false

# Check backend virtual environment
if [ ! -d "$SCRIPT_DIR/backend/.venv" ]; then
    echo "⚠️  Backend virtual environment not found"
    NEEDS_SETUP=true
fi

# Check frontend node_modules
if [ ! -d "$SCRIPT_DIR/frontend/node_modules" ]; then
    echo "⚠️  Frontend node_modules not found"
    NEEDS_SETUP=true
fi

# Check frontend package.json
if [ ! -f "$SCRIPT_DIR/frontend/package.json" ]; then
    echo "⚠️  Frontend package.json not found"
    NEEDS_SETUP=true
fi

# Run setup if needed
if [ "$NEEDS_SETUP" = true ]; then
    echo ""
    echo "📦 Running initial setup..."
    echo ""
    "$SCRIPT_DIR/SETUP.sh"
    echo ""
fi

# Kill any stale processes
echo "📋 Cleaning up old processes..."
pkill -f "vite" 2>/dev/null || true
pkill -f "uvicorn" 2>/dev/null || true
sleep 2

# Verify backend can start
echo "🔍 Verifying backend..."
cd "$SCRIPT_DIR/backend"

if [ ! -f ".env" ]; then
    echo "   Creating .env from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        cat > .env << 'EOF'
# Application Settings
APP_NAME="Terraform Configuration UI API"
APP_VERSION="0.1.0"

# Server Configuration
HOST=127.0.0.1
PORT=8000

# CORS Origins (comma-separated)
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000,http://localhost:5173,http://127.0.0.1:5173
EOF
    fi
fi

# Start Backend
echo "🚀 Starting backend (FastAPI)..."
.venv/bin/python -m uvicorn app.main:app --reload --port 8000 > "$LOGS_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
echo "   Backend started (PID: $BACKEND_PID)"

# Wait for backend to start and verify it's healthy
echo "   Waiting for backend to be ready..."
for i in {1..10}; do
    sleep 1
    if curl -s http://127.0.0.1:8000/health > /dev/null 2>&1; then
        echo "   ✅ Backend is healthy"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "   ❌ Backend failed to start. Check logs:"
        echo "      tail -f $LOGS_DIR/backend.log"
        exit 1
    fi
done

# Verify frontend can start
echo "🔍 Verifying frontend..."
cd "$SCRIPT_DIR/frontend"

# Ensure package.json exists
if [ ! -f "package.json" ]; then
    echo "   Creating package.json..."
    cat > package.json << 'EOF'
{
  "name": "terraform-config-ui",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "anser": "^2.3.3",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.4.11"
  }
}
EOF
fi

# Ensure node_modules exists
if [ ! -d "node_modules" ]; then
    echo "   Installing npm dependencies..."
    npm install
fi

# Start Frontend
echo "🎨 Starting frontend (Vite)..."
npm run dev > "$LOGS_DIR/frontend.log" 2>&1 &
FRONTEND_PID=$!
echo "   Frontend started (PID: $FRONTEND_PID)"

# Wait for frontend to start
echo "   Waiting for frontend to be ready..."
for i in {1..15}; do
    sleep 1
    if lsof -i :3000 > /dev/null 2>&1; then
        echo "   ✅ Frontend is ready"
        break
    fi
    if [ $i -eq 15 ]; then
        echo "   ❌ Frontend failed to start. Check logs:"
        echo "      tail -f $LOGS_DIR/frontend.log"
        exit 1
    fi
done

echo ""
echo "============================================"
echo "✅ Services started successfully!"
echo "============================================"
echo ""
echo "📊 URLs:"
echo "   Frontend: http://localhost:3000"
echo "   Backend:  http://127.0.0.1:8000"
echo "   API Docs: http://127.0.0.1:8000/docs"
echo ""
echo "📝 Process IDs:"
echo "   Backend:  $BACKEND_PID"
echo "   Frontend: $FRONTEND_PID"
echo ""
echo "🛑 To stop services:"
echo "   pkill -f 'vite'"
echo "   pkill -f 'uvicorn'"
echo ""
echo "📄 Logs:"
echo "   tail -f $LOGS_DIR/backend.log"
echo "   tail -f $LOGS_DIR/frontend.log"
echo ""
echo "🔍 Troubleshooting:"
echo "   - Check browser console (F12) if page is blank"
echo "   - Hard refresh: Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows/Linux)"
echo "   - Re-run setup: ./SETUP.sh"
