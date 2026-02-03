# Git Best Practices for This Project

## ✅ What TO Commit

### Root Directory
- ✅ All `.md` documentation files
- ✅ `.gitignore` file itself
- ✅ Project structure files

### Backend
- ✅ All `.py` source files
- ✅ `pyproject.toml` (dependencies)
- ✅ `.env.example` (template for environment variables)
- ✅ `README.md`
- ✅ Tests (`tests/` directory)
- ✅ Migration files (when you add them)

### Frontend
- ✅ All `.jsx`, `.js`, `.css` source files
- ✅ `package.json` (dependencies)
- ✅ `package-lock.json` (lock file - KEEP THIS)
- ✅ `vite.config.js`
- ✅ `index.html`
- ✅ Public assets (`public/` folder)
- ✅ `README.md`

---

## ❌ What NOT to Commit

### 🔴 CRITICAL - Never Commit These!

**Environment Variables (.env files):**
```
backend/.env         ❌ Contains DB passwords, API keys
frontend/.env        ❌ Contains secrets
.envrc               ❌ Local environment config
```

These files contain sensitive information like:
- Database passwords
- API keys
- JWT secret keys
- OAuth credentials

**Instead:** Commit `.env.example` with placeholder values:
```bash
# backend/.env.example
APP_NAME="Terraform Configuration UI API"
HOST=127.0.0.1
PORT=8000
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
SECRET_KEY=change-me-in-production
```

### Generated Files

**Python:**
```
__pycache__/         ❌ Compiled Python files
*.pyc                ❌ Bytecode
.venv/               ❌ Virtual environment
.pytest_cache/       ❌ Test cache
*.egg-info/          ❌ Package metadata
```

**Node:**
```
node_modules/        ❌ Dependencies (huge!)
dist/                ❌ Built files
build/               ❌ Production build
coverage/            ❌ Test coverage reports
```

### IDE/Editor Files

```
.idea/               ❌ PyCharm/WebStorm settings
.vscode/             ❌ VS Code settings (optional)
*.swp                ❌ Vim swap files
.DS_Store            ❌ macOS folder settings
```

**Note:** Some teams commit `.vscode/` for shared settings. Your choice!

### Logs and Temporary Files

```
*.log                ❌ Log files
*.tmp                ❌ Temporary files
.cache/              ❌ Cache directories
```

### Project-Specific

```
content/             ❌ Scraped HTML files
mysql_backups/       ❌ Database dumps
uploads/             ❌ User uploaded files
```

---

## 🛠️ Setup Commands

### First Time Setup (Before First Commit)

```bash
# 1. Initialize git (if not already done)
git init

# 2. Check what will be committed
git status

# 3. You should NOT see:
#    - .env files
#    - __pycache__/
#    - node_modules/
#    - .venv/
```

### Check Before Committing

```bash
# See what's staged
git status

# See what's changed
git diff

# See what would be added
git add -n .

# If you accidentally stage something sensitive:
git reset HEAD <file>
```

### If You Accidentally Committed Secrets

```bash
# Remove file from git but keep locally
git rm --cached backend/.env

# Commit the removal
git commit -m "Remove .env from git"

# Then rotate your secrets immediately!
# Change all passwords, API keys, etc.
```

---

## 🔍 Verify Your .gitignore Works

```bash
# From project root, check what git sees
git status

# List all untracked files (including ignored)
git status --ignored

# Check if a specific file is ignored
git check-ignore -v backend/.env
# Should output: backend/.gitignore:23:.env    backend/.env

# Test with a fake .env file
echo "SECRET=test" > backend/.env
git status
# Should NOT show backend/.env as untracked
```

---

## 📋 Pre-Commit Checklist

Before `git commit`, verify:

- [ ] No `.env` files in `git status`
- [ ] No `__pycache__` directories
- [ ] No `node_modules/` directory  
- [ ] No `.venv/` directory
- [ ] No database files (`.db`, `.sqlite`)
- [ ] No log files (`.log`)
- [ ] No sensitive data in code comments
- [ ] `.env.example` has placeholder values only

---

## 🎯 Recommended Git Workflow

### Daily Development

```bash
# 1. Check status before starting work
git status

# 2. Create a feature branch
git checkout -b feature/add-validation

# 3. Make changes, test them

# 4. Check what changed
git status
git diff

# 5. Stage files
git add backend/app/api/terraform.py
git add frontend/src/components/TerraformConfig.jsx

# 6. Commit with descriptive message
git commit -m "Add configuration validation for HA pair template"

# 7. Push to remote
git push origin feature/add-validation
```

### Before Pushing

```bash
# Final safety check
git log -1 -p  # Review last commit
git diff HEAD~1  # See all changes in last commit

# Look for:
# - Passwords
# - API keys  
# - Database credentials
# - Personal information
```

---

## 🚨 Common Mistakes

### ❌ Mistake #1: Committing .env

```bash
# Wrong:
git add .
git commit -m "Add changes"
# ^ This adds EVERYTHING, including .env

# Right:
git add backend/app/main.py
git commit -m "Update main.py"
# ^ Explicitly add files

# Or use git add -p for interactive staging
git add -p
```

### ❌ Mistake #2: Committing node_modules

```bash
# This is 300MB+! Don't do it!
git add frontend/node_modules/  # ❌

# Instead, node_modules/ is in .gitignore
# Others run: npm install
```

### ❌ Mistake #3: Not Using .env.example

```bash
# Wrong: No template for others
backend/.env  # Only on your machine

# Right: Provide template
backend/.env.example  # Committed to git
backend/.env          # In .gitignore, never committed
```

---

## 📚 Additional Resources

- **GitHub .gitignore templates:** https://github.com/github/gitignore
- **Git documentation:** https://git-scm.com/doc
- **Remove sensitive data:** https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository

---

## ✅ Quick Verification

Run this to check your .gitignore is working:

```bash
cd /Users/mwooten/github/react_fastapi

# Should show "ignored" status for these
git check-ignore backend/.env
git check-ignore backend/.venv
git check-ignore backend/__pycache__
git check-ignore frontend/node_modules
git check-ignore frontend/dist

# If any don't show as ignored, your .gitignore needs updating
```

---

**Remember:** Once committed to git, it's permanent in history. It's much easier to prevent commits than to remove them later! 🔒
