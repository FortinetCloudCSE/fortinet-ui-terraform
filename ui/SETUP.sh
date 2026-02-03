#!/bin/bash

# Terraform UI - One-Time Setup Script
# Run this once after cloning the repository

set -e

echo "🔧 Setting up Terraform Configuration UI..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create logs directory
LOGS_DIR="$(dirname "$SCRIPT_DIR")/logs"
mkdir -p "$LOGS_DIR"

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "   ❌ Python 3 is required but not installed."
    echo "   Install with: brew install python3 (macOS) or apt install python3 (Linux)"
    exit 1
fi
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
echo "   ✅ Python $PYTHON_VERSION"

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "   ❌ Node.js is required but not installed."
    echo "   Install with: brew install node (macOS) or visit https://nodejs.org"
    exit 1
fi
NODE_VERSION=$(node --version 2>&1)
echo "   ✅ Node.js $NODE_VERSION"

# Check npm
if ! command -v npm &> /dev/null; then
    echo "   ❌ npm is required but not installed."
    exit 1
fi
NPM_VERSION=$(npm --version 2>&1)
echo "   ✅ npm $NPM_VERSION"

echo ""

# Backend Setup
echo "📦 Setting up backend (Python/FastAPI)..."
cd backend

if [ -d ".venv" ]; then
    echo "   ⚠️  Virtual environment already exists, skipping creation"
else
    echo "   Creating Python virtual environment..."
    python3 -m venv .venv
fi

echo "   Upgrading pip..."
.venv/bin/pip install --upgrade pip -q

echo "   Installing Python dependencies..."
.venv/bin/pip install -e . -q

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        echo "   Creating .env from .env.example..."
        cp .env.example .env
    else
        echo "   Creating default .env file..."
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

echo "   ✅ Backend setup complete"
echo ""

# Frontend Setup
echo "📦 Setting up frontend (React/Vite)..."
cd ../frontend

# Check if package.json exists
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

# Always run npm install to ensure dependencies are up to date
echo "   Installing npm dependencies..."
npm install --silent 2>/dev/null || npm install

echo "   ✅ Frontend setup complete"
echo ""

# Summary
echo "============================================"
echo "✅ Setup complete!"
echo ""
echo "To start the UI, run:"
echo "   cd ui"
echo "   ./RESTART.sh"
echo ""
echo "Or start services manually:"
echo "   Backend:  cd ui/backend && .venv/bin/uvicorn app.main:app --reload --port 8000"
echo "   Frontend: cd ui/frontend && npm run dev"
echo ""
echo "URLs:"
echo "   Frontend: http://localhost:3000"
echo "   Backend:  http://127.0.0.1:8000"
echo "   API Docs: http://127.0.0.1:8000/docs"
echo "============================================"
